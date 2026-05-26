from fastapi import APIRouter, HTTPException

from app.adapters import wikidata
from app.models.api import UniversityResponse
from app.services import university_resolver
from app.services.university_stats import sector_breakdown, title_level_breakdown, top_employers

router = APIRouter(prefix="/api/universities", tags=["universities"])


@router.get("/{slug}", response_model=UniversityResponse)
async def get_university(slug: str) -> UniversityResponse:
    institution = await university_resolver.resolve(slug.replace("-", " "))
    if not institution:
        raise HTTPException(status_code=404, detail="University not found")

    alumni = await wikidata.fetch_alumni(institution)

    return UniversityResponse(
        institution=institution,
        alumni_count=len(alumni),
        top_employers=top_employers(alumni),
        sector_breakdown=sector_breakdown(alumni),
        title_level_breakdown=title_level_breakdown(alumni),
    )
