"""
Unit tests for schedule & substitutions HTML parser.
"""
import os
import sys

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(CURRENT_DIR)
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.librus.parser import (
    parse_schedule_html,
    parse_substitutions_html,
    merge_schedule_with_substitutions,
    get_subject_color
)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MOCK_DIR = os.path.join(CURRENT_DIR, "mock_html")


def test_parse_schedule_html():
    with open(os.path.join(MOCK_DIR, "plan_lekcji.html"), "r", encoding="utf-8") as f:
        html = f.read()

    days = parse_schedule_html(html)
    assert len(days) == 5

    # Check Monday
    mon = days[0]
    assert mon.day_name == "Poniedziałek"
    assert mon.day_short == "Pon"
    assert mon.date_str == "2026-09-07"
    assert len(mon.lessons) == 5

    # Lesson 1: Historia, 08:00 - 08:45, s. 204
    l1 = mon.lessons[0]
    assert "Historia" in l1.subject
    assert l1.time_start == "08:00"
    assert l1.time_end == "08:45"
    assert l1.room == "s. 204"
    assert l1.color == "#1D3BB5"  # Deep blue as in screenshot

    # Lesson 2: Fizyka, 08:50 - 09:35
    l2 = mon.lessons[1]
    assert "Fizyka" in l2.subject
    assert l2.time_start == "08:50"
    assert l2.time_end == "09:35"
    assert l2.color == "#B52763"  # Magenta as in screenshot


def test_parse_and_merge_substitutions():
    with open(os.path.join(MOCK_DIR, "plan_lekcji.html"), "r", encoding="utf-8") as f:
        sched_html = f.read()

    with open(os.path.join(MOCK_DIR, "zastepstwa.html"), "r", encoding="utf-8") as f:
        sub_html = f.read()

    days = parse_schedule_html(sched_html)
    subs = parse_substitutions_html(sub_html)

    assert len(subs) == 2
    assert subs[0]["lesson_number"] == 3
    assert subs[0]["new_subject"] == "Administrowanie systemami operacyjnymi"

    merged = merge_schedule_with_substitutions(days, subs)
    mon = merged[0]

    # Lesson 3: Polish replaced with Operating Systems Administration
    l3 = mon.lessons[2]
    assert l3.is_substitution is True
    assert "Administrowanie systemami operacyjnymi" in l3.subject
    assert l3.room == "s. 202"
    assert l3.teacher == "Nowak A."
    assert "nieobecnego" in l3.substitution_note

    # Lesson 4: German replaced with History
    l4 = mon.lessons[3]
    assert l4.is_substitution is True
    assert "Historia" in l4.subject
    assert l4.room == "s. 204"
    assert l4.teacher == "Kowalski J."


def test_colors():
    assert get_subject_color("Historia") == "#1D3BB5"
    assert get_subject_color("Fizyka") == "#B52763"
    assert get_subject_color("Administrowanie systemami operacyjnymi") == "#2563EB"
    assert get_subject_color("Wychowanie fizyczne") == "#15803D"


if __name__ == "__main__":
    test_parse_schedule_html()
    test_parse_and_merge_substitutions()
    test_colors()
    print("All parser tests passed successfully!")
