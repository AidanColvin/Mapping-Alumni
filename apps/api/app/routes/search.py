"""Search route — resolves university, runs pipeline, returns paginated results."""
from fastapi import APIRouter, HTTPException, Request

from app.models.api import SearchInput, SearchResponse, SearchResultSchema
from app.services import alumni_search
from app.utils.rate_limit import allow
from app.utils.logger import get_logger

router = APIRouter()
log = get_logger(__name__)


@router.get("/search", response_model=SearchResponse)
async def search(request: Request, inp: SearchInput = SearchInput()) -> SearchResponse:  # type: ignore[assignment]
    client_ip = request.client.host if request.client else "unknown"
    if not allow(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Please slow down.")

    results, total, institution = alumni_search.run(inp)

    if institution is None:
        raise HTTPException(
            status_code=404,
            detail=f"University not found: '{inp.university}'. Try a more specific name.",
        )

    return SearchResponse(
        results=[SearchResultSchema.from_domain(r) for r in results],
        total=total,
        offset=inp.offset,
        limit=inp.limit,
        university=institution,
    )
