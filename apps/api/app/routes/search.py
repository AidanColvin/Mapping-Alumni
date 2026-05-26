from fastapi import APIRouter, Depends, HTTPException, Request

from app.models.api import SearchResponse
from app.services.alumni_search import run
from app.utils import rate_limit
from app.validators.search_input import SearchInput

router = APIRouter(prefix="/api/search", tags=["search"])


@router.get("", response_model=SearchResponse)
async def search(request: Request, query: SearchInput = Depends()) -> SearchResponse:
    client_ip = request.client.host if request.client else "unknown"
    if not rate_limit.allow(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Please slow down.")

    results, total, institution = await run(query)
    if not results and not institution:
        raise HTTPException(status_code=404, detail="University not found")
    return SearchResponse(
        results=results,
        total=total,
        page=query.page,
        limit=query.limit,
        institution=institution,
    )
