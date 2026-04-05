"""
run_session.py — FocusLens session orchestrator
================================================
Called by the frontend/backend to start a study session.

Usage:
    python run_session.py --duration 3600 --user_id user_123 --backend_url https://your-backend.com

What it does:
    1. Starts LSTM pipeline (webcam engagement scoring)
    2. Starts FocusLens Swift app recording (screen + TRIBE v2 + Claude gate)
    3. Waits for session to complete
    4. Reads engagement scores from LSTM CSV export
    5. Polls FocusLens for session summary (focus scores per clip)
    6. Sends session_score + focus_score sequence to backend DB
    7. Prints final summary

Ports:
    localhost:8000  — LSTM FastAPI server (focus_pipeline)
    localhost:9876  — FocusLens Swift app control server
    BACKEND_URL     — your game/app backend
"""

import argparse
import requests
import time
import sys
import threading
import json
from datetime import datetime
from pathlib import Path


# ── Config ────────────────────────────────────────────────────────────────────

LSTM_URL       = "http://localhost:8000"
FOCUSLENS_URL  = "http://localhost:9876"
POLL_INTERVAL  = 5    # seconds between summary polls
MAX_POLL_WAIT  = 300  # max seconds to wait for summary after session ends


# ── LSTM pipeline ─────────────────────────────────────────────────────────────

class LSTMPipeline:
    def __init__(self):
        self.session_id = None

    def start(self, duration: int, user_id: str, content_type: str = "studying") -> bool:
        """Start LSTM session via FastAPI server."""
        try:
            r = requests.post(
                f"{LSTM_URL}/sessions/start",
                json={
                    "content_type":       content_type,
                    "external_session_id": f"{user_id}_{int(time.time())}",
                },
                timeout=10
            )
            r.raise_for_status()
            data = r.json()
            self.session_id = data.get("session_id")
            print(f"[lstm] Started — session_id={self.session_id}")
            return True
        except Exception as e:
            print(f"[lstm] Failed to start: {e}")
            print(f"[lstm] Make sure focus_pipeline server is running:")
            print(f"       cd focus_pipeline && source venv/bin/activate")
            print(f"       uvicorn api.server:app --host 0.0.0.0 --port 8000")
            return False

    def stop(self) -> str | None:
        """Stop LSTM session — returns CSV export path."""
        if not self.session_id:
            return None
        try:
            r = requests.post(
                f"{LSTM_URL}/sessions/{self.session_id}/stop",
                timeout=30
            )
            r.raise_for_status()
            data = r.json()
            csv_path = data.get("csv_export")
            print(f"[lstm] Stopped — export: {csv_path}")
            return csv_path
        except Exception as e:
            print(f"[lstm] Failed to stop: {e}")
            return None

    def read_scores(self, csv_path: str) -> list[float]:
        """
        Read engagement scores from CSV.
        Format: "scores","67.5","37.5",...
        Returns list of floats.
        """
        path = Path(csv_path).expanduser()
        if not path.exists():
            print(f"[lstm] CSV not found: {path}")
            return []

        scores = []
        try:
            content = path.read_text(encoding="utf-8")
            for line in content.splitlines():
                cleaned = line.replace('"', '')
                parts   = cleaned.split(",")
                # skip header row
                if parts and parts[0].strip().lower() == "scores":
                    for part in parts[1:]:
                        v = part.strip()
                        if v:
                            try: scores.append(float(v))
                            except ValueError: pass
                    continue
                # data rows
                for part in parts:
                    v = part.strip()
                    if v:
                        try: scores.append(float(v))
                        except ValueError: pass
        except Exception as e:
            print(f"[lstm] Failed to read CSV: {e}")

        print(f"[lstm] Read {len(scores)} engagement scores")
        return scores


# ── FocusLens pipeline ────────────────────────────────────────────────────────

class FocusLensPipeline:

    def start(self, duration: int) -> bool:
        """Tell FocusLens Swift app to start recording for duration seconds."""
        try:
            r = requests.post(
                f"{FOCUSLENS_URL}/start_timed",
                json={"duration": duration},
                timeout=10
            )
            r.raise_for_status()
            print(f"[focuslens] Started — {r.json()}")
            return True
        except Exception as e:
            print(f"[focuslens] Failed to start: {e}")
            print(f"[focuslens] Make sure FocusLens app is open and running")
            return False

    def stop(self) -> bool:
        """Manually stop FocusLens (used if session is cancelled early)."""
        try:
            requests.post(f"{FOCUSLENS_URL}/stop", timeout=5)
            return True
        except Exception:
            return False

    def get_status(self) -> dict:
        """Get current recording status."""
        try:
            r = requests.get(f"{FOCUSLENS_URL}/status", timeout=5)
            return r.json()
        except Exception:
            return {}

    def poll_summary(self, timeout: int = MAX_POLL_WAIT) -> dict | None:
        """
        Poll GET /summary until ready=true or timeout.
        FocusLens sets ready=true after:
          1. Last clip finishes TRIBE v2 analysis
          2. CSV is read and engagement scores are matched
          3. SessionSummary is computed
        """
        print(f"[focuslens] Waiting for session summary (up to {timeout}s)...")
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                r = requests.get(f"{FOCUSLENS_URL}/summary", timeout=5)
                data = r.json()
                if data.get("ready"):
                    print(f"[focuslens] Summary ready")
                    return data
            except Exception:
                pass
            time.sleep(POLL_INTERVAL)
        print(f"[focuslens] Timed out waiting for summary")
        return None


# ── Backend sender ────────────────────────────────────────────────────────────

def send_to_backend(
    backend_url: str,
    user_id: str,
    session_score: float,
    focus_scores: list[float],
    duration_minutes: float,
    extra: dict = {}
) -> bool:
    """
    POST session results to your game/app backend.

    Payload:
    {
        "user_id": "user_123",
        "session_score": 62.4,          ← avg_focus * 0.8 + duration_min * 0.2
        "focus_scores": [76.0, 0.0, 55.0, ...],  ← per-clip focus scores
        "duration_minutes": 34.5,
        "clip_count": 3,
        "timestamp": "2026-04-05T10:30:00"
    }
    """
    if not backend_url:
        print("[backend] No backend URL provided — skipping upload")
        return False

    payload = {
        "user_id":          user_id,
        "session_score":    round(session_score, 2),
        "focus_scores":     [round(s, 2) for s in focus_scores],
        "duration_minutes": round(duration_minutes, 2),
        "clip_count":       len(focus_scores),
        "timestamp":        datetime.utcnow().isoformat(),
        **extra
    }

    try:
        r = requests.post(
            f"{backend_url.rstrip('/')}/api/sessions",
            json=payload,
            timeout=15
        )
        r.raise_for_status()
        print(f"[backend] Session saved — HTTP {r.status_code}")
        print(f"[backend] Response: {r.json()}")
        return True
    except Exception as e:
        print(f"[backend] Failed to send: {e}")
        return False


# ── Session timer thread ──────────────────────────────────────────────────────

def run_lstm_for_duration(lstm: LSTMPipeline, duration: int,
                          user_id: str, content_type: str,
                          result: dict):
    """Run LSTM for exactly duration seconds, then stop and store CSV path."""
    started = lstm.start(duration=duration, user_id=user_id, content_type=content_type)
    if not started:
        result["lstm_ok"] = False
        return

    result["lstm_ok"] = True
    time.sleep(duration)

    csv_path = lstm.stop()
    result["csv_path"] = csv_path


# ── Main ──────────────────────────────────────────────────────────────────────

def run_session(
    duration: int,
    user_id: str,
    backend_url: str = "",
    content_type: str = "studying"
) -> dict:
    """
    Main entry point — called by frontend/backend.

    Args:
        duration:     session length in seconds
        user_id:      user identifier for backend
        backend_url:  your backend base URL (e.g. https://your-app.com)
        content_type: hint for LSTM model (studying / coding / reading)

    Returns:
        {
            "session_score": 62.4,
            "focus_scores": [76.0, 0.0, 55.0],
            "duration_minutes": 34.5,
            "clip_count": 3,
            "success": true
        }
    """
    print(f"\n{'='*55}")
    print(f"FocusLens Session — {duration}s ({duration//60}m {duration%60}s)")
    print(f"User: {user_id}  Content: {content_type}")
    print(f"{'='*55}\n")

    lstm        = LSTMPipeline()
    focuslens   = FocusLensPipeline()
    lstm_result = {}

    # ── start both pipelines simultaneously ───────────────────────────────────
    lstm_thread = threading.Thread(
        target=run_lstm_for_duration,
        args=(lstm, duration, user_id, content_type, lstm_result),
        daemon=True
    )
    lstm_thread.start()

    # small delay so LSTM webcam is initialized before screen recording starts
    time.sleep(2)

    fl_started = focuslens.start(duration=duration)
    if not fl_started:
        print("[session] FocusLens failed to start — aborting")
        lstm_thread.join(timeout=5)
        return {"success": False, "error": "FocusLens app not reachable"}

    print(f"\n[session] Both pipelines running for {duration}s...\n")

    # ── wait for LSTM thread to finish (it runs for exactly duration seconds) ─
    lstm_thread.join()
    print(f"[session] LSTM pipeline complete")

    # ── wait for FocusLens to finish analysis and produce summary ─────────────
    # FocusLens auto-stops after duration seconds (set by /start_timed)
    # We give it extra time to finish the last clip analysis
    extra_wait = min(120, duration // 10)  # 10% of session or 2 min max
    print(f"[session] Waiting {extra_wait}s for last clip analysis...")
    time.sleep(extra_wait)

    summary = focuslens.poll_summary(timeout=MAX_POLL_WAIT)

    if not summary:
        print("[session] Could not get session summary from FocusLens")
        return {"success": False, "error": "No summary from FocusLens"}

    # ── extract results ───────────────────────────────────────────────────────
    session_score    = summary.get("session_score", 0.0)
    duration_minutes = summary.get("duration_minutes", duration / 60)
    clip_count       = summary.get("clip_count", 0)

    # focus_scores is a list of per-clip scores
    # FocusLens /summary returns aggregate stats — for the full list
    # we read it from the clips field if available, or reconstruct from CSV
    focus_scores = summary.get("focus_scores", [])

    # if FocusLens didn't return per-clip list, use LSTM scores as proxy
    if not focus_scores and lstm_result.get("csv_path"):
        raw_scores   = lstm.read_scores(lstm_result["csv_path"])
        focus_scores = raw_scores  # engagement scores as fallback

    print(f"\n{'='*55}")
    print(f"Session Complete")
    print(f"  Session score:    {session_score}")
    print(f"  Duration:         {duration_minutes:.1f} min")
    print(f"  Clips analyzed:   {clip_count}")
    print(f"  Avg engagement:   {summary.get('avg_engagement', 'N/A')}")
    print(f"  Study time:       {summary.get('study_pct', 'N/A')}%")
    print(f"  Distractions:     {summary.get('distraction_count', 'N/A')}")
    print(f"  Focus scores:     {focus_scores}")
    print(f"{'='*55}\n")

    # ── send to backend ───────────────────────────────────────────────────────
    send_to_backend(
        backend_url     = backend_url,
        user_id         = user_id,
        session_score   = session_score,
        focus_scores    = focus_scores,
        duration_minutes = duration_minutes,
        extra           = {
            "avg_engagement":   summary.get("avg_engagement"),
            "study_pct":        summary.get("study_pct"),
            "distraction_count": summary.get("distraction_count"),
        }
    )

    return {
        "success":          True,
        "session_score":    session_score,
        "focus_scores":     focus_scores,
        "duration_minutes": duration_minutes,
        "clip_count":       clip_count,
        "avg_engagement":   summary.get("avg_engagement"),
        "study_pct":        summary.get("study_pct"),
        "distraction_count": summary.get("distraction_count"),
    }


# ── CLI entry point ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run a FocusLens study session")
    parser.add_argument("--duration",     type=int,   required=True,  help="Session duration in seconds")
    parser.add_argument("--user_id",      type=str,   default="user_dev", help="User ID for backend")
    parser.add_argument("--backend_url",  type=str,   default="",     help="Backend base URL")
    parser.add_argument("--content_type", type=str,   default="studying", help="Content type hint")
    args = parser.parse_args()

    result = run_session(
        duration     = args.duration,
        user_id      = args.user_id,
        backend_url  = args.backend_url,
        content_type = args.content_type,
    )

    # print JSON result for caller to parse
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("success") else 1)
