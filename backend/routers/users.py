import logging
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
import models
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
def get_me(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Return the authenticated user's profile, session stats, and king buildings."""

    # ── Session stats (completed sessions only) ─────────────────────────────
    completed = (
        db.query(models.Session)
        .filter_by(user_id=current_user.id)
        .filter(models.Session.ended_at.isnot(None))
        .all()
    )
    session_count = len(completed)
    scores_with_value = [s.final_score for s in completed if s.final_score is not None]
    avg_focus_score = (
        round(sum(scores_with_value) / len(scores_with_value), 1)
        if scores_with_value else 0.0
    )
    total_minutes = sum(
        s.challenge.duration_minutes
        for s in completed
        if s.challenge is not None
    )

    # ── King buildings ───────────────────────────────────────────────────────
    # A user is "king" of a building when they hold the highest territory score.
    user_territory = (
        db.query(models.Territory)
        .filter_by(user_id=current_user.id)
        .all()
    )

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

    # ── Territory total score ────────────────────────────────────────────────
    total_score_row = (
        db.query(func.sum(models.Territory.total_score))
        .filter_by(user_id=current_user.id)
        .scalar()
    )
    total_score = round(total_score_row or 0.0, 1)

    logger.info(
        "GET /users/me user=%d sessions=%d king_buildings=%s",
        current_user.id, session_count, king_building_ids,
    )

    return success({
        "id": current_user.id,
        "nullifier_hash": current_user.world_id_nullifier_hash,
        "session_count": session_count,
        "total_minutes": total_minutes,
        "avg_focus_score": avg_focus_score,
        "total_score": total_score,
        "king_building_ids": king_building_ids,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
    })
