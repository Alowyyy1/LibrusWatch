"""
Network client for interacting with Librus Synergia.
"""
import requests
import re
from typing import Optional, Dict, Any, Tuple
from bs4 import BeautifulSoup
from .parser import parse_schedule_html, parse_substitutions_html, merge_schedule_with_substitutions
from ..models import WeekScheduleResponse, DaySchedule
from datetime import datetime


DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive"
}


class LibrusClient:
    def __init__(self, username: str, password: str, cookies: Optional[Dict[str, str]] = None):
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.session.headers.update(DEFAULT_HEADERS)
        if cookies:
            self.session.cookies.update(cookies)

    def login(self) -> Tuple[bool, str, Optional[str]]:
        """
        Attempts login to synergia.librus.pl.
        Returns: (success: bool, message: str, student_name: Optional[str])
        """
        login_url = "https://synergia.librus.pl/loguj"
        
        try:
            # 1. First fetch login page to get initial cookies and hidden fields
            init_res = self.session.get(login_url, timeout=15)
            soup = BeautifulSoup(init_res.text, "html.parser")

            form_data = {
                "login": self.username,
                "passwd": self.password,
                "submit": "Zaloguj"
            }

            # Find any hidden form inputs (CSRF, token, etc.)
            form = soup.find("form", id="formLogowanie") or soup.find("form")
            if form:
                for inp in form.find_all("input", type="hidden"):
                    name = inp.get("name")
                    val = inp.get("value", "")
                    if name and name not in form_data:
                        form_data[name] = val

            # 2. POST login form
            post_headers = {
                "Referer": login_url,
                "Content-Type": "application/x-www-form-urlencoded"
            }
            res = self.session.post(login_url, data=form_data, headers=post_headers, timeout=15, allow_redirects=True)

            # Check if login succeeded
            # Failed logins usually contain "Błędny login lub hasło" or keep us on loguj
            if "błędny login" in res.text.lower() or "niepoprawny login" in res.text.lower():
                return False, "Niepoprawny login lub hasło Librus Synergia", None

            # Check for student name or indicators of logged-in portal
            student_name = None
            after_soup = BeautifulSoup(res.text, "html.parser")
            user_elem = after_soup.find("div", id="user-section") or after_soup.find(class_=lambda c: c and "logged" in c)
            if user_elem:
                student_name = user_elem.text.strip()
            
            # Check if redirected away from loguj or has cookies like PHPSESSID / Synergia
            if "loguj" not in res.url.lower() or student_name or "wyloguj" in res.text.lower():
                return True, "Zalogowano pomyślnie", student_name

            # Also check if main student page is accessible
            test_res = self.session.get("https://synergia.librus.pl/uczen/index", timeout=15)
            if "wyloguj" in test_res.text.lower():
                return True, "Zalogowano pomyślnie", None

            return False, "Nie udało się zalogować. Sprawdź poprawność danych.", None

        except requests.RequestException as e:
            return False, f"Błąd połączenia z serwerem Librus: {str(e)}", None

    def _ensure_authenticated(self) -> bool:
        """Checks if session is valid; if expired, re-authenticates."""
        check_url = "https://synergia.librus.pl/przegladaj_plan_lekcji"
        try:
            res = self.session.get(check_url, timeout=10, allow_redirects=False)
            if res.status_code == 200 and "wyloguj" in res.text.lower():
                return True
        except requests.RequestException:
            pass
        # Session expired or invalid, re-login
        success, _, _ = self.login()
        return success

    def get_week_schedule(self) -> Optional[WeekScheduleResponse]:
        """
        Fetches schedule and substitutions, parses, and returns WeekScheduleResponse.
        """
        if not self._ensure_authenticated():
            return None

        try:
            # 1. Fetch Schedule HTML
            sched_url = "https://synergia.librus.pl/przegladaj_plan_lekcji"
            sched_res = self.session.get(sched_url, timeout=15)
            days = parse_schedule_html(sched_res.text)

            # 2. Fetch Substitutions HTML
            sub_url = "https://synergia.librus.pl/zastepstwa"
            sub_res = self.session.get(sub_url, timeout=15)
            substitutions = parse_substitutions_html(sub_res.text)

            # 3. Merge schedule with substitutions
            merged_days = merge_schedule_with_substitutions(days, substitutions)

            now_iso = datetime.now().isoformat()
            week_start = merged_days[0].date_str if merged_days else datetime.now().strftime("%Y-%m-%d")
            week_end = merged_days[-1].date_str if merged_days else datetime.now().strftime("%Y-%m-%d")

            return WeekScheduleResponse(
                week_start=week_start,
                week_end=week_end,
                server_time=now_iso,
                last_synced=now_iso,
                days=merged_days
            )
        except requests.RequestException as e:
            print(f"Error fetching schedule: {e}")
            return None

    def get_cookies_dict(self) -> Dict[str, str]:
        return requests.utils.dict_from_cookiejar(self.session.cookies)
