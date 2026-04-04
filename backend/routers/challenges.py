import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/challenges", tags=["challenges"])


def _build_challenge_out(challenge: models.Challenge) -> schemas.ChallengeOut:
    return schemas.ChallengeOut(
        id=challenge.id,
        title=challenge.title,
        duration_minutes=challenge.duration_minutes,
        buy_in_amount=challenge.buy_in_amount,
        building_id=challenge.building_id,
        status=challenge.status,
        threshold_score=challenge.threshold_score,
        pot_total=challenge.pot_total,
        participant_count=len(challenge.participants),
        created_at=challenge.created_at,
    )


@router.post("", status_code=status.HTTP_201_CREATED)
def create_challenge(
    body: schemas.ChallengeCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if body.building_id:
        if not db.query(models.Building).filter(models.Building.id == body.building_id).first():
            raise HTTPException(status_code=404, detail="Building not found")

    challenge = models.Challenge(
        title=body.title,
        duration_minutes=body.duration_minutes,
        buy_in_amount=body.buy_in_amount,
        building_id=body.building_id,
        threshold_score=body.threshold_score,
        pot_total=body.buy_in_amount,  # creator's stake goes in immediately
    )
    db.add(challenge)
    db.flush()

    # Creator automatically joins
    participant = models.Participant(
        challenge_id=challenge.id,
        user_id=current_user.id,
        bet_amount=body.buy_in_amount,
    )
    db.add(participant)
    db.commit()
    db.refresh(challenge)
    logger.info("Challenge created: id=%d by user=%d pot=%.2f", challenge.id, current_user.id, challenge.pot_total)
    return success(_build_challenge_out(challenge).model_dump(mode="json"))


@router.get("")
def list_challenges(
    db: Session = Depends(get_db),
):
    """Return all active (pending + active) challenges. Public — no auth required."""
    challenges = (
        db.query(models.Challenge)
        .filter(models.Challenge.status != models.ChallengeStatus.ended)
        .order_by(models.Challenge.created_at.desc())
        .all()
    )
    return success([_build_challenge_out(c).model_dump(mode="json") for c in challenges])


@router.post("/{challenge_id}/join")
def join_challenge(
    challenge_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    challenge = db.query(models.Challenge).filter(models.Challenge.id == challenge_id).first()
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")
    if challenge.status == models.ChallengeStatus.ended:
        raise HTTPException(status_code=400, detail="Challenge has ended")

    already = db.query(models.Participant).filter_by(
        challenge_id=challenge_id, user_id=current_user.id
    ).first()
    if already:
        raise HTTPException(status_code=400, detail="You are already participating in this challenge")

    participant = models.Participant(
        challenge_id=challenge_id,
        user_id=current_user.id,
        bet_amount=challenge.buy_in_amount,
    )
    db.add(participant)

    # Add buy-in to pot
    challenge.pot_total += challenge.buy_in_amount

    # pending → active once at least 2 participants have joined
    if challenge.status == models.ChallengeStatus.pending and len(challenge.participants) >= 1:
        challenge.status = models.ChallengeStatus.active

    db.commit()
    db.refresh(challenge)
    logger.info("User %d joined challenge %d — pot now %.2f", current_user.id, challenge_id, challenge.pot_total)
    return success(_build_challenge_out(challenge).model_dump(mode="json"))
