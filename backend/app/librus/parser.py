"""
Librus Synergia HTML Scraper & Schedule/Substitutions Parser.
"""
import re
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
from bs4 import BeautifulSoup, Tag
from ..models import Lesson, DaySchedule, WeekScheduleResponse


# Palette matching Librus Synergia app styling (seen in screenshot)
SUBJECT_COLOR_PALETTE = {
    # Humanities / History
    "historia": "#1D3BB5",
    "historia i teraźniejszość": "#1D3BB5",
    "wiedza o społeczeństwie": "#9D174D",
    "edukacja obywatelska": "#B52763",
    "filozofia": "#4338CA",
    
    # STEM / Exact Sciences
    "fizyka": "#B52763",
    "matematyka": "#1E40AF",
    "chemia": "#831843",
    "biologia": "#047857",
    "geografia": "#0F766E",
    
    # IT / Technical
    "informatyka": "#2563EB",
    "administrowanie systemami operacyjnymi": "#2563EB",
    "programowanie": "#0284C7",
    "bazy danych": "#0369A1",
    "sieci komputerowe": "#1D4ED8",
    
    # Languages
    "język polski": "#3B82F6",
    "język angielski": "#1E40AF",
    "język niemiecki": "#374151",
    "język hiszpański": "#B45309",
    "język rosyjski": "#4B5563",
    
    # Others
    "wychowanie fizyczne": "#15803D",
    "wf": "#15803D",
    "religia": "#6B7280",
    "etyka": "#6B7280",
    "godzina wychowawcza": "#6D28D9",
    "zajęcia z wychowawcą": "#6D28D9",
}

DEFAULT_COLORS = [
    "#1D3BB5", "#B52763", "#2563EB", "#047857", 
    "#6D28D9", "#0F766E", "#831843", "#3B82F6"
]


def get_subject_color(subject_name: str) -> str:
    cleaned = subject_name.lower().strip()
    for key, color in SUBJECT_COLOR_PALETTE.items():
        if key in cleaned or cleaned in key:
            return color
    # Fallback to deterministic hash
    hash_val = sum(ord(c) for c in cleaned)
    return DEFAULT_COLORS[hash_val % len(DEFAULT_COLORS)]


def clean_text(text: Optional[str]) -> str:
    if not text:
        return ""
    # Normalize whitespaces
    return re.sub(r"\s+", " ", text).strip()


def parse_schedule_html(html_content: str, week_start_fallback: Optional[str] = None) -> List[DaySchedule]:
    """
    Parses Librus /przegladaj_plan_lekcji HTML into DaySchedule objects.
    """
    soup = BeautifulSoup(html_content, "html.parser")
    
    # Find schedule table
    table = soup.find("table", class_=lambda c: c and "plan-lekcji" in c)
    if not table:
        table = soup.find("table", class_=lambda c: c and "decorated" in c)
    
    if not table:
        return []

    # Parse headers for days (usually Mon..Fri)
    # Header format: th containing "Poniedziałek\n01-09-2025" or similar
    day_headers: List[Dict[str, Any]] = []
    header_row = table.find("tr")
    if not header_row:
        return []

    day_names_polish = ["Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota", "Niedziela"]
    day_shorts = ["Pon", "Wt", "Śr", "Czw", "Pt", "Sob", "Niedz"]

    cols = header_row.find_all(["th", "td"])
    day_col_indices = []
    
    for idx, col in enumerate(cols):
        text = clean_text(col.text)
        matched_day = None
        for i, dname in enumerate(day_names_polish):
            if dname.lower() in text.lower():
                # Extract date if present, e.g. 2025-09-01 or 01.09.2025
                date_match = re.search(r"(\d{4}[-/]\d{2}[-/]\d{2})|(\d{2}[./-]\d{2}[./-]\d{4})", text)
                date_str = ""
                if date_match:
                    raw_d = date_match.group(0)
                    if "." in raw_d or (len(raw_d.split("-")[0]) == 2 and "-" in raw_d):
                        parts = re.split(r"[.-]", raw_d)
                        date_str = f"{parts[2]}-{parts[1]}-{parts[0]}"
                    else:
                        date_str = raw_d
                
                day_headers.append({
                    "col_idx": idx,
                    "day_name": dname,
                    "day_short": day_shorts[i],
                    "date_str": date_str,
                    "day_index": i
                })
                day_col_indices.append(idx)
                break

    # If headers didn't have explicit dates, calculate dates based on current week
    today = datetime.now()
    monday = today - timedelta(days=today.weekday())
    for d in day_headers:
        if not d["date_str"]:
            target_date = monday + timedelta(days=d["day_index"])
            d["date_str"] = target_date.strftime("%Y-%m-%d")

    # Map each column index to a DaySchedule
    days_map: Dict[int, DaySchedule] = {}
    for d in day_headers:
        days_map[d["col_idx"]] = DaySchedule(
            day_name=d["day_name"],
            day_short=d["day_short"],
            date_str=d["date_str"],
            lessons=[]
        )

    # Parse lesson rows
    rows = table.find_all("tr")[1:]  # skip header
    for row in rows:
        tds = row.find_all(["td", "th"])
        if len(tds) < 2:
            continue

        # Usually col 0 is lesson number, col 1 is hours (or combined in col 0/1)
        lesson_num = 0
        time_start = ""
        time_end = ""

        # Check for lesson number
        col0_text = clean_text(tds[0].text)
        num_match = re.search(r"^\d+", col0_text)
        if num_match:
            lesson_num = int(num_match.group(0))

        # Check for time interval e.g. "08:00 - 08:45"
        for candidate_col in tds[:2]:
            t_match = re.search(r"(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})", candidate_col.text)
            if t_match:
                time_start = t_match.group(1).zfill(5)
                time_end = t_match.group(2).zfill(5)
                break

        if not time_start and not lesson_num:
            continue

        # Default standard lesson times if only lesson number was available
        if not time_start and lesson_num > 0:
            std_times = [
                ("08:00", "08:45"), ("08:50", "09:35"), ("09:45", "10:30"),
                ("10:50", "11:35"), ("11:40", "12:25"), ("12:45", "13:30"),
                ("13:35", "14:20"), ("14:25", "15:10"), ("15:15", "16:00")
            ]
            if lesson_num <= len(std_times):
                time_start, time_end = std_times[lesson_num - 1]
            else:
                time_start, time_end = ("08:00", "08:45")

        # Now iterate day columns
        for col_idx, day_obj in days_map.items():
            if col_idx >= len(tds):
                continue
            cell = tds[col_idx]
            
            # Extract lesson info from cell
            # Librus often has <div class="text"> or multiple inner divs for groups
            cell_text = clean_text(cell.text)
            if not cell_text or cell_text == "-":
                continue

            # Check for cancellation or substitution markers in class or style
            classes = cell.get("class", [])
            cell_html = str(cell)
            is_cancelled = "plan-lekcji-odwolana" in classes or "line-through" in cell_html or "odwołana" in cell_text.lower()
            is_subst = "plan-lekcji-zastepstwo" in classes or "zastępstwo" in cell_text.lower()

            # Room extraction e.g. "s. 204", "sala 12", "s.204", "s 15"
            room_match = re.search(r"(?:s\.\s*|sala\s*|s\s+)(\d+[A-Za-z]?|gim|wf|h)", cell_text, re.IGNORECASE)
            room = None
            if room_match:
                room = f"s. {room_match.group(1)}"
                cell_text_no_room = cell_text.replace(room_match.group(0), "").strip()
            else:
                cell_text_no_room = cell_text

            # Subject extraction
            # Often before room or inside <b> / <span class="przedmiot">
            subj_tag = cell.find(class_=lambda c: c and "przedmiot" in c)
            if subj_tag:
                subject = clean_text(subj_tag.text)
            else:
                # Remove teacher initials if in parentheses or at the end
                subject = re.sub(r"\([A-Za-z0-9\s.,-]+\)", "", cell_text_no_room).strip()
                subject = re.sub(r"[A-Z]\.[A-Z]\.?", "", subject).strip()
                if not subject:
                    subject = cell_text

            # Teacher initials if found
            teacher_match = re.search(r"([A-ZĄĆĘŁŃÓŚŹŻ][a-ząćęłńóśźż]+\s+[A-ZĄĆĘŁŃÓŚŹŻ]\.|\([A-ZĄĆĘŁŃÓŚŹŻa-ząćęłńóśźż\s.]+\))", cell_text)
            teacher = clean_text(teacher_match.group(0)) if teacher_match else None

            lesson_id = f"{day_obj.day_short.lower()}_{lesson_num}_{time_start.replace(':', '')}"

            lesson = Lesson(
                id=lesson_id,
                lesson_number=lesson_num,
                subject=subject,
                time_start=time_start,
                time_end=time_end,
                room=room,
                teacher=teacher,
                color=get_subject_color(subject),
                is_substitution=is_subst,
                is_cancelled=is_cancelled
            )
            day_obj.lessons.append(lesson)

    # Sort lessons inside each day by time_start / lesson_number
    result: List[DaySchedule] = []
    for day in days_map.values():
        day.lessons.sort(key=lambda x: (x.time_start, x.lesson_number))
        result.append(day)

    return result


def parse_substitutions_html(html_content: str) -> List[Dict[str, Any]]:
    """
    Parses Librus /zastepstwa HTML page into structured substitution items.
    """
    soup = BeautifulSoup(html_content, "html.parser")
    substitutions: List[Dict[str, Any]] = []

    # Find substitution tables / containers
    tables = soup.find_all("table", class_=lambda c: c and ("decorated" in c or "zastepstwa" in c))
    if not tables:
        tables = soup.find_all("table")

    current_date = ""

    for table in tables:
        # Check if preceding header has a date
        prev_h = table.find_previous(["h2", "h3", "caption", "p"])
        if prev_h:
            h_text = clean_text(prev_h.text)
            date_match = re.search(r"(\d{4}-\d{2}-\d{2})|(\d{2}[.-]\d{2}[.-]\d{4})", h_text)
            if date_match:
                raw_d = date_match.group(0)
                if "." in raw_d or (len(raw_d.split("-")[0]) == 2 and "-" in raw_d):
                    parts = re.split(r"[.-]", raw_d)
                    current_date = f"{parts[2]}-{parts[1]}-{parts[0]}"
                else:
                    current_date = raw_d

        rows = table.find_all("tr")
        for row in rows:
            tds = row.find_all(["td", "th"])
            if len(tds) < 3:
                continue

            row_text = " | ".join([clean_text(td.text) for td in tds])
            # Skip header rows
            if "lekcja" in row_text.lower() and "przedmiot" in row_text.lower():
                continue

            # Parse columns:
            # Standard Librus format:
            # [Nr lekcji / Czas] [Klasa / Przedmiot] [Sala] [Nauczyciel] [Zastępca] [Uwagi]
            lesson_str = clean_text(tds[0].text)
            lesson_num_match = re.search(r"\d+", lesson_str)
            lesson_num = int(lesson_num_match.group(0)) if lesson_num_match else 0

            desc = clean_text(tds[1].text)
            sala = clean_text(tds[2].text) if len(tds) > 2 else ""
            teacher = clean_text(tds[3].text) if len(tds) > 3 else ""
            substitute = clean_text(tds[4].text) if len(tds) > 4 else ""
            note = clean_text(tds[5].text) if len(tds) > 5 else ""

            # Check if there is an arrow "Subject A -> Subject B" in desc
            old_subj = None
            new_subj = None
            if "->" in desc or "→" in desc:
                parts = re.split(r"->|→", desc)
                old_subj = clean_text(parts[0])
                new_subj = clean_text(parts[1])
            else:
                new_subj = desc

            is_cancelled = "odwołan" in row_text.lower() or "okienko" in row_text.lower()

            substitutions.append({
                "date": current_date,
                "lesson_number": lesson_num,
                "original_subject": old_subj,
                "new_subject": new_subj,
                "room": sala if sala else None,
                "teacher": teacher if teacher else None,
                "substitute": substitute if substitute else None,
                "note": note if note else f"Zastępstwo: {substitute}",
                "is_cancelled": is_cancelled
            })

    return substitutions


def merge_schedule_with_substitutions(days: List[DaySchedule], substitutions: List[Dict[str, Any]]) -> List[DaySchedule]:
    """
    Applies substitutions to the weekly schedule.
    Matches by date and lesson_number or subject name.
    """
    for day in days:
        for lesson in day.lessons:
            # Find matching substitution
            for sub in substitutions:
                # Match by date and lesson number
                date_match = (not sub.get("date")) or (sub.get("date") == day.date_str)
                lesson_match = (sub.get("lesson_number") == lesson.lesson_number)
                
                # Or match by original subject if lesson number not specified
                subj_match = sub.get("original_subject") and (sub.get("original_subject").lower() in lesson.subject.lower())

                if date_match and (lesson_match or subj_match):
                    lesson.is_substitution = True
                    lesson.is_cancelled = sub.get("is_cancelled", False)
                    lesson.substitution_type = "Odwołane" if lesson.is_cancelled else "Zastępstwo"
                    lesson.substitution_note = sub.get("note")

                    if sub.get("original_subject"):
                        lesson.original_subject = lesson.subject
                        lesson.subject = f"{sub['original_subject']} → {sub['new_subject']}"
                    elif sub.get("new_subject") and sub["new_subject"] != lesson.subject:
                        lesson.original_subject = lesson.subject
                        lesson.subject = f"{lesson.subject} → {sub['new_subject']}"

                    if sub.get("room") and sub["room"] != lesson.room:
                        lesson.original_room = lesson.room
                        lesson.room = sub["room"]

                    if sub.get("substitute"):
                        lesson.original_teacher = lesson.teacher
                        lesson.teacher = sub["substitute"]

                    # Update color if new subject has a specific color
                    if sub.get("new_subject"):
                        lesson.color = get_subject_color(sub["new_subject"])
                    break

    return days
