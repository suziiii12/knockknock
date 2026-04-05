"""
pipeline/session_export.py
---------------------------
Writes a session's score stream to a CSV file on session end.

Filename:  exports/session_{id}_{YYYYMMDD_HHMMSS}.csv
           where the timestamp is the session START time.

CSV columns:
    score
"""

import csv
import datetime
from pathlib import Path
from typing import Optional

from db.store import get_session, get_scores

EXPORT_DIR = Path(__file__).parent.parent / "exports"


def export_session(
    session_id: int,
    export_dir: Optional[Path] = None,
    **kwargs,
) -> Path:
    out_dir = export_dir or EXPORT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    session = get_session(session_id)
    if not session:
        raise ValueError(f"Session {session_id} not found in database.")

    scores = get_scores(session_id)   # List[float]

    started_at = session.get("started_at")
    timestamp  = datetime.datetime.fromtimestamp(started_at).strftime("%Y%m%d_%H%M%S")
    out_path   = out_dir / f"session_{session_id}_{timestamp}.csv"

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["score"])
        for score in scores:
            writer.writerow([score])

    print(f"[SessionExport] Wrote {len(scores)} scores → {out_path}")
    return out_path
