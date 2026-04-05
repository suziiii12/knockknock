"""
models/engagement_lstm.py
--------------------------
LSTM-based engagement classifier matching the DAiSEE benchmark architecture.

Input:  (batch, seq_len=30, features=11)  — 3 seconds at 10fps
Output: (batch, 4)  logits over DAiSEE engagement classes
        [very_low, low, high, very_high]

Architecture based on:
  "Engagement Prediction in Online Learning" (DAiSEE benchmark)
  + bidirectional extension for better temporal context
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class EngagementLSTM(nn.Module):
    """
    Bidirectional LSTM encoder with attention pooling for engagement classification.

    The architecture follows the best-performing single-modality model
    on the DAiSEE leaderboard (landmark-based, not raw pixel).
    """

    def __init__(
        self,
        input_size: int = 11,
        hidden_size: int = 128,
        num_layers: int = 2,
        num_classes: int = 4,
        dropout: float = 0.3,
        bidirectional: bool = True,
    ):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.directions = 2 if bidirectional else 1

        # Input normalisation
        self.input_norm = nn.LayerNorm(input_size)

        # LSTM encoder
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout if num_layers > 1 else 0.0,
            bidirectional=bidirectional,
        )

        lstm_out_size = hidden_size * self.directions  # 256 if bidirectional

        # Temporal attention — learns which frames matter most
        self.attention = nn.Sequential(
            nn.Linear(lstm_out_size, 64),
            nn.Tanh(),
            nn.Linear(64, 1),
        )

        # Classification head
        self.classifier = nn.Sequential(
            nn.Linear(lstm_out_size, 128),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(dropout * 0.5),
            nn.Linear(64, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x: (batch, seq_len, input_size)
        returns: (batch, num_classes) logits
        """
        x = self.input_norm(x)

        lstm_out, _ = self.lstm(x)           # (batch, seq, hidden*dirs)

        # Attention pooling
        attn_weights = self.attention(lstm_out)          # (batch, seq, 1)
        attn_weights = F.softmax(attn_weights, dim=1)    # normalise over time
        context = (attn_weights * lstm_out).sum(dim=1)   # (batch, hidden*dirs)

        logits = self.classifier(context)    # (batch, num_classes)
        return logits

    def predict_engagement(self, x: torch.Tensor):
        """
        Returns (class_idx, confidence, score_0_100, attention_weights).
        Convenience method for inference.
        """
        self.eval()
        with torch.no_grad():
            logits = self.forward(x)
            probs = F.softmax(logits, dim=-1)
            class_idx = probs.argmax(dim=-1).item()
            confidence = probs.max(dim=-1).values.item()

            # Weighted continuous score (0–100)
            score_weights = torch.tensor([12.5, 37.5, 62.5, 87.5])
            score = (probs * score_weights).sum(dim=-1).item()

            # Attention for visualisation
            x_norm = self.input_norm(x)
            lstm_out, _ = self.lstm(x_norm)
            attn_w = F.softmax(self.attention(lstm_out), dim=1)
            attn_np = attn_w.squeeze().cpu().numpy()

        return class_idx, confidence, score, attn_np


class EngagementLSTMWithRegression(EngagementLSTM):
    """
    Extended version that also outputs a continuous regression score
    alongside the 4-class classification. Useful if you fine-tune
    on DAiSEE with MSE loss on an additional engagement score column.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        lstm_out_size = self.hidden_size * self.directions
        self.regressor = nn.Sequential(
            nn.Linear(lstm_out_size, 32),
            nn.ReLU(),
            nn.Linear(32, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        x_norm = self.input_norm(x)
        lstm_out, _ = self.lstm(x_norm)
        attn_weights = F.softmax(self.attention(lstm_out), dim=1)
        context = (attn_weights * lstm_out).sum(dim=1)
        logits = self.classifier(context)
        score = self.regressor(context).squeeze(-1) * 100
        return logits, score


def load_model(weights_path: str, device: str = "cpu") -> EngagementLSTM:
    """Load model from checkpoint saved by download_weights.py."""

    ckpt = torch.load(weights_path, map_location=device)
    config = ckpt.get("model_config", {})

    model = EngagementLSTM(
        input_size=config.get("input_size", 11),
        hidden_size=config.get("hidden_size", 128),
        num_layers=config.get("num_layers", 2),
        num_classes=config.get("num_classes", 4),
    )
    model.load_state_dict(ckpt["model_state_dict"])
    model.to(device)
    model.eval()
    return model
