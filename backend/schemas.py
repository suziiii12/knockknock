from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from models import ChallengeStatus


# ── Auth ──────────────────────────────────────────────────────────────────────

class WorldIDProof(BaseModel):
    nullifier_hash: str
    merkle_root: str
    proof: str
    verification_level: str
    action: Optional[str] = None
    signal: Optional[str] = None

    model_config = {"extra": "allow"}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ── Challenges ────────────────────────────────────────────────────────────────

class ChallengeCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    duration_minutes: int = Field(..., ge=1, le=180)
    buy_in_amount: float = Field(..., gt=0)
    building_id: Optional[int] = None
    threshold_score: float = Field(70.0, ge=0, le=100)


class ChallengeOut(BaseModel):
    id: int
    title: str
    duration_minutes: int
    buy_in_amount: float
    building_id: Optional[int]
    status: ChallengeStatus
    threshold_score: float
    pot_total: float
    participant_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Sessions ──────────────────────────────────────────────────────────────────

class SessionStart(BaseModel):
    challenge_id: int


class SessionScoreUpdate(BaseModel):
    gaze_score: float = Field(..., ge=0, le=100)
    tab_score: float = Field(..., ge=0, le=100)
    checkin_score: float = Field(100.0, ge=0, le=100)


class SessionOut(BaseModel):
    id: int
    challenge_id: int
    user_id: int
    started_at: datetime
    ended_at: Optional[datetime] = None
    final_score: Optional[float] = None

    model_config = {"from_attributes": True}


class ScoreOut(BaseModel):
    id: int
    session_id: int
    gaze_score: float
    tab_score: float
    checkin_score: float
    composite_score: float
    recorded_at: datetime

    model_config = {"from_attributes": True}


# ── Check-in ──────────────────────────────────────────────────────────────────

class CheckInEvaluate(BaseModel):
    session_id: int
    prompt: str
    answer: str


class CheckInResult(BaseModel):
    passed: bool
    feedback: str
    score_delta: float


# ── Buildings ─────────────────────────────────────────────────────────────────

class BuildingLeaderboardEntry(BaseModel):
    rank: int
    user_id: int
    total_score: float

    model_config = {"from_attributes": True}
