import logging
from datetime import datetime, timezone, date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(tags=["sessions"])


def _current_month_week() -> tuple[int, int]:
    today = date.today()
    return today.year * 100 + today.month, (today.day - 1) // 7 + 1


def _active_session(user_id: int, db: Session) -> models.Session | None:
    return (
        db.query(models.Session)
        .filter_by(user_id=user_id)
        .filter(models.Session.ended_at.is_(None))
        .order_by(models.Session.started_at.desc())
        .first()
    )


@router.get("/sessions/history")
def get_session_history(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    sessions = (
        db.query(models.Session)
        .filter_by(user_id=current_user.id)
        .filter(models.Session.ended_at.isnot(None))
        .order_by(models.Session.started_at.desc())
        .all()
    )
    logger.info("GET /sessions/history user=%d count=%d", current_user.id, len(sessions))
    return success([
        schemas.SessionOut.model_validate(s).model_dump(mode="json")
        for s in sessions
    ])


@router.post("/sessions/start")
def start_session(
    body: schemas.SoloSessionStart,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Return existing active session if one already exists
    existing = _active_session(current_user.id, db)
    if existing:
        return success(schemas.SessionOut.model_validate(existing).model_dump(mode="json"))

    if body.building_id is not None:
        if not db.query(models.Building).filter(models.Building.id == body.building_id).first():
            raise HTTPException(status_code=404, detail="Building not found")

    session = models.Session(
        user_id=current_user.id,
        building_id=body.building_id,
        duration=body.duration,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    logger.info("Session started: id=%d user=%d duration=%.1f", session.id, current_user.id, body.duration)
    return success(schemas.SessionOut.model_validate(session).model_dump(mode="json"))


@router.post("/sessions/{session_id}/focus-level")
def record_focus_level(
    session_id: int,
    body: schemas.FocusLevelIn,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    session = db.query(models.Session).filter(
        models.Session.id == session_id,
        models.Session.user_id == current_user.id,
        models.Session.ended_at.is_(None),
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Active session not found")

    entry = models.FocusLevel(session_id=session_id, level=body.level)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    logger.info("Focus level: session=%d level=%.2f", session_id, body.level)
    return success(schemas.FocusLevelOut.model_validate(entry).model_dump(mode="json"))


@router.post("/sessions/end")
def end_session(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    session = _active_session(current_user.id, db)
    if not session:
        raise HTTPException(status_code=404, detail="No active session found")

    # final_score = mean of focus_level.level * 100
    levels = db.query(models.FocusLevel).filter_by(session_id=session.id).all()
    final_score = round(
        (sum(l.level for l in levels) / len(levels)) * 100 if levels else 0.0, 2
    )

    session.ended_at   = datetime.now(timezone.utc)
    session.final_score = final_score

    # Upsert weekly_score — accumulate across sessions in the same week
    month, week = _current_month_week()
    weekly = db.query(models.WeeklyScore).filter_by(
        user_id=current_user.id, month=month, week=week
    ).first()
    if weekly:
        weekly.weekly_score = round((weekly.weekly_score or 0.0) + final_score, 2)
    else:
        weekly = models.WeeklyScore(
            user_id=current_user.id,
            month=month,
            week=week,
            weekly_score=final_score,
        )
        db.add(weekly)

    # Flush so weekly.id is available for building_score FK
    db.flush()

    # Upsert building_score — per-building breakdown within this week
    if session.building_id is not None:
        building_score_row = db.query(models.BuildingScore).filter_by(
            weekly_score_id=weekly.id, building_id=session.building_id
        ).first()
        if building_score_row:
            building_score_row.building_score = round(
                (building_score_row.building_score or 0.0) + final_score, 2
            )
        else:
            db.add(models.BuildingScore(
                weekly_score_id=weekly.id,
                building_id=session.building_id,
                building_score=final_score,
            ))

    # Upsert territory for the session's building
    if session.building_id is not None:
        territory = db.query(models.Territory).filter_by(
            building_id=session.building_id, user_id=current_user.id
        ).first()
        if territory:
            territory.total_score = round(territory.total_score + final_score, 2)
        else:
            db.add(models.Territory(
                building_id=session.building_id,
                user_id=current_user.id,
                total_score=final_score,
            ))
        logger.info("Territory updated: user=%d building=%d score=%.2f",
                    current_user.id, session.building_id, final_score)

    db.commit()
    db.refresh(session)
    logger.info("Session ended: id=%d final_score=%.2f", session.id, final_score)
    return success(schemas.SessionOut.model_validate(session).model_dump(mode="json"))
