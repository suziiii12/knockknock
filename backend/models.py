from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum

from database import Base


class ChallengeStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    ended = "ended"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    world_id_nullifier_hash = Column(String, unique=True, index=True, nullable=False)
    jwt_token = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    participants = relationship("Participant", back_populates="user")
    sessions = relationship("Session", back_populates="user")
    territory = relationship("Territory", back_populates="user")


class Building(Base):
    __tablename__ = "buildings"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    location = Column(String, nullable=False)

    challenges = relationship("Challenge", back_populates="building")
    territory = relationship("Territory", back_populates="building")


class Challenge(Base):
    __tablename__ = "challenges"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    duration_minutes = Column(Integer, nullable=False)
    buy_in_amount = Column(Float, nullable=False)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=True)
    status = Column(Enum(ChallengeStatus), default=ChallengeStatus.pending, nullable=False)
    threshold_score = Column(Float, default=70.0, nullable=False)
    pot_total = Column(Float, default=0.0, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    building = relationship("Building", back_populates="challenges")
    participants = relationship("Participant", back_populates="challenge")
    sessions = relationship("Session", back_populates="challenge")


class Participant(Base):
    __tablename__ = "participants"

    id = Column(Integer, primary_key=True, index=True)
    challenge_id = Column(Integer, ForeignKey("challenges.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    bet_amount = Column(Float, nullable=False)
    is_winner = Column(Boolean, nullable=True)
    payout_amount = Column(Float, nullable=True)

    challenge = relationship("Challenge", back_populates="participants")
    user = relationship("User", back_populates="participants")


class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    challenge_id = Column(Integer, ForeignKey("challenges.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    started_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    ended_at = Column(DateTime, nullable=True)
    final_score = Column(Float, nullable=True)

    challenge = relationship("Challenge", back_populates="sessions")
    user = relationship("User", back_populates="sessions")
    scores = relationship("Score", back_populates="session")


class Score(Base):
    __tablename__ = "scores"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    gaze_score = Column(Float, nullable=False)
    tab_score = Column(Float, nullable=False)
    checkin_score = Column(Float, nullable=False)
    composite_score = Column(Float, nullable=False)
    recorded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    session = relationship("Session", back_populates="scores")


class Territory(Base):
    __tablename__ = "territory"

    id = Column(Integer, primary_key=True, index=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    total_score = Column(Float, default=0.0, nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    building = relationship("Building", back_populates="territory")
    user = relationship("User", back_populates="territory")
