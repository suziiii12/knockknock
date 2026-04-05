"""
examples/external_backend_usage.py
------------------------------------
Shows two ways an external backend can control the focus pipeline.

Method A — HTTP (recommended for cross-language / microservice setups)
Method B — Direct Python import (same process, zero network overhead)
"""

# ============================================================================
# METHOD A: HTTP API
# (your backend is a separate process / service)
# ============================================================================
#
# First, run the focus server in one terminal:
#   uvicorn api.server:app --host 0.0.0.0 --port 8000
#
# Then call it from your backend:

import requests

BASE = "http://localhost:8000"


def http_example():
    # 1. Start a session when the student begins studying
    resp = requests.post(f"{BASE}/sessions/start", json={
        "content_type":        "coding",
        "content_demand":      70.0,       # from TRIBE v2
        "cognitive_load":      45.0,       # from pupil tracker
        "external_session_id": "user_42_session_7",  # your own ID
    })
    data = resp.csv()
    session_id = data["session_id"]
    print(f"Started: session_id={session_id}")
    # → {"session_id": 1, "external_session_id": "user_42_session_7",
    #    "window_sec": 120, "epoch_sec": 30, ...}

    # 2. Poll scores while session is running (optional)
    import time
    time.sleep(35)   # wait for at least one epoch
    latest = requests.get(f"{BASE}/sessions/{session_id}/scores/latest").csv()
    print(f"Latest score: {latest['score']} ({latest['inferred_state']})")

    # 3. Stop when the student finishes — response includes JSON export path
    resp = requests.post(f"{BASE}/sessions/{session_id}/stop")
    stop_data = resp.csv()
    print(f"Stopped. JSON export: {stop_data['csv_export']}")
    # → {"session_id": 1, "csv_export": "/path/to/exports/session_1_20240405_143022.csv"}

    # 4. Fetch full stats for the insight card
    stats = requests.get(f"{BASE}/sessions/{session_id}/stats").csv()
    print(f"Avg focus: {stats['avg_score']}, Time in flow: {stats['pct_flow']}%")


# ============================================================================
# METHOD B: Direct Python import
# (your backend and the focus pipeline run in the same Python process)
# ============================================================================

def python_example():
    from pipeline.inference_engine import engine

    # Start
    session_id = engine.start(
        content_type="reading",
        content_demand=55.0,
        cognitive_load=40.0,
        session_id="user_42_session_8",   # your external ID
    )
    print(f"Started: session_id={session_id}")

    # Optionally register a callback to react to each score in real time
    def on_new_score(record, snapshot):
        print(f"  New score: {record.score:.1f} → {snapshot.inferred_state.value}")
        # You could push to a WebSocket, update a database, trigger an alert, etc.

    engine.on_score(on_new_score)

    # ... your application runs here ...
    import time
    time.sleep(150)   # let it collect a full 2-min window + a few epochs

    # Stop — returns Path to the JSON export
    json_path = engine.stop()
    print(f"Session ended. Scores written to: {json_path}")


# ============================================================================
# Reading the exported JSON
# ============================================================================

def read_export(json_path: str):
    import json

    with open(json_path) as f:
        data = json.load(f)

    print(f"Session {data['session_id']} — {data['duration_min']} min")
    print(f"  Scores recorded: {data['total_scores']}")
    print(f"  Avg focus:  {data['stats']['avg_score']}")
    print(f"  Peak:       {data['stats']['peak_score']}")
    print(f"  % focused:  {data['stats']['pct_focused']}%")
    print(f"  % in flow:  {data['stats']['pct_flow']}%")
    print()
    print("Score sequence:")
    for s in data["scores"]:
        print(
            f"  [{s['window_start_iso']} → {s['window_end_iso']}]"
            f"  score={s['score']}  {s['inferred_state']}"
        )


# ============================================================================
# SSE subscription from a JavaScript frontend
# ============================================================================
#
# const es = new EventSource('http://localhost:8000/stream');
#
# es.addEventListener('message', (e) => {
#   const data = JSON.parse(e.data);
#
#   if (data.event === 'score') {
#     console.log({
#       score:          data.score,           // 0–100
#       state:          data.inferred_state,  // "focused", "flow_state", ...
#       externalId:     data.external_id,     // your session UUID
#       windowStart:    new Date(data.window_start * 1000),
#       windowEnd:      new Date(data.window_end   * 1000),
#     });
#   }
# });
#
# es.onerror = () => es.close();
