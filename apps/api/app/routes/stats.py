from pathlib import Path

from fastapi import APIRouter

from app.config import settings
from app.db import get_conn
from app.models.api import StatsResponse

router = APIRouter(prefix="/api/stats", tags=["stats"])


@router.get("", response_model=StatsResponse)
def stats() -> StatsResponse:
    try:
        with get_conn() as conn:
            i = conn.execute("SELECT COUNT(*) FROM institutions").fetchone()[0]
            p = conn.execute("SELECT COUNT(*) FROM people").fetchone()[0]
    except Exception:
        i, p = 0, 0

    cache_dir = Path(settings.cache_dir)
    cached = len(list(cache_dir.glob("*.json"))) if cache_dir.exists() else 0
    return StatsResponse(institutions=i, people=p, cached_pages=cached)
