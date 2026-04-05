from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime, timezone

from database import Base


class User(Base):
    __tablename__ = "users"

    id                      = Column(Integer, primary_key=True, index=True)
    world_id_nullifier_hash = Column(String, unique=True, nullable=False, index=True)
    selfie_nullifier        = Column(String, nullable=True, index=True)
    jwt_token               = Column(String, nullable=True)
    created_at              = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Profile fields (set on first login via ProfileSetupView)
    name                = Column(String,  nullable=True)
    school              = Column(String,  nullable=True)
    major               = Column(String,  nullable=True)
    year                = Column(String,  nullable=True)   # Freshman / Sophomore / …
    expected_graduation = Column(String,  nullable=True)   # e.g. "Spring 2026"
    gender              = Column(String,  nullable=True)

    sessions      = relationship("Session",     back_populates="user")
    weekly_scores = relationship("WeeklyScore", back_populates="user")
    territory     = relationship("Territory",   back_populates="user")


class Building(Base):
    __tablename__ = "buildings"

    id        = Column(Integer, primary_key=True, index=True)
    name      = Column(String, unique=True, nullable=False)
    location  = Column(String, nullable=False)
    latitude  = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    building_scores = relationship("BuildingScore", back_populates="building")
    territory       = relationship("Territory",     back_populates="building")


class Session(Base):
    __tablename__ = "sessions"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id"),     nullable=False)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=True)
    started_at  = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    ended_at    = Column(DateTime, nullable=True)
    duration    = Column(Float, nullable=False)       # minutes
    final_score = Column(Float, nullable=True)

    user         = relationship("User",       back_populates="sessions")
    building     = relationship("Building",   foreign_keys=[building_id])
    focus_levels = relationship("FocusLevel", back_populates="session")


class FocusLevel(Base):
    __tablename__ = "focus_level"

    id         = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    timestamp  = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    level      = Column(Float, nullable=False)   # 0.0 ~ 1.0

    session = relationship("Session", back_populates="focus_levels")


class WeeklyScore(Base):
    __tablename__ = "weekly_score"

    id           = Column(Integer, primary_key=True, index=True)
    user_id      = Column(Integer, ForeignKey("users.id"), nullable=False)
    month        = Column(Integer, nullable=False)   # YYYYMM
    week         = Column(Integer, nullable=False)   # 1~5
    weekly_score = Column(Float, nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "month", "week", name="uq_weekly_score_user_month_week"),
    )

    user            = relationship("User",          back_populates="weekly_scores")
    building_scores = relationship("BuildingScore", back_populates="weekly_score")


class BuildingScore(Base):
    __tablename__ = "building_score"

    id              = Column(Integer, primary_key=True, index=True)
    weekly_score_id = Column(Integer, ForeignKey("weekly_score.id"), nullable=False)
    building_id     = Column(Integer, ForeignKey("buildings.id"),    nullable=False)
    building_score  = Column(Float, nullable=True)

    weekly_score = relationship("WeeklyScore", back_populates="building_scores")
    building     = relationship("Building",    back_populates="building_scores")


class Territory(Base):
    __tablename__ = "territory"

    id          = Column(Integer, primary_key=True, index=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    user_id     = Column(Integer, ForeignKey("users.id"),     nullable=False)
    total_score = Column(Float, nullable=False, default=0.0)
    updated_at  = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                         onupdate=lambda: datetime.now(timezone.utc))

    building = relationship("Building", back_populates="territory")
    user     = relationship("User",     back_populates="territory")
