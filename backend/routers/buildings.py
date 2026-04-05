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
