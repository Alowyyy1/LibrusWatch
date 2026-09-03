"""
Pydantic data models for Librus Synergia schedule, substitutions, and API.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class Lesson(BaseModel):
    id: str = Field(..., description="Unique lesson identifier, e.g. 'mon_1'")
    lesson_number: int = Field(..., description="Lesson index (1, 2, 3...)")
    subject: str = Field(..., description="Subject name, e.g. 'Historia'")
    original_subject: Optional[str] = Field(None, description="Original subject if replaced")
    time_start: str = Field(..., description="Start time 'HH:MM'")
    time_end: str = Field(..., description="End time 'HH:MM'")
    room: Optional[str] = Field(None, description="Classroom, e.g. 's. 204'")
    original_room: Optional[str] = Field(None, description="Original room if changed")
    teacher: Optional[str] = Field(None, description="Teacher name/initials")
    original_teacher: Optional[str] = Field(None, description="Original teacher if substituted")
    color: str = Field("#2563EB", description="Hex color code for UI card")
    
    # Substitution / Zastępstwo flags
    is_substitution: bool = Field(False, description="Whether this lesson has a substitution")
    is_cancelled: bool = Field(False, description="Whether this lesson is cancelled (okienko)")
    substitution_type: Optional[str] = Field(None, description="e.g. 'Zastępstwo', 'Odwołane', 'Przeniesione'")
    substitution_note: Optional[str] = Field(None, description="Details / note from administration")


class DaySchedule(BaseModel):
    day_name: str = Field(..., description="Full day name, e.g. 'Poniedziałek'")
    day_short: str = Field(..., description="Short code, e.g. 'Pon'")
    date_str: str = Field(..., description="Date 'YYYY-MM-DD'")
    lessons: List[Lesson] = Field(default_factory=list)


class WeekScheduleResponse(BaseModel):
    week_start: str = Field(..., description="Start date of the week 'YYYY-MM-DD'")
    week_end: str = Field(..., description="End date of the week 'YYYY-MM-DD'")
    server_time: str = Field(..., description="Current server time ISO format")
    last_synced: str = Field(..., description="Last successful Librus sync time")
    days: List[DaySchedule] = Field(default_factory=list)


class TodayLessonResponse(BaseModel):
    server_time: str
    current_lesson: Optional[Lesson] = None
    next_lesson: Optional[Lesson] = None
    remaining_lessons_count: int = 0


class LoginRequest(BaseModel):
    username: str = Field(..., description="Synergia login (e.g. 1234567u)")
    password: str = Field(..., description="Synergia password")


class LoginResponse(BaseModel):
    success: bool
    token: str = Field(..., description="API token for subsequent requests")
    student_name: Optional[str] = None
    message: str = "Login successful"


class SyncResponse(BaseModel):
    success: bool
    message: str
    synced_at: str
