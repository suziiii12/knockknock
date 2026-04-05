import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/buildings", tags=["buildings"])


@router.get("")
def get_all_buildings(db: Session = Depends(get_db)):
    """All buildings with their current King (highest territory total_score)."""
    buildings = db.query(models.Building).all()

    # For each building, find the user with the highest territory total_score
    results = []
    for b in buildings:
        top = (
            db.query(models.Territory, models.User)
            .join(models.User, models.Territory.user_id == models.User.id)
            .filter(models.Territory.building_id == b.id)
            .order_by(models.Territory.total_score.desc())
            .first()
        )
        results.append({
            "id": b.id,
            "name": b.name,
            "king_user_id": top[1].id if top else None,
            "king_name": top[1].name if top else None,
            "king_score": int(top[0].total_score) if top else 0,
        })

    logger.info("GET /buildings — %d buildings", len(results))
    return success(results)


@router.get("/{building_id}/leaderboard")
def get_building_leaderboard(
    building_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not db.query(models.Building).filter(models.Building.id == building_id).first():
        raise HTTPException(status_code=404, detail="Building not found")

    rows = (
        db.query(
            models.Territory.user_id,
            func.sum(models.Territory.total_score).label("total_score"),
        )
        .filter(models.Territory.building_id == building_id)
        .group_by(models.Territory.user_id)
        .order_by(func.sum(models.Territory.total_score).desc())
        .all()
    )

    user_ids = [row.user_id for row in rows]
    users = {u.id: u for u in db.query(models.User).filter(models.User.id.in_(user_ids)).all()}

    leaderboard = [
        schemas.BuildingLeaderboardEntry(
            rank=idx + 1,
            user_id=row.user_id,
            user_name=users[row.user_id].name if row.user_id in users else None,
            total_score=row.total_score,
        ).model_dump()
        for idx, row in enumerate(rows)
    ]
    return success(leaderboard)
