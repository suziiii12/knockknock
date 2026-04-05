"""
pipeline/inference_engine.py
------------------------------
Orchestrates the full pipeline:
  WebcamCapture → sliding window → EngagementLSTM → StudyContext → score

Call pattern:
    engine = InferenceEngine()
    engine.start()

    # In your UI loop (e.g. every 1s):
    result = engine.tick()
    if result:
        print(result.focus_score, result.inferred_state)

    engine.stop()
"""

import time
import threading
import numpy as np
from pathlib import Path
from typing import Optional

from knockknock.EngagementScoreAI.pipeline.webcam_capture import WebcamCapture, BehavioralAccumulator
from knockknock.EngagementScoreAI.pipeline.study_context import StudyContext, StudyContextSnapshot
from knockknock.EngagementScoreAI.pipeline.behavioral_listener import start_listeners, stop_listeners


WEIGHTS_PATH = Path(__file__).parent.parent / "weights" / "engagement_lstm.pt"


class InferenceEngine:
    """
    Main orchestrator. Thread-safe — call tick() from any thread.

    Parameters
    ----------
    camera_index : int
        Webcam index (0 = built-in)
    fps : int
        Vision processing fps (10 recommended)
    window_size : int
        LSTM input frames (30 = 3s at 10fps)
    epoch_sec : float
        How often to emit a new score (default 5s to match DAiSEE eval cadence)
    content_type : str
        "coding" | "reading" | "video" | "general"
    """

    def __init__(
        self,
        camera_index: int = 0,
        fps: int = 10,
        window_size: int = 30,
        epoch_sec: float = 5.0,
        content_type: str = "general",
    ):
        self.fps = fps
        self.window_size = window_size
        self.epoch_sec = epoch_sec

        self.behavioral = BehavioralAccumulator()
        self.capture = WebcamCapture(
            fps=fps,
            window_size=window_size,
            camera_index=camera_index,
            behavioral=self.behavioral,
        )
        self.study_context = StudyContext(content_type=content_type)

        self._model = None
        self._model_loaded = False
        self._device = "cpu"

        self._latest_snapshot: Optional[StudyContextSnapshot] = None
        self._last_epoch_time = 0.0
        self._epoch_count = 0
        self._score_history = []   # list of (timestamp, focus_score)
        self._lock = threading.Lock()

        self._kb_listener = None
        self._ms_listener = None

    # ------------------------------------------------------------------ #
    #  Lifecycle
    # ------------------------------------------------------------------ #

    def start(self):
        """Start webcam capture, behavioral listeners, and load model."""
        self._load_model()
        self.capture.start()
        self._kb_listener, self._ms_listener = start_listeners(self.behavioral)
        self._last_epoch_time = time.time()
        self.study_context._session_end = None  # Reset for new session
        print("[InferenceEngine] Started")

    def stop(self):
        """Stop all background threads."""
        self.capture.stop()
        stop_listeners(self._kb_listener, self._ms_listener)
        self.study_context._session_end = time.time()  # Record session end time
        print("[InferenceEngine] Stopped")

    # ------------------------------------------------------------------ #
    #  Main update method (call from UI thread / loop)
    # ------------------------------------------------------------------ #

    def tick(self) -> Optional[StudyContextSnapshot]:
        """
        Called periodically (e.g. every 1s from Streamlit).
        Returns a new StudyContextSnapshot every epoch_sec seconds,
        or None if it's not time yet / buffer not full.
        """
        now = time.time()
        if now - self._last_epoch_time < self.epoch_sec:
            return None

        window = self.capture.get_window()
        if window is None:
            return None   # buffer still filling up

        self._last_epoch_time = now
        self._epoch_count += 1

        engagement, daisee_class, confidence = self._run_inference(window)

        debug = self.capture.get_debug_info()
        blink_rate = self.capture.extractor.blink_count  # total since start
        posture = debug.get("posture_score", 0.5)

        snap = self.study_context.update(
            body_engagement=engagement,
            daisee_class=daisee_class,
            confidence=confidence,
            blink_rate=blink_rate,
            posture_score=posture,
        )

        with self._lock:
            self._latest_snapshot = snap
            self._score_history.append((now, snap.focus_score))
            if len(self._score_history) > 720:   # keep max 1 hour
                self._score_history = self._score_history[-720:]

        return snap

    # ------------------------------------------------------------------ #
    #  Accessors
    # ------------------------------------------------------------------ #

    def latest_snapshot(self) -> Optional[StudyContextSnapshot]:
        with self._lock:
            return self._latest_snapshot

    def score_history(self):
        """Returns list of (timestamp, score) tuples."""
        with self._lock:
            return list(self._score_history)

    def latest_frame(self):
        return self.capture.get_frame()

    def debug_info(self) -> dict:
        return self.capture.get_debug_info()

    def buffer_fill(self) -> float:
        return self.capture.get_buffer_fill()

    def epoch_count(self) -> int:
        return self._epoch_count

    def session_summary(self) -> dict:
        return self.study_context.session_summary()

    def set_content_demand(self, score: float):
        self.study_context.content_demand_score = score

    def set_cognitive_load(self, score: float):
        self.study_context.cognitive_load_score = score

    # ------------------------------------------------------------------ #
    #  Model loading & inference
    # ------------------------------------------------------------------ #

    def _load_model(self):
        try:
            import torch
            from knockknock.EngagementScoreAI.models.engagement_lstm import load_model

            if WEIGHTS_PATH.exists():
                print(f"[InferenceEngine] Loading weights: {WEIGHTS_PATH}")
                self._model = load_model(str(WEIGHTS_PATH), self._device)
                self._model_loaded = True
                print("[InferenceEngine] Model loaded OK")
            else:
                print(f"[InferenceEngine] Weights not found at {WEIGHTS_PATH}")
                print("  Run: python download_weights.py")
                print("  Falling back to rule-based scoring.")
        except ImportError:
            print("[InferenceEngine] PyTorch not installed — using rule-based scoring.")

    def _run_inference(self, window: np.ndarray):
        """
        Run EngagementLSTM on window (30, 11) and return
        (engagement_score, daisee_class, confidence).

        Falls back to heuristic scoring if model unavailable.
        """
        if self._model_loaded:
            return self._lstm_inference(window)
        else:
            return self._heuristic_inference(window)

    def _lstm_inference(self, window: np.ndarray):
        import torch
        x = torch.tensor(window).unsqueeze(0)   # (1, 30, 11)
        cls, conf, score, _ = self._model.predict_engagement(x)
        return score, cls, conf

    def _heuristic_inference(self, window: np.ndarray) -> tuple:
        """
        Rule-based fallback matching the original pipeline's weighted formula.
        Window shape: (30, 11) — see feature_extractor for column order.
        """
        # Column means over the window
        mean = window.mean(axis=0)

        face_presence  = float(mean[4])          # 0 or 1
        gaze_score     = float(mean[9])          # rolling gaze %
        head_stability = 1.0 - min(abs(float(mean[0])), 1.0)
        activity       = (float(mean[5]) * 0.6 + float(mean[6]) * 0.4)
        idle_penalty   = float(mean[8])
        posture        = float(mean[10])

        score = (
            gaze_score      * 0.35 +
            face_presence   * 0.20 +
            head_stability  * 0.15 +
            activity        * 0.15 +
            posture         * 0.10 +
            (1.0 - idle_penalty) * 0.05
        ) * 100.0

        score = float(min(100.0, max(0.0, score)))

        # Map to DAiSEE class
        if score < 25:   cls = 0
        elif score < 50: cls = 1
        elif score < 75: cls = 2
        else:            cls = 3

        confidence = 1.0 - abs(score - (cls * 25 + 12.5)) / 25.0
        return score, cls, confidence
