import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import get_db
import models
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])

# Building ID → abbreviation for display
_BUILDING_ABBR: dict[int, str] = {
    1: "WALC",  2: "HIKS",  3: "HAAS",  7: "LWSN",  8: "KNOY",
    9: "PMU",  10: "HOVD", 11: "COREC", 12: "LILL", 13: "KRCH",
    14: "HEAV", 15: "STAN", 16: "REC",  17: "KRAN", 18: "STEW",
    19: "EE",  20: "ARMS",
}


def _week_start() -> datetime:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    return (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)


@router.get("/overview")
def admin_overview(db: Session = Depends(get_db)):
    """Platform KPIs for the current week."""
    ws = _week_start()

    total_sessions = db.query(func.count(models.Session.id)).filter(
        models.Session.started_at >= ws
    ).scalar() or 0

    active_users = db.query(
        func.count(func.distinct(models.Session.user_id))
    ).filter(models.Session.started_at >= ws).scalar() or 0

    avg_focus = db.query(func.avg(models.Session.final_score)).filter(
        models.Session.started_at >= ws,
        models.Session.final_score.isnot(None),
    ).scalar() or 0.0

    avg_duration = db.query(func.avg(models.Session.duration)).filter(
        models.Session.started_at >= ws
    ).scalar() or 0.0

    return success({
        "total_sessions":       total_sessions,
        "active_users":         active_users,
        "avg_focus_score":      round(float(avg_focus), 1),
        "avg_duration_minutes": round(float(avg_duration), 0),
    })


@router.get("/building-focus")
def admin_building_focus(db: Session = Depends(get_db)):
    """Avg focus score per building, highest first."""
    rows = (
        db.query(
            models.Session.building_id,
            func.avg(models.Session.final_score).label("avg_score"),
            func.count(models.Session.id).label("session_count"),
        )
        .filter(models.Session.final_score.isnot(None))
        .group_by(models.Session.building_id)
        .order_by(func.avg(models.Session.final_score).desc())
        .all()
    )
    return success([
        {
            "building_id":   str(r.building_id) if r.building_id else "unknown",
            "abbreviation":  _BUILDING_ABBR.get(r.building_id or 0, str(r.building_id or "?")),
            "avg_score":     round(float(r.avg_score), 1),
            "session_count": r.session_count,
        }
        for r in rows
    ])


@router.get("/hourly-focus")
def admin_hourly_focus(db: Session = Depends(get_db)):
    """Avg focus score by hour of day (UTC)."""
    rows = db.query(models.Session.started_at, models.Session.final_score).filter(
        models.Session.final_score.isnot(None),
        models.Session.started_at.isnot(None),
    ).all()

    buckets: dict[int, list[float]] = defaultdict(list)
    for started_at, final_score in rows:
        buckets[started_at.hour].append(float(final_score))

    return success([
        {
            "hour": hour,
            "avg_score": round(sum(scores) / len(scores), 1),
            "count": len(scores),
        }
        for hour, scores in sorted(buckets.items())
    ])


@router.get("/daily-usage")
def admin_daily_usage(db: Session = Depends(get_db)):
    """Session count by day of week (Mon → Sun order)."""
    rows = db.query(models.Session.started_at).filter(models.Session.started_at.isnot(None)).all()

    counts = {day: 0 for day in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]}
    _dow = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for (started_at,) in rows:
        counts[_dow[started_at.weekday()]] += 1

    return success([
        {"day": d, "count": counts.get(d, 0)}
        for d in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    ])


@router.get("/year-focus")
def admin_year_focus(db: Session = Depends(get_db)):
    """Avg focus score by student year, highest first."""
    rows = (
        db.query(
            models.User.year,
            func.avg(models.Session.final_score).label("avg_score"),
        )
        .join(models.Session, models.Session.user_id == models.User.id)
        .filter(models.Session.final_score.isnot(None))
        .group_by(models.User.year)
        .order_by(func.avg(models.Session.final_score).desc())
        .all()
    )
    return success([
        {"year": r.year or "Unknown", "avg_score": round(float(r.avg_score), 1)}
        for r in rows
    ])


@router.get("/college-focus")
def admin_college_focus(db: Session = Depends(get_db)):
    """Avg focus score by major, highest first."""
    rows = (
        db.query(
            models.User.major,
            func.avg(models.Session.final_score).label("avg_score"),
        )
        .join(models.Session, models.Session.user_id == models.User.id)
        .filter(models.Session.final_score.isnot(None))
        .group_by(models.User.major)
        .order_by(func.avg(models.Session.final_score).desc())
        .all()
    )
    return success([
        {"major": r.major or "Unknown", "avg_score": round(float(r.avg_score), 1)}
        for r in rows
    ])


@router.get("/semester-trend")
def admin_semester_trend(db: Session = Depends(get_db)):
    """Weekly avg focus score — week number within current year."""
    rows = db.query(models.Session.started_at, models.Session.final_score).filter(
        models.Session.final_score.isnot(None),
        models.Session.started_at.isnot(None),
    ).all()

    buckets: dict[int, list[float]] = defaultdict(list)
    for started_at, final_score in rows:
        buckets[int(started_at.strftime("%W"))].append(float(final_score))

    return success([
        {
            "week": week,
            "avg_score": round(sum(scores) / len(scores), 1),
        }
        for week, scores in sorted(buckets.items())
    ])
