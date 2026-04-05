"""
finetune_daisee.py
-------------------
Fine-tune EngagementLSTM on the real DAiSEE dataset.

DAiSEE dataset download:
  https://people.iith.ac.in/vineethnb/resources/daisee/index.html

Expected directory structure after download:
  DAiSEE/
    DataSet/
      Train/  (student folders → video clips)
      Test/
      Validation/
    Labels/
      TrainLabels.csv
      TestLabels.csv
      ValidationLabels.csv

Label CSV columns:
  ClipID, Boredom, Engagement, Confusion, Frustration
  (all 0–3 scale; we use Engagement column)

Usage:
  python finetune_daisee.py --data_dir /path/to/DAiSEE --epochs 30

This script:
  1. Extracts MediaPipe landmark features from each video clip
  2. Creates sliding windows of length 30
  3. Fine-tunes EngagementLSTM starting from synthetic pretrained weights
  4. Saves best checkpoint to weights/engagement_lstm_daisee.pt
"""

import os
import argparse
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd

# ── Argument parsing ───────────────────────────────────────────────────────────
parser = argparse.ArgumentParser()
parser.add_argument("--data_dir",  type=str, required=True, help="Path to DAiSEE root")
parser.add_argument("--epochs",    type=int, default=30)
parser.add_argument("--lr",        type=float, default=3e-4)
parser.add_argument("--batch",     type=int, default=32)
parser.add_argument("--window",    type=int, default=30, help="Frames per window")
parser.add_argument("--fps",       type=int, default=10, help="Sampling fps from video")
parser.add_argument("--device",    type=str, default="cpu")
parser.add_argument("--pretrained",type=str, default="weights/engagement_lstm.pt")
parser.add_argument("--out",       type=str, default="weights/engagement_lstm_daisee.pt")
args = parser.parse_args()


try:
    import torch
    import torch.nn as nn
    from torch.utils.data import Dataset, DataLoader
    import cv2
    import mediapipe as mp
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install: pip install torch torchvision opencv-python mediapipe")
    exit(1)

from knockknock.EngagementScoreAI.models.engagement_lstm import EngagementLSTM, load_model
from knockknock.EngagementScoreAI.pipeline.feature_extractor import FeatureExtractor, RawSignals

def select_device(device: str = "cpu") -> str:
    """Resolve the requested device and fall back to CPU when needed."""
    if device.lower() in ("cpu", "-1"):
        return "cpu"
    if device.lower().startswith("cuda") and torch.cuda.is_available():
        return device
    if device.lower() in ("cuda", "gpu") and torch.cuda.is_available():
        return "cuda"
    return "cpu"

# ── Feature extraction from video ────────────────────────────────────────────

def extract_features_from_video(video_path: str, fps: int = 10) -> np.ndarray:
    """
    Extract 11-dim feature vectors from a DAiSEE video clip.
    Returns array of shape (n_frames, 11).
    """
    mp_face = mp.solutions.face_mesh
    mp_holistic = mp.solutions.holistic

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return np.empty((0, 11), dtype=np.float32)

    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30
    sample_every = max(1, int(src_fps / fps))

    extractor = FeatureExtractor()
    features = []
    frame_idx = 0

    with (
        mp_face.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        ) as face_mesh,
        mp_holistic.Holistic(
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
            model_complexity=0,
        ) as holistic,
    ):
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % sample_every != 0:
                frame_idx += 1
                continue

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            face_res = face_mesh.process(rgb)
            hol_res  = holistic.process(rgb)

            face_lms = None
            if face_res.multi_face_landmarks:
                face_lms = face_res.multi_face_landmarks[0].landmark

            raw = RawSignals(
                face_landmarks=face_lms,
                pose_landmarks=hol_res.pose_landmarks,
                keys_this_second=0,
                mouse_positions=[],
                last_input_time=time.time(),
                current_time=time.time(),
            )
            vec = extractor.extract(raw)
            features.append(vec)
            frame_idx += 1

    cap.release()
    return np.stack(features, axis=0) if features else np.empty((0, 11), dtype=np.float32)


# ── Dataset ────────────────────────────────────────────────────────────────────

class DAiSEEDataset(Dataset):
    """
    Loads pre-extracted features (or extracts on-the-fly) for DAiSEE clips.
    Each item is a (window_size, 11) feature array + engagement label (0–3).
    """

    def __init__(
        self,
        data_dir: str,
        labels_csv: str,
        split: str = "Train",
        window_size: int = 30,
        fps: int = 10,
        cache_dir: str = ".feature_cache",
    ):
        self.data_dir = Path(data_dir)
        self.window_size = window_size
        self.fps = fps
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)

        df = pd.read_csv(labels_csv)
        # DAiSEE CSV: ClipID, Boredom, Engagement, Confusion, Frustration
        self.records = []
        for _, row in df.iterrows():
            clip_id  = str(row["ClipID"])
            label    = int(row["Engagement"])   # 0–3
            # Locate video file
            video_path = self._find_video(clip_id, split)
            if video_path:
                self.records.append((clip_id, str(video_path), label))

        print(f"[DAiSEEDataset] {split}: {len(self.records)} clips found")
        self._windows = []
        self._labels  = []
        self._preprocess()

    def _find_video(self, clip_id: str, split: str) -> Path | None:
        """DAiSEE uses nested student/session folders."""
        search_root = self.data_dir / "DataSet" / split
        for p in search_root.rglob(f"{clip_id}*"):
            if p.suffix.lower() in (".avi", ".mp4", ".mov"):
                return p
        return None

    def _preprocess(self):
        """Extract features for all clips, then slice into windows."""
        for clip_id, video_path, label in self.records:
            cache_path = self.cache_dir / f"{clip_id}.npy"
            if cache_path.exists():
                feats = np.load(cache_path)
            else:
                print(f"  Extracting: {clip_id}")
                feats = extract_features_from_video(video_path, self.fps)
                np.save(cache_path, feats)

            if len(feats) < self.window_size:
                continue

            # Slide window with 50% overlap
            step = max(1, self.window_size // 2)
            for start in range(0, len(feats) - self.window_size + 1, step):
                window = feats[start : start + self.window_size]
                self._windows.append(window.astype(np.float32))
                self._labels.append(label)

        print(f"  → {len(self._windows)} windows created")

    def __len__(self):
        return len(self._windows)

    def __getitem__(self, idx):
        import torch
        x = torch.tensor(self._windows[idx])   # (window_size, 11)
        y = torch.tensor(self._labels[idx], dtype=torch.long)
        return x, y


# ── Training ───────────────────────────────────────────────────────────────────

def train():
    print("=" * 60)
    print("DAiSEE Fine-tuning")
    print("=" * 60)

    data_dir = Path(args.data_dir)

    # Load datasets
    train_ds = DAiSEEDataset(
        data_dir=data_dir,
        labels_csv=data_dir / "Labels" / "TrainLabels.csv",
        split="Train",
        window_size=args.window,
        fps=args.fps,
    )
    val_ds = DAiSEEDataset(
        data_dir=data_dir,
        labels_csv=data_dir / "Labels" / "ValidationLabels.csv",
        split="Validation",
        window_size=args.window,
        fps=args.fps,
    )

    train_loader = DataLoader(train_ds, batch_size=args.batch, shuffle=True,  num_workers=2)
    val_loader   = DataLoader(val_ds,   batch_size=args.batch, shuffle=False, num_workers=2)

    device = select_device(args.device)
    print(f"Using device: {device}")

    # Load pretrained weights
    model_path = Path(args.pretrained)
    if model_path.exists():
        print(f"Loading pretrained weights: {model_path}")
        model = load_model(str(model_path), device)
    else:
        print("No pretrained weights found — training from scratch")
        model = EngagementLSTM(input_size=11, hidden_size=128, num_layers=2, num_classes=4)
        model.to(device)

    if device != "cpu":
        torch.backends.cudnn.benchmark = True

    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
    criterion = nn.CrossEntropyLoss()

    best_val_acc = 0.0

    for epoch in range(args.epochs):
        # Train
        model.train()
        t_loss, t_correct, t_total = 0, 0, 0
        for xb, yb in train_loader:
            xb, yb = xb.to(args.device), yb.to(args.device)
            optimizer.zero_grad()
            logits = model(xb)
            loss = criterion(logits, yb)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            t_loss    += loss.item()
            t_correct += (logits.argmax(1) == yb).sum().item()
            t_total   += len(yb)
        scheduler.step()

        # Validate
        model.eval()
        v_correct, v_total = 0, 0
        with torch.no_grad():
            for xb, yb in val_loader:
                xb, yb = xb.to(args.device), yb.to(args.device)
                logits = model(xb)
                v_correct += (logits.argmax(1) == yb).sum().item()
                v_total   += len(yb)

        train_acc = t_correct / t_total * 100
        val_acc   = v_correct / v_total * 100
        print(
            f"Epoch {epoch+1:3d}/{args.epochs} | "
            f"loss: {t_loss/len(train_loader):.4f} | "
            f"train acc: {train_acc:.1f}% | "
            f"val acc: {val_acc:.1f}%"
        )

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save({
                "model_state_dict": model.state_dict(),
                "model_config": {
                    "input_size": 11, "hidden_size": 128,
                    "num_layers": 2, "num_classes": 4,
                    "window_size": args.window, "fps": args.fps,
                },
                "val_acc": val_acc,
                "epoch": epoch + 1,
                "training": "daisee_finetuned",
            }, args.out)
            print(f"  ✓ Saved best model (val acc: {val_acc:.1f}%) → {args.out}")

    print(f"\nDone. Best val accuracy: {best_val_acc:.1f}%")
    print(f"Run the app with: streamlit run app.py")


if __name__ == "__main__":
    train()
