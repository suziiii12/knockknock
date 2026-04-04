import logging
import os
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
from routers import challenges, sessions, checkin, buildings, users
from routers.sessions import scheduler as checkin_scheduler


_REQUIRED_ENV_VARS = [
    "SECRET_KEY",
    "ANTHROPIC_API_KEY",
    "DATABASE_URL",
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

    checkin_scheduler.start()
    logger.info("APScheduler started")
    yield
    checkin_scheduler.shutdown(wait=False)
    logger.info("APScheduler stopped")
    logger.info("Server shutting down")


app = FastAPI(
    title="FocusBet API",
    description="Backend for FocusBet — stake money on your focus sessions.",
    version="0.1.0",
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


app.include_router(challenges.router)
app.include_router(sessions.router)
app.include_router(checkin.router)
app.include_router(buildings.router)
app.include_router(users.router)


@app.get("/health")
def health():
    return success({"status": "ok"})


@app.post("/auth/verify-world-id")
async def verify_world_id(
    body: schemas.WorldIDProof,
    db: Session = Depends(get_db),
):
    """Verify a World ID proof and return a 24h JWT. One account per person."""
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

    # Persist latest JWT so the client can re-hydrate after restart
    user.jwt_token = token
    db.commit()
    db.refresh(user)

    return success(schemas.TokenResponse(access_token=token).model_dump())
