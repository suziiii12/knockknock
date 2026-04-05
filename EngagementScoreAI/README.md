# Focus Score Pipeline — Backend API

Real-time student engagement scoring.
FastAPI + SQLite + JSON export + MediaPipe + DAiSEE-LSTM.

## Quick start

```bash
bash setup_macos.sh
source venv/bin/activate
uvicorn api.server:app --host 0.0.0.0 --port 8000 --reload
```

API docs: **http://localhost:8000/docs**

---

## External backend control

Sessions are started and stopped by your backend, not the focus server itself.

### HTTP (cross-language / microservice)

```bash
# Start a session
curl -X POST http://localhost:8000/sessions/start \
  -H "Content-Type: application/json" \
  -d '{
    "content_type": "coding",
    "content_demand": 70,
    "external_session_id": "user_42_session_7"
  }'
# → {"session_id": 1, "window_sec": 120, "epoch_sec": 30, ...}

# Stop — triggers JSON export
curl -X POST http://localhost:8000/sessions/1/stop
# → {"session_id": 1, "csv_export": "/path/to/exports/session_1_20240405_143022.csv"}
```

### Direct Python import (same process)

```python
from pipeline.inference_engine import engine

session_id = engine.start(
    content_type="coding",
    session_id="user_42_session_7",   # your external ID
)

# ... your app runs here ...

json_path = engine.stop()   # returns Path to JSON export
```

---

## JSON export

On every `stop()`, the engine writes:

```
exports/session_{id}_{YYYYMMDD_HHMMSS}.csv
```

```json
{
  "session_id": 1,
  "external_session_id": "user_42_session_7",
  "content_type": "coding",
  "started_at": 1712345600.0,
  "ended_at":   1712349200.0,
  "duration_min": 60.0,
  "window_sec": 120,
  "epoch_sec":  30,
  "total_scores": 118,
  "stats": {
    "avg_score": 73.4,
    "peak_score": 91.0,
    "pct_focused": 68.0,
    "pct_flow": 22.0,
    "pct_distracted": 12.0
  },
  "scores": [
    {
      "index": 0,
      "window_start": 1712345720.0,
      "window_end":   1712345840.0,
      "window_start_iso": "2024-04-05T14:15:20",
      "window_end_iso":   "2024-04-05T14:17:20",
      "score": 73.4,
      "daisee_class": "high",
      "inferred_state": "focused",
      "body_engagement": 71.2,
      "confidence": 0.84,
      "mean_gaze": 0.81,
      "mean_head_yaw": 4.2,
      "mean_ear": 0.27,
      "mean_kpm": 48.3,
      "mean_posture": 0.72
    },
    ...
  ]
}
```

You can also re-export any past session:
```bash
curl http://localhost:8000/sessions/1/export
```

---

## API reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/sessions/start` | Start pipeline + open session |
| `POST` | `/sessions/{id}/stop` | Stop pipeline + export JSON |
| `GET`  | `/sessions` | List all sessions |
| `GET`  | `/sessions/{id}` | Session metadata |
| `GET`  | `/sessions/{id}/scores` | Score sequence (`?since=<unix_ts>`) |
| `GET`  | `/sessions/{id}/scores/latest` | Most recent score |
| `GET`  | `/sessions/{id}/stats` | Aggregated stats |
| `GET`  | `/sessions/{id}/export` | Re-export to JSON |
| `GET`  | `/status` | Engine status + buffer fill |
| `GET`  | `/stream` | SSE real-time score push |

---

## File structure

```
focus_pipeline/
├── api/server.py               FastAPI app
├── db/store.py                 SQLite schema + queries
├── exports/                    JSON files written on session stop
├── pipeline/
│   ├── inference_engine.py     Orchestrator + start/stop API
│   ├── session_export.py       JSON writer
│   ├── webcam_capture.py       Camera thread
│   ├── feature_extractor.py    11-dim features
│   ├── study_context.py        InferredState fusion
│   └── behavioral_listener.py  Keyboard/mouse
├── models/engagement_lstm.py   Bidirectional LSTM
├── examples/
│   └── external_backend_usage.py
├── setup_macos.sh
└── requirements.txt
```
