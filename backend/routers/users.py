import logging
from datetime import date
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["users"])


def _current_month_week() -> tuple[int, int]:
    """Return (YYYYMM, week_of_month 1-5) for today."""
    today = date.today()
    month = today.year * 100 + today.month
    week  = (today.day - 1) // 7 + 1
    return month, week


@router.get("/me")
def get_me(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    completed = (
        db.query(models.Session)
        .filter_by(user_id=current_user.id)
        .filter(models.Session.ended_at.isnot(None))
        .all()
    )
    session_count   = len(completed)
    scores_with_val = [s.final_score for s in completed if s.final_score is not None]
    avg_focus_score = round(sum(scores_with_val) / len(scores_with_val), 1) if scores_with_val else 0.0
    total_minutes   = round(sum(s.duration for s in completed if s.duration is not None), 1)

    # King buildings — highest territory score per building
    user_territory = db.query(models.Territory).filter_by(user_id=current_user.id).all()
    king_building_ids: list[int] = []
    for t in user_territory:
        top = (
            db.query(models.Territory)
            .filter_by(building_id=t.building_id)
            .order_by(models.Territory.total_score.desc())
            .first()
        )
        if top and top.user_id == current_user.id:
            king_building_ids.append(t.building_id)

    total_score = round(
        db.query(func.sum(models.Territory.total_score))
        .filter_by(user_id=current_user.id)
        .scalar() or 0.0, 1
    )

    # Current weekly score
    month, week = _current_month_week()
    weekly_row = db.query(models.WeeklyScore).filter_by(
        user_id=current_user.id, month=month, week=week
    ).first()
    weekly_score = round(weekly_row.weekly_score or 0.0, 1) if weekly_row else 0.0

    logger.info("GET /users/me user=%d sessions=%d", current_user.id, session_count)

    return success({
        "id":               current_user.id,
        "nullifier_hash":   current_user.world_id_nullifier_hash,
        "session_count":    session_count,
        "total_minutes":    total_minutes,
        "avg_focus_score":  avg_focus_score,
        "total_score":      total_score,
        "weekly_score":     weekly_score,
        "king_building_ids": king_building_ids,
        "created_at":       current_user.created_at.isoformat() if current_user.created_at else None,
    })


@router.patch("/me/profile")
def update_profile(
    body: schemas.UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Save profile fields collected on the ProfileSetupView."""
    if body.name                is not None: current_user.name                = body.name
    if body.school              is not None: current_user.school              = body.school
    if body.major               is not None: current_user.major               = body.major
    if body.year                is not None: current_user.year                = body.year
    if body.expected_graduation is not None: current_user.expected_graduation = body.expected_graduation
    if body.gender              is not None: current_user.gender              = body.gender

    db.commit()
    db.refresh(current_user)
    logger.info("Profile updated: user=%d name=%s", current_user.id, current_user.name)
    return success({
        "id":                  current_user.id,
        "name":                current_user.name,
        "school":              current_user.school,
        "major":               current_user.major,
        "year":                current_user.year,
        "expected_graduation": current_user.expected_graduation,
        "gender":              current_user.gender,
    })


@router.get("/me/weekly-score")
def get_weekly_score(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Return the current user's score for this week (YYYYMM + week 1-5)."""
    month, week = _current_month_week()
    row = db.query(models.WeeklyScore).filter_by(
        user_id=current_user.id, month=month, week=week
    ).first()

    return success({
        "month":        month,
        "week":         week,
        "weekly_score": round(row.weekly_score or 0.0, 1) if row else 0.0,
    })
