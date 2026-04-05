"""
api/server.py
--------------
FastAPI backend server.

Endpoints
---------
POST   /sessions/start              Start a new session, returns session_id
POST   /sessions/stop               Stop the current session
GET    /sessions                    List all sessions
GET    /sessions/{id}               Get session metadata
GET    /sessions/{id}/scores        Get all scores for a session
GET    /sessions/{id}/scores/latest Get most recent score
GET    /sessions/{id}/stats         Aggregate stats / insight card data
GET    /status                      Engine status (running, buffer fill, etc.)
GET    /stream                      Server-Sent Events — push scores in real time

Usage
-----
    uvicorn api.server:app --host 0.0.0.0 --port 8000 --reload
"""

import asyncio
import json
import time
from contextlib import asynccontextmanager
from typing import Optional, AsyncGenerator

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from knockknock.EngagementScoreAI.pipeline.inference_engine import InferenceEngine
from knockknock.EngagementScoreAI.db.store import (
    get_session, list_sessions, get_scores,
    get_latest_score, session_stats,
)

# ── Engine singleton ──────────────────────────────────────────────────────────
engine = InferenceEngine(
    camera_index=0,
    fps=10,
    epoch_sec=30.0,   # score written every 30s, each covering trailing 2 min
)

# SSE subscriber queues — one asyncio.Queue per connected client
_sse_subscribers: list[asyncio.Queue] = []


def _on_score(record, snapshot):
    """Called by InferenceEngine after each DB write. Pushes to SSE clients."""
    payload = {
        "event":          "score",
        "session_id":     record.session_id,
        "window_start":   record.window_start,
        "window_end":     record.window_end,
        "score":          round(record.score, 2),
        "daisee_class":   record.daisee_class,
        "inferred_state": record.inferred_state,
        "body_engagement":round(record.body_engagement, 2),
        "confidence":     round(record.confidence, 3),
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
    # Nothing auto-starts — caller hits /sessions/start
    yield
    # Shutdown: stop engine if still running
    if engine.is_running:
        engine.stop()


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Focus Score Pipeline API",
    version="1.0.0",
    description="Real-time engagement scoring backend. 2-minute rolling window.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # restrict in production
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response models ─────────────────────────────────────────────────
class StartRequest(BaseModel):
    content_type:   str   = "general"
    content_demand: float = 50.0
    cognitive_load: float = 50.0


class StatusResponse(BaseModel):
    running:       bool
    session_id:    Optional[int]
    buffer_fill:   float           # 0–1, how full the 2-min window is
    buffer_sec:    float           # seconds of data collected so far
    window_sec:    int             # always 120
    epoch_sec:     float           # score emitted every N seconds


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/status", response_model=StatusResponse, tags=["engine"])
def status():
    fill = engine.buffer_fill()
    return {
        "running":     engine.is_running,
        "session_id":  engine.session_id,
        "buffer_fill": round(fill, 3),
        "buffer_sec":  round(fill * 120, 1),
        "window_sec":  120,
        "epoch_sec":   engine.epoch_sec,
    }


@app.post("/sessions/start", tags=["sessions"])
def start_session(body: StartRequest):
    if engine.is_running:
        raise HTTPException(409, "A session is already running. POST /sessions/stop first.")

    engine.set_content_demand(body.content_demand)
    engine.set_cognitive_load(body.cognitive_load)

    session_id = engine.start(content_type=body.content_type)
    return {
        "session_id":  session_id,
        "started_at":  time.time(),
        "content_type":body.content_type,
        "window_sec":  120,
        "epoch_sec":   engine.epoch_sec,
        "message":     f"Session {session_id} started. "
                       f"First score in ~{engine.epoch_sec:.0f}s "
                       f"(window fills over 120s).",
    }


@app.post("/sessions/stop", tags=["sessions"])
def stop_session():
    if not engine.is_running:
        raise HTTPException(409, "No session is running.")
    sid = engine.session_id
    engine.stop()
    return {"message": f"Session {sid} stopped.", "session_id": sid}


@app.get("/sessions", tags=["sessions"])
def sessions():
    return list_sessions()


@app.get("/sessions/{session_id}", tags=["sessions"])
def session(session_id: int):
    s = get_session(session_id)
    if not s:
        raise HTTPException(404, f"Session {session_id} not found.")
    return s


@app.get("/sessions/{session_id}/scores", tags=["scores"])
def scores(
    session_id: int,
    since: Optional[float] = Query(None, description="Unix timestamp — return scores after this time"),
    limit: int = Query(200, le=1000),
):
    s = get_session(session_id)
    if not s:
        raise HTTPException(404, f"Session {session_id} not found.")
    return get_scores(session_id, since=since, limit=limit)


@app.get("/sessions/{session_id}/scores/latest", tags=["scores"])
def latest_score(session_id: int):
    s = get_session(session_id)
    if not s:
        raise HTTPException(404, f"Session {session_id} not found.")
    score = get_latest_score(session_id)
    if not score:
        raise HTTPException(404, "No scores recorded yet for this session.")
    return score


@app.get("/sessions/{session_id}/stats", tags=["scores"])
def stats(session_id: int):
    s = get_session(session_id)
    if not s:
        raise HTTPException(404, f"Session {session_id} not found.")
    return session_stats(session_id)


# ── Server-Sent Events ────────────────────────────────────────────────────────

@app.get("/stream", tags=["realtime"],
         summary="SSE stream — receive scores as they are written")
async def stream():
    """
    Connect to receive scores in real time via Server-Sent Events.

    Each event is a JSON object:
    {
        "event": "score",
        "session_id": 1,
        "window_start": 1712345678.0,
        "window_end":   1712345798.0,
        "score": 73.4,
        "daisee_class": "high",
        "inferred_state": "focused",
        "body_engagement": 71.2,
        "confidence": 0.84
    }

    JavaScript example:
        const es = new EventSource('http://localhost:8000/stream');
        es.onmessage = e => console.log(JSON.parse(e.data));
    """
    queue: asyncio.Queue = asyncio.Queue(maxsize=50)
    _sse_subscribers.append(queue)

    async def event_generator() -> AsyncGenerator[str, None]:
        try:
            # Send a hello event immediately so the client knows it's connected
            yield _sse_fmt({"event": "connected", "message": "Focus stream ready"})

            while True:
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=25.0)
                    yield _sse_fmt(payload)
                except asyncio.TimeoutError:
                    # Keep-alive ping every 25s
                    yield ": ping\n\n"
        except asyncio.CancelledError:
            pass
        finally:
            _sse_subscribers.remove(queue)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering
        },
    )


def _sse_fmt(payload: dict) -> str:
    return f"data: {json.dumps(payload)}\n\n"
