"""
pipeline/inference_engine.py
------------------------------
Backend inference engine.

Key changes from the Streamlit version:
  - WINDOW_SEC = 120  (2-minute rolling window)
  - Scores are written to SQLite via db.store every EPOCH_SEC seconds
  - No UI concerns — pure data pipeline
  - Thread-safe; designed to be started/stopped by the FastAPI lifespan

Window strategy
---------------
We collect frames continuously at 10fps into a 1200-frame deque
(120s x 10fps). Every EPOCH_SEC seconds we:
  1. Take a snapshot of the full 1200-frame window
  2. Run the LSTM on it (or heuristic fallback)
  3. Write a ScoreRecord to the DB with window_start / window_end timestamps
  4. Notify any registered callbacks (for SSE push)

Each DB row represents a score computed over the full preceding 2 minutes.
"""

import time
import threading
import numpy as np
from pathlib import Path
from typing import Optional, Callable, List
from collections import deque

from knockknock.EngagementScoreAI.pipeline.webcam_capture import WebcamCapture, BehavioralAccumulator
from knockknock.EngagementScoreAI.pipeline.study_context import StudyContext, StudyContextSnapshot
from knockknock.EngagementScoreAI.pipeline.behavioral_listener import start_listeners, stop_listeners
from knockknock.EngagementScoreAI.db.store import (
    init_db, create_session, end_session,
    insert_score, ScoreRecord,
)

WEIGHTS_PATH = Path(__file__).parent.parent / "weights" / "engagement_lstm.pt"

WINDOW_SEC        = 120          # 2-minute window
FPS_DEFAULT       = 10
EPOCH_SEC_DEFAULT = 30.0         # emit one score every 30 s


class InferenceEngine:
    """
    Pure backend pipeline. No UI. Writes scores to SQLite.

    engine = InferenceEngine()
    session_id = engine.start(content_type="coding")
    ...
    engine.stop()
    """

    def __init__(
        self,
        camera_index: int = 0,
        fps: int = FPS_DEFAULT,
        epoch_sec: float = EPOCH_SEC_DEFAULT,
        content_demand: float = 50.0,
        cognitive_load: float = 50.0,
    ):
        self.fps         = fps
        self.epoch_sec   = epoch_sec
        self.window_frames = WINDOW_SEC * fps   # 1200 at default fps

        self.behavioral = BehavioralAccumulator()
        self.capture = WebcamCapture(
            fps=fps,
            window_size=self.window_frames,
            camera_index=camera_index,
            behavioral=self.behavioral,
        )
        self.study_context = StudyContext()
        self.study_context.content_demand_score = content_demand
        self.study_context.cognitive_load_score  = cognitive_load

        self._model        = None
        self._model_loaded = False

        self._session_id: Optional[int]           = None
        self._running     = False
        self._epoch_thread: Optional[threading.Thread] = None
        self._lock        = threading.Lock()

        self._kb_listener = None
        self._ms_listener = None

        self._callbacks: List[Callable] = []
        self._recent_scores: deque      = deque(maxlen=20)

        init_db()

    # ------------------------------------------------------------------ #
    #  Lifecycle
    # ------------------------------------------------------------------ #

    def start(self, content_type: str = "general") -> int:
        if self._running:
            raise RuntimeError("Engine already running.")

        self._load_model()
        self._session_id   = create_session(content_type=content_type)
        self.study_context = StudyContext(content_type=content_type)
        self._running      = True

        self.capture.start()
        self._kb_listener, self._ms_listener = start_listeners(self.behavioral)

        self._epoch_thread = threading.Thread(
            target=self._epoch_loop, daemon=True, name="epoch-loop"
        )
        self._epoch_thread.start()

        print(f"[InferenceEngine] Session {self._session_id} started "
              f"(window={WINDOW_SEC}s, epoch={self.epoch_sec}s, fps={self.fps})")
        return self._session_id

    def stop(self):
        if not self._running:
            return
        self._running = False
        if self._epoch_thread:
            self._epoch_thread.join(timeout=5.0)
        self.capture.stop()
        stop_listeners(self._kb_listener, self._ms_listener)
        if self._session_id is not None:
            end_session(self._session_id)
            print(f"[InferenceEngine] Session {self._session_id} ended.")
            self._session_id = None

    # ------------------------------------------------------------------ #
    #  Callbacks
    # ------------------------------------------------------------------ #

    def on_score(self, callback: Callable):
        """Register callback(record, snapshot) for SSE / WebSocket push."""
        self._callbacks.append(callback)

    # ------------------------------------------------------------------ #
    #  Accessors
    # ------------------------------------------------------------------ #

    def latest_scores(self, n: int = 10) -> list:
        with self._lock:
            return list(self._recent_scores)[-n:]

    @property
    def session_id(self) -> Optional[int]:
        return self._session_id

    @property
    def is_running(self) -> bool:
        return self._running

    def buffer_fill(self) -> float:
        return self.capture.get_buffer_fill()

    def set_content_demand(self, v: float): self.study_context.content_demand_score = v
    def set_cognitive_load(self, v: float): self.study_context.cognitive_load_score  = v

    # ------------------------------------------------------------------ #
    #  Epoch loop
    # ------------------------------------------------------------------ #

    def _epoch_loop(self):
        next_tick = time.time() + self.epoch_sec
        while self._running:
            sleep_for = next_tick - time.time()
            if sleep_for > 0:
                time.sleep(sleep_for)
            next_tick += self.epoch_sec
            if not self._running:
                break

            window = self.capture.get_window()
            if window is None:
                pct = self.capture.get_buffer_fill() * 100
                print(f"[InferenceEngine] Buffer filling… {pct:.0f}% of {WINDOW_SEC}s")
                continue

            window_end   = time.time()
            window_start = window_end - WINDOW_SEC
            self._run_epoch(window, window_start, window_end)

    def _run_epoch(self, window, window_start, window_end):
        engagement, daisee_class, confidence = self._infer(window)

        debug   = self.capture.get_debug_info()
        posture = debug.get("posture_score", 0.5)
        blinks  = self.capture.extractor.blink_count

        snap = self.study_context.update(
            body_engagement=engagement,
            daisee_class=daisee_class,
            confidence=confidence,
            blink_rate=float(blinks),
            posture_score=posture,
        )

        col = window.mean(axis=0)   # mean per feature over 2-min window

        record = ScoreRecord(
            session_id      = self._session_id,
            window_start    = window_start,
            window_end      = window_end,
            score           = snap.focus_score,
            daisee_class    = snap.daisee_class,
            confidence      = snap.confidence,
            inferred_state  = snap.inferred_state.value,
            body_engagement = snap.body_engagement,
            mean_gaze       = float(col[9]),
            mean_head_yaw   = float(col[0]) * 90.0,
            mean_ear        = float((col[2] + col[3]) / 2),
            mean_kpm        = float(col[5]) * 120.0,
            mean_posture    = float(col[10]),
        )

        score_id = insert_score(record)

        summary = {
            "score_id":       score_id,
            "session_id":     self._session_id,
            "window_start":   window_start,
            "window_end":     window_end,
            "score":          round(snap.focus_score, 2),
            "daisee_class":   snap.daisee_class,
            "confidence":     round(snap.confidence, 3),
            "inferred_state": snap.inferred_state.value,
            "body_engagement":round(snap.body_engagement, 2),
            "mean_gaze":      round(record.mean_gaze, 3),
            "mean_head_yaw":  round(record.mean_head_yaw, 1),
            "mean_ear":       round(record.mean_ear, 3),
            "mean_kpm":       round(record.mean_kpm, 1),
            "mean_posture":   round(record.mean_posture, 3),
        }

        with self._lock:
            self._recent_scores.append(summary)

        import datetime
        fmt = lambda ts: datetime.datetime.fromtimestamp(ts).strftime("%H:%M:%S")
        print(f"[InferenceEngine] score={snap.focus_score:.1f} "
              f"state={snap.inferred_state.value} "
              f"window=[{fmt(window_start)} → {fmt(window_end)}]")

        for cb in self._callbacks:
            try:
                cb(record, snap)
            except Exception as e:
                print(f"[InferenceEngine] Callback error: {e}")

    # ------------------------------------------------------------------ #
    #  Inference
    # ------------------------------------------------------------------ #

    def _load_model(self):
        try:
            import torch
            from knockknock.EngagementScoreAI.models.engagement_lstm import load_model
            if WEIGHTS_PATH.exists():
                self._model = load_model(str(WEIGHTS_PATH), "cpu")
                self._model_loaded = True
                print(f"[InferenceEngine] Model loaded.")
            else:
                print(f"[InferenceEngine] No weights found — heuristic mode.")
        except ImportError:
            print("[InferenceEngine] PyTorch not available — heuristic mode.")

    def _infer(self, window: np.ndarray):
        if self._model_loaded:
            return self._lstm_infer(window)
        return self._heuristic_infer(window)

    def _lstm_infer(self, window: np.ndarray):
        import torch
        # Downsample 1200-frame window to 30 frames for the LSTM
        idx     = np.linspace(0, len(window) - 1, 30, dtype=int)
        sampled = window[idx]
        x       = torch.tensor(sampled).unsqueeze(0)
        cls, conf, score, _ = self._model.predict_engagement(x)
        return score, cls, conf

    def _heuristic_infer(self, window: np.ndarray):
        m     = window.mean(axis=0)
        score = (
            float(m[9])  * 0.35 +
            float(m[4])  * 0.20 +
            (1.0 - min(abs(float(m[0])), 1.0)) * 0.15 +
            (float(m[5]) * 0.6 + float(m[6]) * 0.4) * 0.15 +
            float(m[10]) * 0.10 +
            (1.0 - float(m[8])) * 0.05
        ) * 100.0
        score = float(min(100.0, max(0.0, score)))
        cls   = 0 if score < 25 else 1 if score < 50 else 2 if score < 75 else 3
        conf  = 1.0 - abs(score - (cls * 25 + 12.5)) / 25.0
        return score, cls, conf
