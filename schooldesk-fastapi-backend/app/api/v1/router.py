from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import approvals, auth, compat, goals, health
from app.api.v1 import fees, attendance, timetable, guardians, notifications

router = APIRouter()
router.include_router(health.router)
router.include_router(auth.router)
router.include_router(goals.router)
router.include_router(approvals.router)
router.include_router(fees.router)
router.include_router(attendance.router)
router.include_router(timetable.router)
router.include_router(guardians.router)
router.include_router(notifications.router)
router.include_router(compat.router)
