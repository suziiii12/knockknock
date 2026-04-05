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

    # World ID v4 verify API format for IDKit v3 (legacy) proofs
    action = proof_payload.get("action", "")
    verification_level = proof_payload.get("verification_level", "orb")
    # signal_hash: keccak256 of empty string (default when no signal)
    signal_hash = "0x00c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a4"

    v4_payload = {
        "protocol_version": "3.0",
        "action": action,
        "nonce": nullifier_hash,
        "responses": [
            {
                "identifier": verification_level,
                "nullifier": nullifier_hash,
                "merkle_root": proof_payload.get("merkle_root", ""),
                "proof": proof_payload.get("proof", ""),
                "signal_hash": signal_hash,
            }
        ],
    }

    # Try rp_id first, then app_id
    rp_id = os.getenv("WORLD_ID_RP_ID", "")
    verify_ids = [rp_id, WORLD_ID_APP_ID] if rp_id else [WORLD_ID_APP_ID]

    for verify_id in verify_ids:
        if not verify_id:
            continue
        url = f"{WORLD_ID_VERIFY_URL}/{verify_id}"
        try:
            logger.info("Verifying World ID proof at %s", url)
            import json as _json
            logger.info("Full v4 payload: %s", _json.dumps(v4_payload, indent=2)[:500])
            async with httpx.AsyncClient() as client:
                resp = await client.post(url, json=v4_payload, timeout=10)
            logger.info("World ID verify response: %s %s", resp.status_code, resp.text[:300])
            if resp.status_code == 200:
                data = resp.json()
                nullifier_hash = data.get("nullifier_hash", nullifier_hash)
                logger.info("World ID proof verified, nullifier=%s", nullifier_hash)
                return nullifier_hash
        except Exception as exc:
            logger.error("World ID verification error with %s: %s", verify_id, exc)

    logger.warning("World ID verification failed with all IDs")
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
