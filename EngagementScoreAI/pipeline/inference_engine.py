"""
pipeline/inference_engine.py
------------------------------
Backend inference engine — externally controllable.

  Direct Python usage:
    from pipeline.inference_engine import engine
    session_id = engine.start(content_type="coding")
    ...
    csv_path = engine.stop()

  Via HTTP (api/server.py):
    POST /sessions/start  →  engine.start(...)
    POST /sessions/{id}/stop  →  engine.stop()

On stop():
  1. Marks session ended in SQLite
  2. Exports score stream to CSV
  3. Returns the Path to the CSV file

Window: equal to epoch_sec, non-overlapping clips
Epoch:  score written every epoch_sec seconds for each clip
"""

import time
import threading
import datetime
import numpy as np
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Callable, List
from collections import deque

from pipeline.webcam_capture import WebcamCapture, BehavioralAccumulator
from pipeline.study_context import StudyContext
from pipeline.behavioral_listener import start_listeners, stop_listeners
from pipeline.session_export import export_session, EXPORT_DIR
from db.store import init_db, create_session, end_session, insert_score

WEIGHTS_PATH      = Path(__file__).parent.parent / "weights" / "engagement_lstm.pt"
FPS_DEFAULT       = 10
EPOCH_SEC_DEFAULT = 30.0


@dataclass
class ScoreRecord:
    session_id: int
    window_start: float
    window_end: float
    score: float
    body_engagement: float
    daisee_class: str
    inferred_state: Optional[str]
    confidence: float


class InferenceEngine:

    def __init__(
        self,
        camera_index: int = 0,
        fps: int = FPS_DEFAULT,
        epoch_sec: float = EPOCH_SEC_DEFAULT,
        export_dir: Optional[Path] = None,
    ):
        self.fps           = fps
        self.epoch_sec     = epoch_sec
        self.window_frames = max(1, int(self.epoch_sec * fps))
        self.camera_index  = camera_index
        self.export_dir    = export_dir or EXPORT_DIR

        self.behavioral = BehavioralAccumulator()
        self.capture    = None
        self.study_context = StudyContext()

        self._model        = None
        self._model_loaded = False

        self._session_id: Optional[int]                = None
        self._external_id: Optional[str]               = None
        self._running      = False
        self._epoch_thread: Optional[threading.Thread] = None
        self._lock         = threading.Lock()

        self._kb_listener = None
        self._ms_listener = None

        self._callbacks: List[Callable]  = []
        self._recent_scores: deque       = deque(maxlen=20)

        init_db()
        self._load_model()

    def _build_capture(self):
        self.window_frames = max(1, int(self.epoch_sec * self.fps))
        self.capture = WebcamCapture(
            fps=self.fps,
            window_size=self.window_frames,
            camera_index=self.camera_index,
            behavioral=self.behavioral,
        )

    # ------------------------------------------------------------------ #
    #  External control API
    # ------------------------------------------------------------------ #

    def start(
        self,
        content_type: str     = "general",
        content_demand: float = 50.0,
        cognitive_load: float = 50.0,
        session_id: Optional[str] = None,
    ) -> int:
        if self._running:
            raise RuntimeError(
                f"Engine already running (session {self._session_id}). "
                "Call stop() first."
            )

        self._external_id = session_id

        db_content_type = f"{content_type}:{session_id}" if session_id else content_type
        self._session_id   = create_session(content_type=db_content_type)
        self.study_context = StudyContext(content_type=content_type)
        self.study_context.content_demand_score = content_demand
        self.study_context.cognitive_load_score  = cognitive_load

        self._running = True
        self._build_capture()
        self.capture.start()
        self._kb_listener, self._ms_listener = start_listeners(self.behavioral)

        self._epoch_thread = threading.Thread(
            target=self._epoch_loop, daemon=True, name="epoch-loop"
        )
        self._epoch_thread.start()

        print(
            f"[InferenceEngine] Session {self._session_id} started"
            + (f" (external_id={session_id})" if session_id else "")
            + f" | window={self.epoch_sec}s epoch={self.epoch_sec}s fps={self.fps}"
        )
        return self._session_id

    def stop(self) -> Optional[Path]:
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
                )
            except Exception as e:
                print(f"[InferenceEngine] CSV export failed: {e}")

        self._session_id  = None
        self._external_id = None
        return csv_path

    # ------------------------------------------------------------------ #
    #  Callbacks & accessors
    # ------------------------------------------------------------------ #

    def on_score(self, callback: Callable):
        """Register callback(record, snapshot) called after each score write."""
        self._callbacks.append(callback)

    def latest_scores(self, n: int = 10) -> List[float]:
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
        return self.capture.get_buffer_fill() if self.capture else 0.0

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
                time.sleep(min(sleep_for, 1.0))
                continue

            if not self._running:
                break

            window = self.capture.get_window()
            if window is None:
                pct = self.capture.get_buffer_fill() * 100
                print(f"[InferenceEngine] Buffer filling… {pct:.0f}% of {self.epoch_sec}s")
                time.sleep(0.5)
                continue

            window_end   = time.time()
            window_start = window_end - self.epoch_sec
            self._run_epoch(window, window_start, window_end)
            next_tick = window_end + self.epoch_sec

    def _run_epoch(self, window: np.ndarray, window_start: float, window_end: float):
        score, cls, conf = self._infer(window)
        snapshot = self.study_context.update(score, cls, conf)
        record = ScoreRecord(
            session_id=self._session_id,
            window_start=window_start,
            window_end=window_end,
            score=round(score, 2),
            body_engagement=snapshot.body_engagement,
            daisee_class=snapshot.daisee_class,
            inferred_state=snapshot.inferred_state,
            confidence=snapshot.confidence,
        )

        insert_score(
            session_id=self._session_id,
            window_start=window_start,
            window_end=window_end,
            score=record.score,
        )

        with self._lock:
            self._recent_scores.append(record.score)

        fmt = lambda ts: datetime.datetime.fromtimestamp(ts).strftime("%H:%M:%S")
        print(
            f"[InferenceEngine] score={record.score:.1f} "
            f"window=[{fmt(window_start)} → {fmt(window_end)}]"
        )

        for cb in self._callbacks:
            try:
                cb(record, snapshot)
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


engine = InferenceEngine()
