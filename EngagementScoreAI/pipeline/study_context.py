"""
pipeline/study_context.py
--------------------------
Implements the StudyContext and InferredState nodes from the architecture diagram.

StudyContext fuses:
  - body_engagement_score   (from EngagementLSTM)
  - content_demand_score    (from TRIBE v2 — placeholder, configurable)
  - cognitive_load_score    (from Pupil tracker — placeholder, configurable)
  - time_of_day             (derived from system clock)
  - session_length_min      (measured internally)
  - content_type            (set externally by user/app)

InferredState maps the fused context to one of:
  flow_state | focused | surface_browsing | invisible_distraction |
  cognitive_overload | fatigue | disengaged
"""

import time
import math
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List
from collections import deque


class InferredState(Enum):
    FLOW_STATE             = "flow_state"
    FOCUSED                = "focused"
    SURFACE_BROWSING       = "surface_browsing"
    INVISIBLE_DISTRACTION  = "invisible_distraction"
    COGNITIVE_OVERLOAD     = "cognitive_overload"
    FATIGUE                = "fatigue"
    DISENGAGED             = "disengaged"
    WARMING_UP             = "warming_up"   # first 30s of session


STATE_DESCRIPTIONS = {
    InferredState.FLOW_STATE:            "Deep focus — student is in the zone",
    InferredState.FOCUSED:               "On task — solid engagement",
    InferredState.SURFACE_BROWSING:      "Browsing but not deeply engaged",
    InferredState.INVISIBLE_DISTRACTION: "Looks present but mentally elsewhere",
    InferredState.COGNITIVE_OVERLOAD:    "High demand, engagement dropping — consider a break",
    InferredState.FATIGUE:               "Signs of fatigue — blink rate up, posture dropping",
    InferredState.DISENGAGED:            "Off task — significant distraction detected",
    InferredState.WARMING_UP:            "Session warming up…",
}

STATE_COLORS = {
    InferredState.FLOW_STATE:            "#3B6D11",
    InferredState.FOCUSED:               "#1D9E75",
    InferredState.SURFACE_BROWSING:      "#BA7517",
    InferredState.INVISIBLE_DISTRACTION: "#854F0B",
    InferredState.COGNITIVE_OVERLOAD:    "#993C1D",
    InferredState.FATIGUE:               "#534AB7",
    InferredState.DISENGAGED:            "#A32D2D",
    InferredState.WARMING_UP:            "#888780",
}


@dataclass
class StudyContextSnapshot:
    """One moment in time — the full fused context vector."""
    timestamp: float
    body_engagement: float        # 0–100, from LSTM
    content_demand: float         # 0–100, from TRIBE v2 (default 50)
    cognitive_load: float         # 0–100, from pupil tracker (default 50)
    focus_score: float            # 0–100, final weighted output
    inferred_state: InferredState
    time_of_day_h: float          # 0–24
    session_length_min: float
    content_type: str
    daisee_class: str             # very_low / low / high / very_high
    confidence: float             # LSTM confidence 0–1


class StudyContext:
    """
    Stateful context manager. Call `update()` each epoch (every 5s).
    """

    DAISEE_CLASS_NAMES = ["very_low", "low", "high", "very_high"]

    # Focus score weights (from diagram: LSTM = body_engagement = primary)
    W_BODY  = 0.60
    W_DEMAND_ADJUST = 0.20   # content demand modulates the score
    W_LOAD  = 0.20

    def __init__(self, content_type: str = "general"):
        self.content_type = content_type
        self._session_start = time.time()
        self._session_end = None
        self._history: List[StudyContextSnapshot] = []
        self._score_buf = deque(maxlen=12)   # ~1-min rolling average

        # External scores (set from other pipeline components)
        self.content_demand_score: float = 50.0   # TRIBE v2 placeholder
        self.cognitive_load_score: float = 50.0   # Pupil tracker placeholder

        # Fatigue tracking
        self._blink_rate_buf = deque(maxlen=10)
        self._posture_buf = deque(maxlen=10)

    def update(
        self,
        body_engagement: float,
        daisee_class: int,
        confidence: float,
        blink_rate: float = 0.0,
        posture_score: float = 0.5,
    ) -> StudyContextSnapshot:
        """
        Fuse inputs and produce a StudyContextSnapshot.

        Parameters
        ----------
        body_engagement : float
            0–100 score from EngagementLSTM
        daisee_class : int
            0–3 class prediction from LSTM
        confidence : float
            Softmax confidence 0–1
        blink_rate : float
            Blinks per minute (optional, for fatigue detection)
        posture_score : float
            0–1 from feature extractor (optional)
        """
        self._blink_rate_buf.append(blink_rate)
        self._posture_buf.append(posture_score)

        now = time.time()
        session_min = (now - self._session_start) / 60.0
        tod = time.localtime(now).tm_hour + time.localtime(now).tm_min / 60.0

        # Fuse focus score
        # Content demand adjustment: high demand + low engagement → penalise more
        demand_factor = self.content_demand_score / 100.0
        load_factor = 1.0 - (self.cognitive_load_score / 100.0) * 0.3

        focus_score = (
            body_engagement * self.W_BODY
            + (100.0 - abs(body_engagement - self.content_demand_score) * 0.5) * self.W_DEMAND_ADJUST
            + body_engagement * load_factor * self.W_LOAD
        )
        focus_score = float(min(100.0, max(0.0, focus_score)))

        self._score_buf.append(focus_score)

        state = self._infer_state(
            body_engagement=body_engagement,
            focus_score=focus_score,
            session_min=session_min,
            blink_rate=float(self._mean(self._blink_rate_buf)),
            posture=float(self._mean(self._posture_buf)),
        )

        snap = StudyContextSnapshot(
            timestamp=now,
            body_engagement=round(body_engagement, 1),
            content_demand=round(self.content_demand_score, 1),
            cognitive_load=round(self.cognitive_load_score, 1),
            focus_score=round(focus_score, 1),
            inferred_state=state,
            time_of_day_h=round(tod, 2),
            session_length_min=round(session_min, 1),
            content_type=self.content_type,
            daisee_class=self.DAISEE_CLASS_NAMES[daisee_class],
            confidence=round(confidence, 3),
        )
        self._history.append(snap)
        return snap

    def rolling_average(self, window: int = 12) -> float:
        """Rolling average focus score over last N epochs."""
        buf = list(self._score_buf)[-window:]
        return round(sum(buf) / len(buf), 1) if buf else 0.0

    def session_summary(self) -> dict:
        """Post-session breakdown for the insight card."""
        if not self._history:
            return {}

        scores = [s.focus_score for s in self._history]
        states = [s.inferred_state for s in self._history]

        from collections import Counter
        state_counts = Counter(states)
        total = len(states)

        peak_idx = int(max(range(len(scores)), key=lambda i: scores[i]))
        trough_idx = int(min(range(len(scores)), key=lambda i: scores[i]))

        end_time = self._session_end or time.time()
        return {
            "duration_min":    round((end_time - self._session_start) / 60, 1),
            "avg_focus":       round(sum(scores) / len(scores), 1),
            "peak_score":      round(scores[peak_idx], 1),
            "trough_score":    round(scores[trough_idx], 1),
            "time_in_flow":    round(state_counts.get(InferredState.FLOW_STATE, 0) / total * 100, 1),
            "time_focused":    round((state_counts.get(InferredState.FOCUSED, 0) +
                                      state_counts.get(InferredState.FLOW_STATE, 0)) / total * 100, 1),
            "time_distracted": round((state_counts.get(InferredState.DISENGAGED, 0) +
                                      state_counts.get(InferredState.INVISIBLE_DISTRACTION, 0)) / total * 100, 1),
            "total_epochs":    total,
        }

    # ------------------------------------------------------------------ #
    #  InferredState logic
    # ------------------------------------------------------------------ #

    def _infer_state(
        self,
        body_engagement: float,
        focus_score: float,
        session_min: float,
        blink_rate: float,
        posture: float,
    ) -> InferredState:

        if session_min < 0.5:
            return InferredState.WARMING_UP

        # Fatigue: high blink rate + low posture
        if blink_rate > 25 and posture < 0.35:
            return InferredState.FATIGUE

        # Completely disengaged
        if body_engagement < 20:
            return InferredState.DISENGAGED

        # Cognitive overload: high demand but engagement dropping
        if (self.content_demand_score > 70 and body_engagement < 40):
            return InferredState.COGNITIVE_OVERLOAD

        # Invisible distraction: looks present (face detected) but engagement low
        # This is the "zoning out" scenario — gaze on screen but mind elsewhere
        if 20 <= body_engagement < 40:
            return InferredState.INVISIBLE_DISTRACTION

        # Surface browsing: moderate engagement, low content demand
        if 40 <= body_engagement < 60 and self.content_demand_score < 40:
            return InferredState.SURFACE_BROWSING

        # Focused
        if 60 <= body_engagement < 80:
            return InferredState.FOCUSED

        # Flow state: high engagement + reasonable content demand
        if body_engagement >= 80 and self.content_demand_score >= 40:
            return InferredState.FLOW_STATE

        return InferredState.FOCUSED

    @staticmethod
    def _mean(buf) -> float:
        return sum(buf) / len(buf) if buf else 0.0
