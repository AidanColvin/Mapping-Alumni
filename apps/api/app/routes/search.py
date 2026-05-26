from fastapi import APIRouter, Depends, HTTPException, Request
from app.models.api import SearchInput, SearchResponse, SearchResultSchema
from app.services import alumni_search
from app.utils.logger import get_logger

log = get_logger(__name__)
router = APIRouter()

@router.get("/", response_model=SearchResponse)
async def search(request: Request, inp: SearchInput = Depends()) -> SearchResponse:
    """Execute the core alumni search pipeline."""
    try:
        results, total, institution = alumni_search.run(inp)
        return SearchResponse(
            results=results,
            total=total,
            institution=institution
        )
    except Exception as e:
        log.error(f"Search pipeline failed: {e}")
        raise HTTPException(status_code=500, detail="Internal server error during search.")
