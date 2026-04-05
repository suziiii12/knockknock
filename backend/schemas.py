from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


# ── User profile ──────────────────────────────────────────────────────────────

class UserProfileUpdate(BaseModel):
    name:                Optional[str] = None
    school:              Optional[str] = None
    major:               Optional[str] = None
    year:                Optional[str] = None
    expected_graduation: Optional[str] = None
    gender:              Optional[str] = None


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


# ── Sessions ──────────────────────────────────────────────────────────────────

class SoloSessionStart(BaseModel):
    duration: float = Field(..., gt=0)          # minutes
    building_id: Optional[int] = None


class SessionOut(BaseModel):
    id: int
    user_id: int
    building_id: Optional[int]
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration: float
    final_score: Optional[float] = None

    model_config = {"from_attributes": True}


# ── Focus levels ──────────────────────────────────────────────────────────────

class FocusLevelIn(BaseModel):
    level: float = Field(..., ge=0.0, le=1.0)   # 0.0 ~ 1.0


class FocusLevelOut(BaseModel):
    id: int
    session_id: int
    timestamp: datetime
    level: float

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
    user_name: Optional[str]
    total_score: float

    model_config = {"from_attributes": True}
