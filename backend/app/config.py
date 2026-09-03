"""
Application configuration for LibrusWatch Backend.
"""
import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "LibrusWatch Backend"
    APP_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api"
    
    # Security & Encryption Key (for storing credentials safely in SQLite)
    ENCRYPTION_KEY: str = os.getenv("ENCRYPTION_KEY", "librus-watch-default-secret-key-32b")
    JWT_SECRET: str = os.getenv("JWT_SECRET", "librus-watch-jwt-secret-key-change-me")
    
    # SQLite Database Path
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./librus_watch.db")
    
    # Librus URLs
    LIBRUS_BASE_URL: str = "https://synergia.librus.pl"
    LIBRUS_LOGIN_URL: str = "https://synergia.librus.pl/loguj"
    LIBRUS_SCHEDULE_URL: str = "https://synergia.librus.pl/przegladaj_plan_lekcji"
    LIBRUS_SUBSTITUTIONS_URL: str = "https://synergia.librus.pl/zastepstwa"
    
    # Cache settings (seconds)
    SCHEDULE_CACHE_TTL_SECONDS: int = 600  # 10 minutes cache
    
    class Config:
        env_file = ".env"
        extra = "allow"


settings = Settings()
