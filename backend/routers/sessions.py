import logging
import random
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy import func
from sqlalchemy.orm import Session
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.jobstores.base import JobLookupError

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(tags=["sessions"])

# In-memory WebSocket connections: challenge_id -> list of active websockets
_connections: dict[int, list[WebSocket]] = {}

# Shared scheduler instance — started/stopped by main.py lifespan
scheduler = AsyncIOScheduler()

# Pending check-in job IDs per session for cancellation on end
_session_jobs: dict[int, list[str]] = {}


async def _send_checkin_trigger(challenge_id: int, session_id: int) -> None:
    payload = {"type": "checkin_trigger", "session_id": session_id}
    if challenge_id in _connections:
        dead = []
        for ws in _connections[challenge_id]:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            _connections[challenge_id].remove(ws)
    logger.info("Check-in trigger sent: session=%d challenge=%d", session_id, challenge_id)


def _schedule_checkins(session_id: int, challenge_id: int, duration_minutes: int) -> None:
    """Schedule 2–3 check-in triggers spread across the middle 70% of the session."""
    num_triggers = random.randint(2, 3)
    duration_secs = duration_minutes * 60
    window_start = int(duration_secs * 0.15)   # earliest: 15% in
    window_end = int(duration_secs * 0.85)     # latest: 85% in
    window = window_end - window_start

    slice_size = max(window // num_triggers, 1)
    now = datetime.now(timezone.utc)
    job_ids: list[str] = []

    for i in range(num_triggers):
        slice_start = window_start + i * slice_size
        offset_secs = slice_start + random.randint(0, slice_size - 1)
        fire_at = now + timedelta(seconds=offset_secs)
        job_id = f"checkin_{session_id}_{i}"
        scheduler.add_job(
            _send_checkin_trigger,
            "date",
            run_date=fire_at,
            args=[challenge_id, session_id],
            id=job_id,
            misfire_grace_time=30,
        )
        logger.info(
            "Check-in scheduled: session=%d trigger=%d/%d at=%s",
            session_id, i + 1, num_triggers, fire_at.isoformat(),
        )
        job_ids.append(job_id)

    _session_jobs[session_id] = job_ids


@router.post("/sessions/start")
def start_session(
    body: schemas.SessionStart,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    challenge = db.query(models.Challenge).filter(models.Challenge.id == body.challenge_id).first()
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")
    if challenge.status == models.ChallengeStatus.ended:
        raise HTTPException(status_code=400, detail="Challenge has ended")

    participant = db.query(models.Participant).filter_by(
        challenge_id=body.challenge_id, user_id=current_user.id
    ).first()
    if not participant:
        raise HTTPException(status_code=403, detail="You have not joined this challenge")

    # Return existing active session if one exists (ended_at is None)
    existing = db.query(models.Session).filter_by(
        challenge_id=body.challenge_id, user_id=current_user.id
    ).filter(models.Session.ended_at.is_(None)).first()
    if existing:
        return success(schemas.SessionOut.model_validate(existing).model_dump(mode="json"))

    session = models.Session(challenge_id=body.challenge_id, user_id=current_user.id)
    db.add(session)
    db.commit()
    db.refresh(session)
    logger.info("Session started: id=%d user=%d challenge=%d", session.id, current_user.id, body.challenge_id)

    _schedule_checkins(session.id, body.challenge_id, challenge.duration_minutes)
    return success(schemas.SessionOut.model_validate(session).model_dump(mode="json"))


@router.post("/sessions/{session_id}/score")
async def record_score(
    session_id: int,
    body: schemas.SessionScoreUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    session = db.query(models.Session).filter(models.Session.id == session_id).first()
    if not session or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.ended_at is not None:
        raise HTTPException(status_code=400, detail="Session has already ended")

    composite = (
        body.gaze_score * 0.5
        + body.tab_score * 0.3
        + body.checkin_score * 0.2
    )
    score = models.Score(
        session_id=session_id,
        gaze_score=body.gaze_score,
        tab_score=body.tab_score,
        checkin_score=body.checkin_score,
        composite_score=composite,
    )
    db.add(score)
    db.commit()
    db.refresh(score)

    # Broadcast latest composite score to WebSocket subscribers
    challenge_id = session.challenge_id
    if challenge_id in _connections:
        payload = {
            "user_id": current_user.id,
            "gaze_score": body.gaze_score,
            "tab_score": body.tab_score,
            "checkin_score": body.checkin_score,
            "composite_score": composite,
        }
        dead = []
        for ws in _connections[challenge_id]:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            _connections[challenge_id].remove(ws)

    logger.info("Score recorded: session=%d composite=%.1f", session_id, composite)
    return success(schemas.ScoreOut.model_validate(score).model_dump(mode="json"))


@router.post("/sessions/end")
async def end_session(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    session = (
        db.query(models.Session)
        .filter_by(user_id=current_user.id)
        .filter(models.Session.ended_at.is_(None))
        .order_by(models.Session.started_at.desc())
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="No active session found")

    # Compute final_score as average of all recorded composite scores
    scores = db.query(models.Score).filter_by(session_id=session.id).all()
    final_score = (
        sum(s.composite_score for s in scores) / len(scores) if scores else 0.0
    )

    # Cancel any pending check-in triggers for this session
    for job_id in _session_jobs.pop(session.id, []):
        try:
            scheduler.remove_job(job_id)
            logger.info("Cancelled pending check-in job: %s", job_id)
        except JobLookupError:
            pass  # Already fired

    session.ended_at = datetime.now(timezone.utc)
    session.final_score = final_score

    # Mark winner if threshold met
    challenge = session.challenge
    participant = db.query(models.Participant).filter_by(
        challenge_id=session.challenge_id, user_id=current_user.id
    ).first()
    if participant:
        participant.is_winner = final_score >= challenge.threshold_score

    # Upsert territory points for the challenge's building
    building_id = challenge.building_id
    if building_id is not None:
        territory = db.query(models.Territory).filter_by(
            building_id=building_id, user_id=current_user.id
        ).first()
        if territory:
            territory.total_score += final_score
        else:
            territory = models.Territory(
                building_id=building_id,
                user_id=current_user.id,
                total_score=final_score,
            )
            db.add(territory)
        logger.info(
            "Territory updated: user=%d building=%d score=%.1f",
            current_user.id, building_id, final_score,
        )

    db.commit()
    db.refresh(session)
    logger.info("Session ended: id=%d final_score=%.1f", session.id, final_score)

    # Broadcast updated top-5 leaderboard for this building over the challenge WebSocket
    if building_id is not None and session.challenge_id in _connections:
        top5 = (
            db.query(
                models.Territory.user_id,
                func.sum(models.Territory.total_score).label("total_score"),
            )
            .filter(models.Territory.building_id == building_id)
            .group_by(models.Territory.user_id)
            .order_by(func.sum(models.Territory.total_score).desc())
            .limit(5)
            .all()
        )
        leaderboard = [
            {"rank": idx + 1, "user_id": row.user_id, "total_score": row.total_score}
            for idx, row in enumerate(top5)
        ]
        payload = {"type": "leaderboard_update", "leaderboard": leaderboard}
        dead = []
        for ws in _connections[session.challenge_id]:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            _connections[session.challenge_id].remove(ws)
        logger.info(
            "Leaderboard broadcast: challenge=%d building=%d entries=%d",
            session.challenge_id, building_id, len(leaderboard),
        )

    # Check if every participant now has an ended session → resolve the challenge
    challenge_id = session.challenge_id
    challenge = db.query(models.Challenge).filter(models.Challenge.id == challenge_id).first()
    if challenge and challenge.status != models.ChallengeStatus.ended:
        total_participants = (
            db.query(models.Participant).filter_by(challenge_id=challenge_id).count()
        )
        ended_sessions = (
            db.query(models.Session)
            .filter_by(challenge_id=challenge_id)
            .filter(models.Session.ended_at.isnot(None))
            .count()
        )

        if ended_sessions >= total_participants:
            all_participants = (
                db.query(models.Participant).filter_by(challenge_id=challenge_id).all()
            )
            winners = [p for p in all_participants if p.is_winner]

            if not winners:
                # No one hit the threshold — refund everyone their stake
                for p in all_participants:
                    p.payout_amount = p.bet_amount
                payout_per_winner = None
                logger.info("Challenge %d: no winners, refunding all participants", challenge_id)
            else:
                distributable = challenge.pot_total * 0.85
                payout_per_winner = distributable / len(winners)
                for p in winners:
                    p.payout_amount = payout_per_winner
                logger.info(
                    "Challenge %d: %d winner(s), pot=%.2f commission=%.2f payout_each=%.2f",
                    challenge_id, len(winners),
                    challenge.pot_total, challenge.pot_total * 0.15, payout_per_winner,
                )

            challenge.status = models.ChallengeStatus.ended
            db.commit()

            # Broadcast challenge resolution to all connected clients
            if challenge_id in _connections:
                payload = {
                    "type": "challenge_ended",
                    "winners": [p.user_id for p in winners],
                    "payout_per_winner": payout_per_winner,
                }
                dead = []
                for ws in _connections[challenge_id]:
                    try:
                        await ws.send_json(payload)
                    except Exception:
                        dead.append(ws)
                for ws in dead:
                    _connections[challenge_id].remove(ws)
                logger.info("Challenge ended broadcast sent: challenge=%d", challenge_id)

    return success(schemas.SessionOut.model_validate(session).model_dump(mode="json"))


@router.websocket("/ws/challenge/{challenge_id}")
async def websocket_challenge(websocket: WebSocket, challenge_id: int):
    await websocket.accept()
    _connections.setdefault(challenge_id, []).append(websocket)
    logger.info("WebSocket connected: challenge=%d", challenge_id)
    try:
        while True:
            await websocket.receive_text()  # keep alive
    except WebSocketDisconnect:
        if challenge_id in _connections:
            _connections[challenge_id].remove(websocket)
        logger.info("WebSocket disconnected: challenge=%d", challenge_id)
