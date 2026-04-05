from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.pool import NullPool
import os
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env", override=False)

def _resolve_database_url() -> str:
    raw_url = os.getenv("DATABASE_URL", "").strip()
    if not raw_url:
        sqlite_path = Path(__file__).resolve().parent / "focusbet.db"
        return f"sqlite:///{sqlite_path}"

    parsed_url = make_url(raw_url)
    if parsed_url.drivername in {"postgres", "postgresql"} or parsed_url.drivername.startswith("postgresql+"):
        return str(parsed_url.set(drivername="postgresql+psycopg"))
    return raw_url


DATABASE_URL = _resolve_database_url()
IS_SQLITE = DATABASE_URL.startswith("sqlite")

engine_kwargs = {"future": True, "pool_pre_ping": not IS_SQLITE}
if IS_SQLITE:
    engine_kwargs["connect_args"] = {"check_same_thread": False}
    engine_kwargs["poolclass"] = NullPool
else:
    engine_kwargs["pool_recycle"] = 300

engine = create_engine(DATABASE_URL, **engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
