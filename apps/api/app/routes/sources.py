from fastapi import APIRouter
from app.models.api import SourcesResponse
from app.adapters.registry import ALLOWED_DOMAINS

router = APIRouter()

@router.get("/", response_model=SourcesResponse)
async def get_sources():
    """Returns the list of verified public data sources."""
    sources_list = [{"id": k, "domain": v} for k, v in ALLOWED_DOMAINS.items()]
    return SourcesResponse(sources=sources_list)
