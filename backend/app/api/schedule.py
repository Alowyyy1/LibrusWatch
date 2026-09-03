"""
Schedule and sync API routes.
"""
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Depends
from typing import Optional
from ..models import WeekScheduleResponse, TodayLessonResponse, SyncResponse, Lesson
from ..database import db
from ..librus.client import LibrusClient
from .auth import get_current_user_token
from ..config import settings


router = APIRouter(prefix="/schedule", tags=["schedule"])


def _fetch_and_cache_schedule(token: str, user: dict) -> WeekScheduleResponse:
    """Internal helper to fetch schedule from Librus and cache it."""
    client = LibrusClient(user["username"], user["password"], user.get("cookies"))
    sched = client.get_week_schedule()

    if not sched:
        raise HTTPException(status_code=502, detail="Nie udało się pobrać planu lekcji z serwera Librus")

    # Update cookies in DB
    db.update_user_cookies(token, client.get_cookies_dict())

    # Cache schedule
    db.save_schedule_cache(token, sched.week_start, sched.model_dump())
    return sched


@router.get("/week", response_model=WeekScheduleResponse)
def get_week_schedule(token: str = Depends(get_current_user_token)):
    """
    Returns current week schedule. Uses database cache if fresh (< 10 min),
    otherwise re-fetches from Librus automatically.
    """
    user = db.get_user_by_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Nieprawidłowy token")

    cached = db.get_schedule_cache(token)
    if cached:
        # Check cache age
        updated_at = datetime.fromisoformat(cached["updated_at"].replace("Z", ""))
        cache_age = (datetime.utcnow() - updated_at).total_seconds()
        if cache_age < settings.SCHEDULE_CACHE_TTL_SECONDS:
            data = cached["data"]
            data["server_time"] = datetime.now().isoformat()
            return WeekScheduleResponse(**data)

    # Re-fetch from Librus
    return _fetch_and_cache_schedule(token, user)


@router.post("/sync", response_model=WeekScheduleResponse)
def force_sync(token: str = Depends(get_current_user_token)):
    """
    Forces an immediate re-fetch from Librus, updating the cache.
    Triggered by the 'Sync' button on Apple Watch / iPhone.
    """
    user = db.get_user_by_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Nieprawidłowy token")

    return _fetch_and_cache_schedule(token, user)


@router.get("/today", response_model=TodayLessonResponse)
def get_today_lessons(token: str = Depends(get_current_user_token)):
    """
    Returns the current and next lesson for today.
    Lightweight endpoint specifically optimized for Apple Watch Complications.
    """
    week_sched = get_week_schedule(token)
    now = datetime.now()
    today_str = now.strftime("%Y-%m-%d")
    current_time_str = now.strftime("%H:%M")

    # Find today's schedule
    today_day = next((d for d in week_sched.days if d.date_str == today_str), None)
    if not today_day:
        # Fallback to current day of week (0=Mon, 4=Fri)
        weekday_idx = now.weekday()
        if weekday_idx < len(week_sched.days):
            today_day = week_sched.days[weekday_idx]

    if not today_day or not today_day.lessons:
        return TodayLessonResponse(
            server_time=now.isoformat(),
            current_lesson=None,
            next_lesson=None,
            remaining_lessons_count=0
        )

    current_lesson: Optional[Lesson] = None
    next_lesson: Optional[Lesson] = None
    remaining_count = 0

    for lesson in today_day.lessons:
        if lesson.time_start <= current_time_str <= lesson.time_end:
            current_lesson = lesson
        elif lesson.time_start > current_time_str:
            if next_lesson is None:
                next_lesson = lesson
            remaining_count += 1

    return TodayLessonResponse(
        server_time=now.isoformat(),
        current_lesson=current_lesson,
        next_lesson=next_lesson,
        remaining_lessons_count=remaining_count
    )
