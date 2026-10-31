from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Set DATABASE_URL in your .env for Postgres, e.g.:
    # DATABASE_URL=postgresql://guardian:guardian_dev_password@localhost:5432/guardian_go
    database_url: str

    @field_validator("database_url")
    @classmethod
    def require_postgres_database_url(cls, value: str) -> str:
        if not value.lower().startswith(("postgresql://", "postgresql+")):
            raise ValueError("DATABASE_URL must use PostgreSQL; SQLite is not supported.")
        return value

    # Redis is used for the SOS dispatch queue (see sos_queue.py)
    redis_url: str = "redis://localhost:6379/0"

    secret_key: str = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET_IN_PRODUCTION"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days

    stale_location_minutes: int = 30

    class Config:
        env_file = str(Path(__file__).resolve().with_name(".env"))


settings = Settings()
