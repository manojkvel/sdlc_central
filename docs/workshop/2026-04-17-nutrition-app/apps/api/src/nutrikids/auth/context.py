from __future__ import annotations

import contextvars
from dataclasses import dataclass
from typing import Literal

Role = Literal["student", "parent", "staff", "admin"]


@dataclass(frozen=True)
class RequestContext:
    user_id: str
    role: Role
    aggregate_query: bool = False


_context: contextvars.ContextVar[RequestContext | None] = contextvars.ContextVar(
    "nutrikids_request_context", default=None
)


def set_context(ctx: RequestContext) -> contextvars.Token:
    return _context.set(ctx)


def reset_context(token: contextvars.Token) -> None:
    _context.reset(token)


def current_context() -> RequestContext | None:
    return _context.get()
