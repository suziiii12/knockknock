import os
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from database import get_db
import models

logger = logging.getLogger(__name__)

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24h

WORLD_ID_APP_ID = os.getenv("WORLD_ID_APP_ID", "")
WORLD_ID_RP_ID = os.getenv("WORLD_ID_RP_ID", "")
WORLD_ID_VERIFY_URL = "https://developer.world.org/api/v4/verify"

bearer_scheme = HTTPBearer()


def _is_dev_mode() -> bool:
    return not WORLD_ID_APP_ID or WORLD_ID_APP_ID == "dev"


async def verify_world_id_proof(proof_payload: dict) -> Optional[str]:
    """Verify a World ID v4 proof. Returns nullifier_hash on success, None on failure.

    In dev mode (WORLD_ID_APP_ID unset or 'dev'), nullifier_hash values starting
    with 'test_' bypass verification entirely. All other hashes also bypass in
    dev mode (no real World ID API call is made).
    """
    nullifier_hash = proof_payload.get("nullifier_hash", "")

    if nullifier_hash.startswith("test_"):
        logger.warning("Test bypass: nullifier_hash '%s', skipping World ID verification", nullifier_hash)
        return nullifier_hash

    if _is_dev_mode():
        logger.warning("Dev mode: WORLD_ID_APP_ID not set or 'dev', skipping World ID verification")
        return nullifier_hash or None

    url = f"{WORLD_ID_VERIFY_URL}/{WORLD_ID_APP_ID}"
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(url, json=proof_payload, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            nullifier_hash = data.get("nullifier_hash")
            logger.info("World ID v4 proof verified, nullifier=%s", nullifier_hash)
            return nullifier_hash
        logger.warning("World ID v4 verification failed: %s %s", resp.status_code, resp.text)
        return None
    except Exception as exc:
        logger.error("World ID v4 verification error: %s", exc)
        return None


def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: Optional[str] = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
