"""
test_pipeline.py
-----------------
Runs the focus pipeline directly without any backend or HTTP server.

Usage:
    python test_pipeline.py              # runs for 3 minutes
    python test_pipeline.py --duration 60  # runs for 60 seconds
    python test_pipeline.py --epoch 10     # emit a score every 10 seconds
"""

import argparse
import time
from pathlib import Path

from pipeline.inference_engine import InferenceEngine


def main():
    parser = argparse.ArgumentParser(description="Test the focus pipeline directly.")
    parser.add_argument("--duration", type=int,   default=180, help="How long to run (seconds)")
    parser.add_argument("--epoch",    type=float, default=120,  help="Score interval (seconds)")
    args = parser.parse_args()

    # Override epoch interval before starting
    engine = InferenceEngine()
    engine.epoch_sec = args.epoch

    print("=" * 50)
    print("Focus Pipeline — standalone test")
    print(f"  Duration : {args.duration}s")
    print(f"  Epoch    : {args.epoch}s  (score emitted every {args.epoch}s)")
    print(f"  Window   : 120s rolling")
    print("=" * 50)

    # Optional: react to each score as it arrives
    def on_score(record, snapshot):
        print(f"  → score={record.score:.1f}  "
              f"state={snapshot.inferred_state.value}  "
              f"daisee={record.daisee_class}  "
              f"conf={record.confidence:.2f}")

    engine.on_score(on_score)

    session_id = engine.start(
        content_type="general"
    )
    print(f"Session {session_id} started. Collecting data…")
    print("(Press Ctrl+C to stop early)\n")

    try:
        time.sleep(args.duration)
    except KeyboardInterrupt:
        print("\nInterrupted.")

    csv_path = engine.stop()
    print("\n" + "=" * 50)
    if csv_path and Path(csv_path).exists():
        print(f"CSV written → {csv_path}")
        _preview_csv(csv_path)
    else:
        print("No scores recorded (session may have been too short).")
    print("=" * 50)


def _preview_csv(path):
    import csv
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    print(f"{len(rows)} score(s) recorded:\n")
    for r in rows:
        print(f"[score={r['score']}")


if __name__ == "__main__":
    main()
