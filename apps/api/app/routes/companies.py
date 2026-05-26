from fastapi import APIRouter, Query

from app.services.sector_mapper import SECTOR_KEYWORDS

router = APIRouter(prefix="/api/companies", tags=["companies"])


@router.get("/sectors")
def list_sectors(q: str | None = Query(default=None)) -> dict:
    """Return available sectors and example keywords."""
    if q:
        return {q: SECTOR_KEYWORDS.get(q, [])}
    return {k: v[:5] for k, v in SECTOR_KEYWORDS.items()}
