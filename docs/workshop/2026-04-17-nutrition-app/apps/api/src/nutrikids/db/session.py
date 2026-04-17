from __future__ import annotations

import os
from collections.abc import Iterator

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from nutrikids.auth.context import current_context

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://nutrikids:nutrikids@localhost:5432/nutrikids",
)


def make_engine(url: str | None = None) -> Engine:
    return create_engine(url or DATABASE_URL, pool_pre_ping=True, future=True)


_engine: Engine | None = None
_SessionLocal: sessionmaker[Session] | None = None


def engine() -> Engine:
    global _engine
    if _engine is None:
        _engine = make_engine()
    return _engine


def _bind_rls_guc(session: Session, transaction) -> None:
    ctx = current_context()
    if ctx is None:
        return
    session.execute(text("SET LOCAL app.user_id = :uid"), {"uid": ctx.user_id})
    session.execute(text("SET LOCAL app.role = :role"), {"role": ctx.role})
    session.execute(
        text("SET LOCAL app.aggregate_query = :agg"),
        {"agg": "true" if ctx.aggregate_query else "false"},
    )


def session_factory() -> sessionmaker[Session]:
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(bind=engine(), expire_on_commit=False, future=True)
        event.listen(_SessionLocal, "after_begin", _bind_rls_guc)
    return _SessionLocal


def get_session() -> Iterator[Session]:
    with session_factory()() as sess:
        yield sess
