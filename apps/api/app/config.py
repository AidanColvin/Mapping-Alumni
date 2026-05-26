"""Application configuration via environment variables."""
from __future__ import annotations
import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./alumnimap.db"
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:3001",
        "https://your-org.github.io",  # update to your actual GitHub Pages URL
    ]
    rate_limit_per_minute: int = 30
    cache_dir: str = ".cache"
    log_level: str = "INFO"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
