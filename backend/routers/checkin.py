import os
import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import anthropic

from database import get_db
import models
import schemas
from auth import get_current_user
from responses import success

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/checkin", tags=["checkin"])

_anthropic_client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY", ""))


@router.post("/evaluate")
async def evaluate_checkin(
    body: schemas.CheckInEvaluate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    session = db.query(models.Session).filter(models.Session.id == body.session_id).first()
    if not session or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.ended_at is not None:
        raise HTTPException(status_code=400, detail="Session has already ended")

    system_prompt = (
        "You are evaluating whether a student is genuinely focused on studying. "
        "Given a prompt and the student's answer, decide if they pass the focus check. "
        "Respond in JSON with keys: passed (bool), feedback (string, ≤80 chars)."
    )
    user_message = f"Prompt: {body.prompt}\nAnswer: {body.answer}"

    try:
        message = _anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=150,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        import json
        raw = message.content[0].text.strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        result = json.loads(raw)
        passed = bool(result.get("passed", False))
        feedback = str(result.get("feedback", ""))
    except Exception as exc:
        logger.error("Claude check-in evaluation failed: %s", exc)
        passed = False
        feedback = "Check-in evaluation unavailable."

    logger.info("Check-in evaluated: session=%d passed=%s", body.session_id, passed)
    return success(schemas.CheckInResult(
        passed=passed,
        feedback=feedback,
        score_delta=20.0 if passed else -20.0,
    ).model_dump())
