"""
db/store.py
-----------
CSV storage for focus sessions and their score streams.

Session files:
    exports/session_{id}_{YYYYMMDD_HHMMSS}.csv

CSV columns:
    score
"""

import csv
import datetime
import re
import time
from pathlib import Path
from typing import Dict, List, Optional

EXPORT_DIR = Path(__file__).parent.parent / "exports"
SESSION_FILENAME_RE = re.compile(r"^session_(\d+)_(\d{8}_\d{6})\.csv$")
_active_sessions: Dict[int, Dict] = {}


def init_db(path: Optional[Path] = None):
    """Initialize storage for session CSV exports."""
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)


def _ensure_exports_dir():
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)


def _format_timestamp(ts: float) -> str:
    return datetime.datetime.fromtimestamp(ts).strftime("%Y%m%d_%H%M%S")


def _session_path(session_id: int, started_at: float) -> Path:
    return EXPORT_DIR / f"session_{session_id}_{_format_timestamp(started_at)}.csv"


def _parse_session_file(path: Path) -> Optional[Dict]:
    match = SESSION_FILENAME_RE.match(path.name)
    if not match:
        return None
    session_id = int(match.group(1))
    started_at = datetime.datetime.strptime(match.group(2), "%Y%m%d_%H%M%S").timestamp()
    return {
        "id": session_id,
        "started_at": started_at,
        "ended_at": path.stat().st_mtime,
        "content_type": "general",
        "path": path,
    }


def _load_export_sessions() -> List[Dict]:
    if not EXPORT_DIR.exists():
        return []
    sessions = []
    for path in EXPORT_DIR.iterdir():
        if not path.is_file():
            continue
        info = _parse_session_file(path)
        if info:
            sessions.append(info)
    return sessions


def _session_file(session_id: int) -> Optional[Path]:
    active = _active_sessions.get(session_id)
    if active:
        return active["path"]
    for session in _load_export_sessions():
        if session["id"] == session_id:
            return session["path"]
    return None


# ── Sessions ──────────────────────────────────────────────────────────────────

def create_session(content_type: str = "general", path: Optional[Path] = None) -> int:
    _ensure_exports_dir()
    existing_ids = [session["id"] for session in _load_export_sessions()]
    next_id = max(existing_ids, default=0) + 1
    started_at = time.time()
    session_path = _session_path(next_id, started_at)

    with open(session_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["score"])

    _active_sessions[next_id] = {
        "id": next_id,
        "started_at": started_at,
        "ended_at": None,
        "content_type": content_type,
        "path": session_path,
    }
    return next_id


def end_session(session_id: int, path: Optional[Path] = None):
    session = _active_sessions.get(session_id)
    if session:
        session["ended_at"] = time.time()
        _active_sessions.pop(session_id, None)


def get_session(session_id: int, path: Optional[Path] = None) -> Optional[Dict]:
    session = _active_sessions.get(session_id)
    if session:
        return {
            "id": session["id"],
            "started_at": session["started_at"],
            "ended_at": session["ended_at"],
            "content_type": session["content_type"],
        }

    session_file = _session_file(session_id)
    if not session_file:
        return None

    info = _parse_session_file(session_file)
    if info:
        return {
            "id": info["id"],
            "started_at": info["started_at"],
            "ended_at": info["ended_at"],
            "content_type": info["content_type"],
        }
    return None


def list_sessions(path: Optional[Path] = None) -> List[Dict]:
    sessions = {session["id"]: session for session in _load_export_sessions()}
    for session_id, active in _active_sessions.items():
        sessions[session_id] = {
            "id": active["id"],
            "started_at": active["started_at"],
            "ended_at": active["ended_at"],
            "content_type": active["content_type"],
        }
    return sorted(sessions.values(), key=lambda item: item["started_at"], reverse=True)


# ── Scores ────────────────────────────────────────────────────────────────────

def insert_score(
    session_id: int,
    window_start: float,
    window_end: float,
    score: float,
    path: Optional[Path] = None,
) -> int:
    session_path = _session_file(session_id)
    if session_path is None:
        raise ValueError(f"Session {session_id} not found.")

    score_value = round(score, 2)
    with open(session_path, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([score_value])

    return sum(1 for _ in open(session_path, "r", encoding="utf-8")) - 1


def _read_scores(session_id: int) -> List[float]:
    session_path = _session_file(session_id)
    if session_path is None:
        raise ValueError(f"Session {session_id} not found.")

    with open(session_path, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader, None)
        return [float(row[0]) for row in reader if row]


def get_scores(
    session_id: int,
    path: Optional[Path] = None,
    since: Optional[float] = None,
    limit: Optional[int] = None,
) -> List[float]:
    scores = _read_scores(session_id)
    if limit is not None:
        scores = scores[:limit]
    return scores


def get_latest_score(session_id: int, path: Optional[Path] = None) -> Optional[float]:
    scores = _read_scores(session_id)
    return scores[-1] if scores else None


def session_stats(session_id: int) -> Dict[str, Optional[float]]:
    scores = _read_scores(session_id)
    if not scores:
        return {
            "count": 0,
            "min": None,
            "max": None,
            "mean": None,
            "latest": None,
        }
    return {
        "count": len(scores),
        "min": min(scores),
        "max": max(scores),
        "mean": sum(scores) / len(scores),
        "latest": scores[-1],
    }
