"""
pipeline/inference_engine.py
------------------------------
Backend inference engine — externally controllable.

Designed to be driven by an external backend (HTTP API or direct Python import):

  Direct Python usage:
    from pipeline.inference_engine import engine
    session_id = engine.start(session_id="abc123", content_type="coding")
    ...
    csv_path = engine.stop()   # returns path of written CSV file

  Via HTTP (api/server.py wraps these calls):
    POST /sessions/start  →  engine.start(...)
    POST /sessions/stop   →  engine.stop()

On stop():
  1. Marks session ended in SQLite
  2. Calls session_export.export_session() → writes exports/session_N_TIMESTAMP.csv
  3. Returns the Path to the CSV file

Window: 120s rolling (1200 frames at 10fps)
Epoch:  score emitted every 30s, each covering the trailing 2 minutes
"""

import time
import threading
import datetime
import numpy as np
from pathlib import Path
from typing import Optional, Callable, List
from collections import deque

from pipeline.webcam_capture import WebcamCapture, BehavioralAccumulator
from pipeline.study_context import StudyContext
from pipeline.behavioral_listener import start_listeners, stop_listeners
from pipeline.session_export import export_session, EXPORT_DIR
from db.store import (
    init_db, create_session, end_session,
    insert_score, ScoreRecord,
)

WEIGHTS_PATH      = Path(__file__).parent.parent / "weights" / "engagement_lstm.pt"
WINDOW_SEC        = 120
FPS_DEFAULT       = 10
EPOCH_SEC_DEFAULT = 30.0


class InferenceEngine:
    """
    Pure backend pipeline. No UI.

    Externally controllable — start/stop from any Python code or HTTP call.
    Writes scores to SQLite continuously.
    Exports full score sequence to CSV when stop() is called.
    """

    def __init__(
        self,
        camera_index: int = 0,
        fps: int = FPS_DEFAULT,
        epoch_sec: float = EPOCH_SEC_DEFAULT,
        export_dir: Optional[Path] = None,
    ):
        self.fps           = fps
        self.epoch_sec     = epoch_sec
        self.window_frames = WINDOW_SEC * fps
        self.export_dir    = export_dir or EXPORT_DIR

        self.behavioral = BehavioralAccumulator()
        self.capture    = WebcamCapture(
            fps=fps,
            window_size=self.window_frames,
            camera_index=camera_index,
            behavioral=self.behavioral,
        )
        self.study_context = StudyContext()

        self._model        = None
        self._model_loaded = False

        self._session_id: Optional[int]                = None
        self._external_id: Optional[str]               = None  # caller-supplied ID
        self._running      = False
        self._epoch_thread: Optional[threading.Thread] = None
        self._lock         = threading.Lock()

        self._kb_listener = None
        self._ms_listener = None

        # Callbacks: registered by api/server.py for SSE push
        self._callbacks: List[Callable] = []

        # In-memory ring of recent score dicts (for /status polling)
        self._recent_scores: deque = deque(maxlen=20)

        init_db()
        self._load_model()

    # ------------------------------------------------------------------ #
    #  External control API
    # ------------------------------------------------------------------ #

    def start(
        self,
        content_type: str    = "general",
        content_demand: float = 50.0,
        cognitive_load: float = 50.0,
        session_id: Optional[str] = None,
    ) -> int:
        """
        Start the pipeline and open a new DB session.

        Parameters
        ----------
        content_type   : "general" | "coding" | "reading" | "video" | "math"
        content_demand : 0–100  (from TRIBE v2 or set manually)
        cognitive_load : 0–100  (from pupil tracker or set manually)
        session_id     : optional string ID supplied by the external caller
                         (stored as content_type suffix for traceability)

        Returns
        -------
        int  DB session_id
        """
        if self._running:
            raise RuntimeError(
                f"Engine already running (session {self._session_id}). "
                "Call stop() before starting a new session."
            )

        self._external_id = session_id

        # Tag content_type with external ID if provided so it's queryable
        db_content_type = content_type
        if session_id:
            db_content_type = f"{content_type}:{session_id}"

        self._session_id   = create_session(content_type=db_content_type)
        self.study_context = StudyContext(content_type=content_type)
        self.study_context.content_demand_score = content_demand
        self.study_context.cognitive_load_score  = cognitive_load

        self._running = True
        self.capture.start()
        self._kb_listener, self._ms_listener = start_listeners(self.behavioral)

        self._epoch_thread = threading.Thread(
            target=self._epoch_loop, daemon=True, name="epoch-loop"
        )
        self._epoch_thread.start()

        print(
            f"[InferenceEngine] Session {self._session_id} started"
            + (f" (external_id={session_id})" if session_id else "")
            + f" | window={WINDOW_SEC}s epoch={self.epoch_sec}s fps={self.fps}"
        )
        return self._session_id

    def stop(self) -> Optional[Path]:
        """
        Stop the pipeline, close the DB session, and export scores to CSV.

        Returns
        -------
        Path  to the exported CSV file, or None if no scores were recorded.
        """
        if not self._running:
            return None

        self._running = False
        sid = self._session_id

        if self._epoch_thread:
            self._epoch_thread.join(timeout=5.0)

        self.capture.stop()
        stop_listeners(self._kb_listener, self._ms_listener)

        csv_path = None
        if sid is not None:
            end_session(sid)
            print(f"[InferenceEngine] Session {sid} ended — exporting CSV…")
            try:
                csv_path = export_session(
                    session_id=sid,
                    export_dir=self.export_dir,
                    window_sec=WINDOW_SEC,
                    epoch_sec=self.epoch_sec,
                )
            except Exception as e:
                print(f"[InferenceEngine] CSV export failed: {e}")

        self._session_id  = None
        self._external_id = None
        return csv_path

    # ------------------------------------------------------------------ #
    #  Callback registration (used by api/server.py for SSE)
    # ------------------------------------------------------------------ #

    def on_score(self, callback: Callable):
        """
        Register a function called after each score is written to the DB.
        Signature: callback(record: ScoreRecord, snapshot: StudyContextSnapshot)
        """
        self._callbacks.append(callback)

    # ------------------------------------------------------------------ #
    #  Read-only accessors
    # ------------------------------------------------------------------ #

    def latest_scores(self, n: int = 10) -> list:
        with self._lock:
            return list(self._recent_scores)[-n:]

    @property
    def session_id(self) -> Optional[int]:
        return self._session_id

    @property
    def external_id(self) -> Optional[str]:
        return self._external_id

    @property
    def is_running(self) -> bool:
        return self._running

    def buffer_fill(self) -> float:
        """0.0–1.0 fraction of the 2-min window that has been collected."""
        return self.capture.get_buffer_fill()

    def set_content_demand(self, v: float):
        self.study_context.content_demand_score = v

    def set_cognitive_load(self, v: float):
        self.study_context.cognitive_load_score = v

    # ------------------------------------------------------------------ #
    #  Epoch loop (background thread)
    # ------------------------------------------------------------------ #

    def _epoch_loop(self):
        next_tick = time.time() + self.epoch_sec
        while self._running:
            sleep_for = next_tick - time.time()
            if sleep_for > 0:
                time.sleep(min(sleep_for, 1.0))  # wake at most every 1s to check _running
                continue
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

    def _run_epoch(self, window: np.ndarray, window_start: float, window_end: float):
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

        col = window.mean(axis=0)

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
            "score_id":        score_id,
            "session_id":      self._session_id,
            "external_id":     self._external_id,
            "window_start":    window_start,
            "window_end":      window_end,
            "score":           round(snap.focus_score, 2),
            "daisee_class":    snap.daisee_class,
            "confidence":      round(snap.confidence, 3),
            "inferred_state":  snap.inferred_state.value,
            "body_engagement": round(snap.body_engagement, 2),
            "mean_gaze":       round(record.mean_gaze, 3),
            "mean_head_yaw":   round(record.mean_head_yaw, 1),
            "mean_ear":        round(record.mean_ear, 3),
            "mean_kpm":        round(record.mean_kpm, 1),
            "mean_posture":    round(record.mean_posture, 3),
        }

        with self._lock:
            self._recent_scores.append(summary)

        fmt = lambda ts: datetime.datetime.fromtimestamp(ts).strftime("%H:%M:%S")
        print(
            f"[InferenceEngine] score={snap.focus_score:.1f} "
            f"state={snap.inferred_state.value} "
            f"window=[{fmt(window_start)} → {fmt(window_end)}]"
        )

        for cb in self._callbacks:
            try:
                cb(record, snap)
            except Exception as e:
                print(f"[InferenceEngine] Callback error: {e}")

    # ------------------------------------------------------------------ #
    #  Model loading & inference
    # ------------------------------------------------------------------ #

    def _load_model(self):
        try:
            import torch
            from models.engagement_lstm import load_model
            if WEIGHTS_PATH.exists():
                self._model = load_model(str(WEIGHTS_PATH), "cpu")
                self._model_loaded = True
                print("[InferenceEngine] Model loaded.")
            else:
                print("[InferenceEngine] No weights found — heuristic mode.")
        except ImportError:
            print("[InferenceEngine] PyTorch unavailable — heuristic mode.")

    def _infer(self, window: np.ndarray):
        if self._model_loaded:
            return self._lstm_infer(window)
        return self._heuristic_infer(window)

    def _lstm_infer(self, window: np.ndarray):
        import torch
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


# ── Module-level singleton ────────────────────────────────────────────────────
# Import and use directly, or let api/server.py manage it.
engine = InferenceEngine()
