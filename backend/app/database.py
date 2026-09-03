"""
SQLite database management for sessions, credentials, and schedule caching.
"""
import sqlite3
import json
import base64
import hashlib
from datetime import datetime
from typing import Optional, Dict, Any
from .config import settings


def _get_cipher_key(key_str: str) -> bytes:
    return hashlib.sha256(key_str.encode("utf-8")).digest()


def encrypt_data(plaintext: str, secret_key: str = settings.ENCRYPTION_KEY) -> str:
    """Simple reversible encryption using SHA256 keystream XOR + base64."""
    key = _get_cipher_key(secret_key)
    raw_bytes = plaintext.encode("utf-8")
    encrypted = bytes([b ^ key[i % len(key)] for i, b in enumerate(raw_bytes)])
    return base64.b64encode(encrypted).decode("ascii")


def decrypt_data(ciphertext: str, secret_key: str = settings.ENCRYPTION_KEY) -> str:
    """Decrypt ciphertext encrypted with encrypt_data."""
    key = _get_cipher_key(secret_key)
    raw_bytes = base64.b64decode(ciphertext.encode("ascii"))
    decrypted = bytes([b ^ key[i % len(key)] for i, b in enumerate(raw_bytes)])
    return decrypted.decode("utf-8")


class Database:
    def __init__(self, db_path: str = "librus_watch.db"):
        # Strip sqlite:/// prefix if present
        if db_path.startswith("sqlite:///"):
            db_path = db_path.replace("sqlite:///", "")
        self.db_path = db_path
        self._init_db()

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    token TEXT PRIMARY KEY,
                    username TEXT NOT NULL UNIQUE,
                    encrypted_password TEXT NOT NULL,
                    student_name TEXT,
                    cookies_json TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS schedule_cache (
                    user_token TEXT PRIMARY KEY,
                    week_start TEXT NOT NULL,
                    data_json TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_token) REFERENCES users(token)
                )
            """)
            conn.commit()

    def save_user(self, token: str, username: str, password_raw: str, student_name: Optional[str] = None, cookies: Optional[dict] = None):
        enc_pw = encrypt_data(password_raw)
        cookies_str = json.dumps(cookies or {})
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO users (token, username, encrypted_password, student_name, cookies_json, last_active_at)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(username) DO UPDATE SET
                    token=excluded.token,
                    encrypted_password=excluded.encrypted_password,
                    student_name=COALESCE(excluded.student_name, users.student_name),
                    cookies_json=excluded.cookies_json,
                    last_active_at=CURRENT_TIMESTAMP
            """, (token, username, enc_pw, student_name, cookies_str))
            conn.commit()

    def get_user_by_token(self, token: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE token = ?", (token,))
            row = cursor.fetchone()
            if not row:
                return None
            user = dict(row)
            user["password"] = decrypt_data(user["encrypted_password"])
            user["cookies"] = json.loads(user["cookies_json"] or "{}")
            return user

    def update_user_cookies(self, token: str, cookies: dict):
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE users SET cookies_json = ?, last_active_at = CURRENT_TIMESTAMP WHERE token = ?
            """, (json.dumps(cookies), token))
            conn.commit()

    def save_schedule_cache(self, token: str, week_start: str, data_dict: dict):
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO schedule_cache (user_token, week_start, data_json, updated_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(user_token) DO UPDATE SET
                    week_start=excluded.week_start,
                    data_json=excluded.data_json,
                    updated_at=CURRENT_TIMESTAMP
            """, (token, week_start, json.dumps(data_dict)))
            conn.commit()

    def get_schedule_cache(self, token: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM schedule_cache WHERE user_token = ?", (token,))
            row = cursor.fetchone()
            if not row:
                return None
            res = dict(row)
            res["data"] = json.loads(res["data_json"])
            return res


db = Database(settings.DATABASE_URL)
