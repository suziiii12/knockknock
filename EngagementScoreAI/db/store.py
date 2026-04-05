"""
db/store.py
-----------
SQLite storage for engagement score windows.

Schema
------
sessions
  id            INTEGER PK
  started_at    REAL    (unix timestamp)
  ended_at      REAL    (unix timestamp, NULL while active)
  content_type  TEXT

scores
  id            INTEGER PK
  session_id    INTEGER FK → sessions.id
  window_start  REAL    (unix timestamp — start of the 2-min window)
  window_end    REAL    (unix timestamp — end of the 2-min window)
  recorded_at   REAL    (unix timestamp — when score was written)
  score         REAL    (0–100)
  daisee_class  TEXT    (very_low / low / high / very_high)
  confidence    REAL    (0–1)
  inferred_state TEXT
  body_engagement REAL
  -- raw signal means over the window
  mean_gaze     REAL
  mean_head_yaw REAL
  mean_ear      REAL
  mean_kpm      REAL
  mean_posture  REAL
"""

import sqlite3
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

DB_PATH = Path(__file__).parent / "focus.db"


def init_db(path: Path = DB_PATH):
    """Create tables if they don't exist."""
    with _connect(path) as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS sessions (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at   REAL    NOT NULL,
                ended_at     REAL,
                content_type TEXT    NOT NULL DEFAULT 'general'
            );

            CREATE TABLE IF NOT EXISTS scores (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id      INTEGER NOT NULL REFERENCES sessions(id),
                window_start    REAL    NOT NULL,
                window_end      REAL    NOT NULL,
                recorded_at     REAL    NOT NULL,
                score           REAL    NOT NULL,
                daisee_class    TEXT    NOT NULL,
                confidence      REAL    NOT NULL,
                inferred_state  TEXT    NOT NULL,
                body_engagement REAL    NOT NULL,
                mean_gaze       REAL,
                mean_head_yaw   REAL,
                mean_ear        REAL,
                mean_kpm        REAL,
                mean_posture    REAL
            );

            CREATE INDEX IF NOT EXISTS idx_scores_session
                ON scores(session_id);
            CREATE INDEX IF NOT EXISTS idx_scores_window_start
                ON scores(window_start);
        """)


@contextmanager
def _connect(path: Path = DB_PATH):
    conn = sqlite3.connect(str(path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ── Sessions ──────────────────────────────────────────────────────────────────

def create_session(content_type: str = "general", path: Path = DB_PATH) -> int:
    with _connect(path) as conn:
        cur = conn.execute(
            "INSERT INTO sessions (started_at, content_type) VALUES (?, ?)",
            (time.time(), content_type),
        )
        return cur.lastrowid


def end_session(session_id: int, path: Path = DB_PATH):
    with _connect(path) as conn:
        conn.execute(
            "UPDATE sessions SET ended_at = ? WHERE id = ?",
            (time.time(), session_id),
        )


def get_session(session_id: int, path: Path = DB_PATH) -> Optional[dict]:
    with _connect(path) as conn:
        row = conn.execute(
            "SELECT * FROM sessions WHERE id = ?", (session_id,)
        ).fetchone()
        return dict(row) if row else None


def list_sessions(path: Path = DB_PATH) -> List[dict]:
    with _connect(path) as conn:
        rows = conn.execute(
            "SELECT * FROM sessions ORDER BY started_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]


# ── Scores ────────────────────────────────────────────────────────────────────

@dataclass
class ScoreRecord:
    session_id:      int
    window_start:    float
    window_end:      float
    score:           float
    daisee_class:    str
    confidence:      float
    inferred_state:  str
    body_engagement: float
    mean_gaze:       float = 0.0
    mean_head_yaw:   float = 0.0
    mean_ear:        float = 0.0
    mean_kpm:        float = 0.0
    mean_posture:    float = 0.0


def insert_score(record: ScoreRecord, path: Path = DB_PATH) -> int:
    with _connect(path) as conn:
        cur = conn.execute(
            """INSERT INTO scores (
                session_id, window_start, window_end, recorded_at,
                score, daisee_class, confidence, inferred_state,
                body_engagement, mean_gaze, mean_head_yaw,
                mean_ear, mean_kpm, mean_posture
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                record.session_id,
                record.window_start,
                record.window_end,
                time.time(),
                round(record.score, 2),
                record.daisee_class,
                round(record.confidence, 4),
                record.inferred_state,
                round(record.body_engagement, 2),
                round(record.mean_gaze, 4),
                round(record.mean_head_yaw, 4),
                round(record.mean_ear, 4),
                round(record.mean_kpm, 4),
                round(record.mean_posture, 4),
            ),
        )
        return cur.lastrowid


def get_scores(
    session_id: int,
    since: Optional[float] = None,
    limit: int = 200,
    path: Path = DB_PATH,
) -> List[dict]:
    with _connect(path) as conn:
        if since:
            rows = conn.execute(
                """SELECT * FROM scores
                   WHERE session_id = ? AND window_start >= ?
                   ORDER BY window_start ASC LIMIT ?""",
                (session_id, since, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """SELECT * FROM scores
                   WHERE session_id = ?
                   ORDER BY window_start ASC LIMIT ?""",
                (session_id, limit),
            ).fetchall()
        return [dict(r) for r in rows]


def get_latest_score(session_id: int, path: Path = DB_PATH) -> Optional[dict]:
    with _connect(path) as conn:
        row = conn.execute(
            """SELECT * FROM scores WHERE session_id = ?
               ORDER BY window_start DESC LIMIT 1""",
            (session_id,),
        ).fetchone()
        return dict(row) if row else None


def session_stats(session_id: int, path: Path = DB_PATH) -> dict:
    """Aggregate stats for the session summary / insight card."""
    with _connect(path) as conn:
        row = conn.execute(
            """SELECT
                COUNT(*)            AS total_windows,
                AVG(score)          AS avg_score,
                MAX(score)          AS peak_score,
                MIN(score)          AS trough_score,
                AVG(mean_gaze)      AS avg_gaze,
                AVG(mean_kpm)       AS avg_kpm,
                AVG(mean_posture)   AS avg_posture,
                SUM(CASE WHEN inferred_state IN ('flow_state','focused')
                         THEN 1 ELSE 0 END) * 1.0 / COUNT(*) * 100
                                    AS pct_focused,
                SUM(CASE WHEN inferred_state = 'flow_state'
                         THEN 1 ELSE 0 END) * 1.0 / COUNT(*) * 100
                                    AS pct_flow,
                SUM(CASE WHEN inferred_state IN
                         ('disengaged','invisible_distraction')
                         THEN 1 ELSE 0 END) * 1.0 / COUNT(*) * 100
                                    AS pct_distracted
               FROM scores WHERE session_id = ?""",
            (session_id,),
        ).fetchone()

        # Duration from session table
        sess = conn.execute(
            "SELECT started_at, ended_at FROM sessions WHERE id = ?",
            (session_id,),
        ).fetchone()

        duration_min = 0.0
        if sess:
            end = sess["ended_at"] or time.time()
            duration_min = (end - sess["started_at"]) / 60.0

        result = dict(row) if row else {}
        result["duration_min"] = round(duration_min, 1)
        return {k: (round(v, 2) if isinstance(v, float) else v)
                for k, v in result.items()}
