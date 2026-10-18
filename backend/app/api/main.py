from fastapi import APIRouter

from app.api.routes import (
    calendars,
    events,
    invitations,
    items,
    login,
    private,
    users,
    utils,
)
from app.core.config import settings

api_router = APIRouter()
api_router.include_router(login.router)
api_router.include_router(users.router)
api_router.include_router(utils.router)
api_router.include_router(items.router)
api_router.include_router(calendars.router)
api_router.include_router(events.router)
api_router.include_router(invitations.router)


if settings.FASTAPI_ENV == "development":
    api_router.include_router(private.router)
