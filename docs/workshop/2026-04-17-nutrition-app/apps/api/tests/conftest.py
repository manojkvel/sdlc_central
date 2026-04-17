from __future__ import annotations

import os
import subprocess
from collections.abc import Iterator

import pytest
from sqlalchemy import text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from nutrikids.db.session import make_engine, session_factory
from nutrikids.db.seed import seed


@pytest.fixture(scope="session")
def database_url() -> str:
    return os.getenv(
        "TEST_DATABASE_URL",
        "postgresql+psycopg2://nutrikids:nutrikids@localhost:5432/nutrikids_test",
    )


@pytest.fixture(scope="session")
def engine(database_url: str) -> Engine:
    os.environ["DATABASE_URL"] = database_url
    eng = make_engine(database_url)
    subprocess.run(
        ["alembic", "downgrade", "base"],
        check=False,
        env={**os.environ, "DATABASE_URL": database_url},
    )
    subprocess.run(
        ["alembic", "upgrade", "head"],
        check=True,
        env={**os.environ, "DATABASE_URL": database_url},
    )
    seed()
    return eng


@pytest.fixture
def db_session(engine: Engine) -> Iterator[Session]:
    Session_ = session_factory()
    sess = Session_()
    try:
        yield sess
    finally:
        sess.rollback()
        sess.close()


def set_app_context(session: Session, user_id: str, role: str, aggregate: bool = False) -> None:
    session.execute(text("SET LOCAL app.user_id = :u"), {"u": user_id})
    session.execute(text("SET LOCAL app.role = :r"), {"r": role})
    session.execute(
        text("SET LOCAL app.aggregate_query = :a"),
        {"a": "true" if aggregate else "false"},
    )
