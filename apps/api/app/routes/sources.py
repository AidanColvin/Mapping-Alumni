from fastapi import APIRouter

from app.models.api import SourcesResponse
from app.sources.registry import ALLOWED_DOMAINS

router = APIRouter(prefix="/api/sources", tags=["sources"])


@router.get("", response_model=SourcesResponse)
def list_sources() -> SourcesResponse:
    return SourcesResponse(allowed_domains=ALLOWED_DOMAINS)
