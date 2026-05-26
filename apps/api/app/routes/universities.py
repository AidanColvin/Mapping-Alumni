"""University detail route."""
from fastapi import APIRouter, HTTPException

from app.models.api import SearchInput, UniversityResponse
from app.services import alumni_search, university_stats
from app.utils.slugify import slugify

router = APIRouter()


@router.get("/universities/{slug}", response_model=UniversityResponse)
async def get_university(slug: str) -> UniversityResponse:
    # Derive a search name by un-slugging (best effort)
    name = slug.replace("-", " ").title()
    inp = SearchInput(university=name, limit=200)
    alumni, total, institution = alumni_search.run(inp)

    if institution is None:
        raise HTTPException(status_code=404, detail=f"University not found: {slug}")

    return UniversityResponse(
        institution=institution,
        alumni_count=total,
        top_employers=university_stats.top_employers(alumni),
        sector_breakdown=university_stats.sector_breakdown(alumni),
        title_level_breakdown=university_stats.title_level_breakdown(alumni),
    )
