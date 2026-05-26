"""Application configuration loaded from environment."""
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./data/sqlite/alumnimap.db"
    cache_dir: str = "./data/cache"
    # EDGAR requires: "CompanyName admin@company.com"
    user_agent: str = "AlumniMap alumnimap@example.org"
    rate_limit_per_min: int = 30
    cache_ttl_hours: int = 24
    cors_origins: str = "http://localhost:3000,http://localhost:3001"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def cache_path(self) -> Path:
        p = Path(self.cache_dir)
        p.mkdir(parents=True, exist_ok=True)
        return p


settings = Settings()
