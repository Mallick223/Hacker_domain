from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Swap this for a real Postgres URL in production, e.g.:
    # postgresql://user:password@localhost:5432/tourist_safety
    database_url: str = "sqlite:///./tourist_safety.db"

    secret_key: str = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET_IN_PRODUCTION"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days

    # How old a location ping can be before a tourist is considered "offline"
    stale_location_minutes: int = 30

    class Config:
        env_file = ".env"


settings = Settings()
