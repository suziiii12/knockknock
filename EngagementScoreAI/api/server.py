"""
api/server.py
--------------
FastAPI server wrapping InferenceEngine for external backend control.

The engine can be driven two ways:
  1. HTTP  — any backend POSTs to /sessions/start and /sessions/stop
  2. Python — import engine and call engine.start() / engine.stop() directly

On session stop, the engine automatically writes:
    exports/session_{id}_{TIMESTAMP}.csv

Endpoints
---------
POST  /sessions/start                 Start a session
POST  /sessions/{session_id}/stop     Stop a specific session
GET   /sessions                       List all sessions
GET   /sessions/{session_id}          Session metadata
GET   /sessions/{session_id}/scores   All scores for a session
GET   /sessions/{session_id}/scores/latest
GET   /sessions/{session_id}/stats    Aggregated stats
GET   /sessions/{session_id}/export   Re-export a past session to JSON
GET   /status                         Engine status
GET   /stream                         SSE — real-time score push

Run:
    uvicorn api.server:app --host 0.0.0.0 --port 8000 --reload
"""

import asyncio
import json
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional, AsyncGenerator

from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
from pydantic import BaseModel, Field

from pipeline.inference_engine import engine
from pipeline.session_export import export_session
from db.store import (
    get_session, list_sessions, get_scores,
    get_latest_score, session_stats,
)

# ── SSE subscribers ───────────────────────────────────────────────────────────
_sse_subscribers: list[asyncio.Queue] = []


def _on_score(record, snapshot):
    """Registered with engine — pushes each score to all SSE clients."""
    payload = {
        "event":           "score",
        "session_id":      record.session_id,
        "external_id":     engine.external_id,
        "window_start":    record.window_start,
        "window_end":      record.window_end,
        "score":           round(record.score, 2),
        "daisee_class":    record.daisee_class,
        "inferred_state":  record.inferred_state,
        "body_engagement": round(record.body_engagement, 2),
        "confidence":      round(record.confidence, 3),
    }
    for q in list(_sse_subscribers):
        try:
            q.put_nowait(payload)
        except asyncio.QueueFull:
            pass


engine.on_score(_on_score)


# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    if engine.is_running:
        engine.stop()


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Focus Score Pipeline",
    version="2.0.0",
    description=(
        "Real-time student engagement scoring backend. "
        "2-minute rolling window. "
        "Sessions started/stopped by external backend. "
        "Scores exported to JSON on session end."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic models ───────────────────────────────────────────────────────────

class StartRequest(BaseModel):
    content_type:    str   = Field("general", description="coding | reading | video | math | general")
    content_demand:  float = Field(50.0, ge=0, le=100, description="TRIBE v2 score (0–100)")
    cognitive_load:  float = Field(50.0, ge=0, le=100, description="Pupil tracker score (0–100)")
    external_session_id: Optional[str] = Field(
        None,
        description=(
            "ID from your external backend (e.g. a study-session UUID). "
            "Stored alongside scores for cross-system traceability."
        ),
    )


class StartResponse(BaseModel):
    session_id:          int
    external_session_id: Optional[str]
    started_at:          float
    content_type:        str
    window_sec:          float
    epoch_sec:           float
    message:             str


class StopResponse(BaseModel):
    session_id:   int
    stopped_at:   float
    csv_export:   Optional[str]   # absolute path to the CSV file
    message:      str


class StatusResponse(BaseModel):
    running:       bool
    session_id:    Optional[int]
    external_id:   Optional[str]
    buffer_fill:   float
    buffer_sec:    float
    window_sec:    int
    epoch_sec:     float


# ── Status ────────────────────────────────────────────────────────────────────

@app.get("/status", response_model=StatusResponse, tags=["engine"])
def status():
    fill = engine.buffer_fill()
    return {
        "running":     engine.is_running,
        "session_id":  engine.session_id,
        "external_id": engine.external_id,
        "buffer_fill": round(fill, 3),
        "buffer_sec":  round(fill * engine.epoch_sec, 1),
        "window_sec":  engine.epoch_sec,
        "epoch_sec":   engine.epoch_sec,
    }


# ── Session control ───────────────────────────────────────────────────────────

@app.post("/sessions/start", response_model=StartResponse, tags=["control"])
def start_session(body: StartRequest):
    """
    Start the focus pipeline. Call this from your external backend when a
    study session begins.

    The pipeline will:
      - Open the laptop webcam
      - Start the feature extraction + LSTM inference loop
      - Write a score to the DB every {epoch_sec} seconds
      - Each score covers the trailing 2-minute window
    """
    if engine.is_running:
        raise HTTPException(
            409,
            detail={
                "error":      "session_already_running",
                "session_id": engine.session_id,
                "message":    f"Session {engine.session_id} is active. "
                              f"POST /sessions/{engine.session_id}/stop first.",
            },
        )

    session_id = engine.start(
        content_type=body.content_type,
        content_demand=body.content_demand,
        cognitive_load=body.cognitive_load,
        session_id=body.external_session_id,
    )

    return {
        "session_id":          session_id,
        "external_session_id": body.external_session_id,
        "started_at":          time.time(),
        "content_type":        body.content_type,
        "window_sec":          engine.epoch_sec,
        "epoch_sec":           engine.epoch_sec,
        "message":             (
            f"Session {session_id} started. "
            f"First score emitted after {engine.epoch_sec:.0f}s. "
            f"Window length set to {engine.epoch_sec:.0f}s, matching epoch duration. "
            f"Scores exported to CSV on stop."
        ),
    }


@app.post("/sessions/{session_id}/stop", response_model=StopResponse, tags=["control"])
def stop_session(session_id: int):
    """
    Stop the focus pipeline and export scores to JSON.

    Call this from your external backend when the study session ends.

    Returns the path to the exported JSON file containing the full
    sequence of engagement scores for this session.
    """
    if not engine.is_running:
        raise HTTPException(
            409,
            detail={
                "error":   "no_active_session",
                "message": "No session is currently running.",
            },
        )

    if engine.session_id != session_id:
        raise HTTPException(
            409,
            detail={
                "error":              "session_id_mismatch",
                "active_session_id":  engine.session_id,
                "requested_id":       session_id,
                "message": (
                    f"Active session is {engine.session_id}, not {session_id}. "
                    f"POST /sessions/{engine.session_id}/stop to stop it."
                ),
            },
        )

    json_path = engine.stop()

    return {
        "session_id":  session_id,
        "stopped_at":  time.time(),
        "csv_export": str(json_path) if json_path else None,
        "message": (
            f"Session {session_id} stopped. "
            + (f"Scores exported → {json_path}" if json_path else "No scores recorded.")
        ),
    }


# ── Session queries ───────────────────────────────────────────────────────────

@app.get("/sessions", tags=["sessions"])
def sessions():
    """List all sessions (past and current)."""
    return list_sessions()


@app.get("/sessions/{session_id}", tags=["sessions"])
def session(session_id: int):
    s = get_session(session_id)
    if not s:
        raise HTTPException(404, f"Session {session_id} not found.")
    return s


@app.get("/sessions/{session_id}/scores", tags=["sessions"])
def scores(
    session_id: int,
    since: Optional[float] = Query(None, description="Unix timestamp — scores after this time only"),
    limit: int = Query(200, le=1000),
):
    """Return the score sequence for a session."""
    if not get_session(session_id):
        raise HTTPException(404, f"Session {session_id} not found.")
    return get_scores(session_id, since=since, limit=limit)


@app.get("/sessions/{session_id}/scores/latest", tags=["sessions"])
def latest_score(session_id: int):
    if not get_session(session_id):
        raise HTTPException(404, f"Session {session_id} not found.")
    score = get_latest_score(session_id)
    if not score:
        raise HTTPException(404, "No scores recorded yet.")
    return score


@app.get("/sessions/{session_id}/stats", tags=["sessions"])
def stats(session_id: int):
    """Aggregated stats for the session insight card."""
    if not get_session(session_id):
        raise HTTPException(404, f"Session {session_id} not found.")
    return session_stats(session_id)


@app.get("/sessions/{session_id}/export", tags=["sessions"])
def export(session_id: int, background_tasks: BackgroundTasks):
    """
    Re-export a past session's scores to a fresh JSON file.
    Returns the file path. Useful if you need to regenerate the export.
    """
    if not get_session(session_id):
        raise HTTPException(404, f"Session {session_id} not found.")
    try:
        path = export_session(session_id)
        return {"csv_export": str(path), "message": f"Exported → {path}"}
    except Exception as e:
        raise HTTPException(500, f"Export failed: {e}")


# ── SSE stream ────────────────────────────────────────────────────────────────

@app.get("/stream", tags=["realtime"],
         summary="SSE — receive scores in real time as they are written")
async def stream():
    """
    Server-Sent Events endpoint. Each event is a JSON score object.

    Connect from your frontend:
        const es = new EventSource('http://localhost:8000/stream');
        es.onmessage = e => {
            const { score, inferred_state, window_start, window_end } = JSON.parse(e.data);
        };
    """
    queue: asyncio.Queue = asyncio.Queue(maxsize=50)
    _sse_subscribers.append(queue)

    async def generate() -> AsyncGenerator[str, None]:
        try:
            yield _sse({"event": "connected", "message": "Focus stream active"})
            while True:
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=25.0)
                    yield _sse(payload)
                except asyncio.TimeoutError:
                    yield ": ping\n\n"
        except asyncio.CancelledError:
            pass
        finally:
            if queue in _sse_subscribers:
                _sse_subscribers.remove(queue)

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


def _sse(payload: dict) -> str:
    return f"data: {json.dumps(payload)}\n\n"
