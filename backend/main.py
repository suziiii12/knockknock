import logging
import os
import secrets
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

from database import engine, get_db
import models
import schemas
from auth import verify_world_id_proof, create_access_token
from responses import success
from routers import sessions, checkin, buildings, users, admin


_REQUIRED_ENV_VARS = [
    "SECRET_KEY",
    "ANTHROPIC_API_KEY",
    "WORLD_ID_APP_ID",
    "WORLD_ID_RP_ID",
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    models.Base.metadata.create_all(bind=engine)
    logger.info("Database tables created")

    for var in _REQUIRED_ENV_VARS:
        if os.getenv(var):
            logger.info("Env OK: %s", var)
        else:
            logger.warning("Env MISSING: %s — using default or dev fallback", var)

    if os.getenv("DATABASE_URL"):
        logger.info("Env OK: DATABASE_URL")
    else:
        logger.info("Env MISSING: DATABASE_URL — using local SQLite fallback")

    yield
    logger.info("Server shutting down")


app = FastAPI(
    title="FocusBet API",
    description="Backend for FocusBet — AI-powered focus session tracker.",
    version="0.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code == 404:
        return JSONResponse({"success": False, "error": "Not found"}, status_code=404)
    return JSONResponse({"success": False, "error": str(exc.detail)}, status_code=exc.status_code)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        {"success": False, "error": "Validation error", "detail": exc.errors()},
        status_code=422,
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse({"success": False, "error": "Internal server error"}, status_code=500)


app.include_router(sessions.router)
app.include_router(checkin.router)
app.include_router(buildings.router)
app.include_router(users.router)
app.include_router(admin.router)


@app.get("/health")
def health():
    return success({"status": "ok"})


@app.get("/leaderboard/global")
def get_global_leaderboard(db: Session = Depends(get_db)):
    """Top 10 students by weekly score — no auth required."""
    from datetime import date
    from sqlalchemy import func

    today = date.today()
    month = today.year * 100 + today.month
    week = (today.day - 1) // 7 + 1

    rows = (
        db.query(models.WeeklyScore, models.User)
        .join(models.User, models.WeeklyScore.user_id == models.User.id)
        .filter(models.WeeklyScore.month == month, models.WeeklyScore.week == week)
        .order_by(models.WeeklyScore.weekly_score.desc())
        .limit(10)
        .all()
    )

    if not rows:
        return success([])

    # Per-building king = user with highest total_score in Territory
    max_sub = (
        db.query(
            models.Territory.building_id,
            func.max(models.Territory.total_score).label("max_score"),
        )
        .group_by(models.Territory.building_id)
        .subquery()
    )
    king_rows = (
        db.query(models.Territory.user_id, func.count().label("king_count"))
        .join(
            max_sub,
            (models.Territory.building_id == max_sub.c.building_id)
            & (models.Territory.total_score == max_sub.c.max_score),
        )
        .group_by(models.Territory.user_id)
        .all()
    )
    king_counts = {r.user_id: r.king_count for r in king_rows}

    result = []
    for rank, (ws, user) in enumerate(rows, start=1):
        result.append({
            "rank": rank,
            "user_id": user.id,
            "name": user.name or f"User {user.id}",
            "score": int(ws.weekly_score or 0),
            "king_count": king_counts.get(user.id, 0),
        })

    logger.info("GET /leaderboard/global — %d entries", len(result))
    return success(result)


# ============ DEV/TEST ENDPOINTS — remove before production ============

@app.post("/dev/create-test-user")
def create_test_user(db: Session = Depends(get_db)):
    """Create a test user and return a JWT token — DEV ONLY."""
    test_hash = "dev_test_user_nullifier_hash"
    user = db.query(models.User).filter_by(world_id_nullifier_hash=test_hash).first()
    if not user:
        user = models.User(
            world_id_nullifier_hash=test_hash,
            name="Test User",
            school="Purdue University",
            major="Computer Science",
            year="Junior",
            gender="Prefer not to say",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user.id)
    user.jwt_token = token
    db.commit()
    logger.info("Dev test user: id=%d token issued", user.id)
    return {"token": token, "user_id": user.id}


@app.get("/dev/sessions")
def dev_get_all_sessions(db: Session = Depends(get_db)):
    """List all sessions (no auth) — DEV ONLY."""
    rows = (
        db.query(models.Session)
        .order_by(models.Session.started_at.desc())
        .limit(50)
        .all()
    )
    return [
        {
            "id":          s.id,
            "user_id":     s.user_id,
            "building_id": s.building_id,
            "duration":    s.duration,
            "final_score": s.final_score,
            "started_at":  s.started_at.isoformat() if s.started_at else None,
            "ended_at":    s.ended_at.isoformat()   if s.ended_at   else None,
        }
        for s in rows
    ]


@app.get("/auth/create-session")
async def create_session():
    """Return rpContext data for IDKit v2 World ID flow.

    In dev mode (WORLD_ID_APP_ID unset / 'dev'), signature is empty and
    the frontend falls back to the test_ stub. In production, set
    WORLD_ID_PRIVATE_KEY (PEM, ECDSA P-256 from the Worldcoin Developer Portal)
    to produce a real signature.
    """
    app_id = os.getenv("WORLD_ID_APP_ID", "dev")
    rp_id  = os.getenv("WORLD_ID_RP_ID", "focusbet")
    nonce      = secrets.token_hex(16)
    created_at = int(time.time())
    expires_at = created_at + 600  # 10 minutes

    private_key_pem = os.getenv("WORLD_ID_PRIVATE_KEY", "")
    signature = ""
    if private_key_pem:
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec
            import base64
            message = f"{nonce}:{created_at}:{expires_at}".encode()
            key = serialization.load_pem_private_key(private_key_pem.encode(), password=None)
            sig = key.sign(message, ec.ECDSA(hashes.SHA256()))
            signature = base64.b64encode(sig).decode()
        except Exception as exc:
            logger.warning("rpContext signing failed: %s", exc)

    return success({
        "app_id":     app_id,
        "rp_id":      rp_id,
        "nonce":      nonce,
        "created_at": created_at,
        "expires_at": expires_at,
        "signature":  signature,
    })


@app.post("/auth/verify-world-id")
async def verify_world_id(
    body: schemas.WorldIDProof,
    db: Session = Depends(get_db),
):
    nullifier_hash = await verify_world_id_proof(body.model_dump())
    if not nullifier_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="World ID verification failed",
        )

    user = db.query(models.User).filter(
        models.User.world_id_nullifier_hash == nullifier_hash
    ).first()

    if not user:
        user = models.User(world_id_nullifier_hash=nullifier_hash)
        db.add(user)
        db.flush()
        logger.info("New user registered: id=%d", user.id)

    token = create_access_token(user.id)
    user.jwt_token = token
    db.commit()
    db.refresh(user)

    return success(schemas.TokenResponse(access_token=token).model_dump())
