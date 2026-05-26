"""API request/response shapes."""
from typing import Optional

from pydantic import BaseModel

from app.models.domain import Institution, SearchResult, TitleLevel


class SearchResponse(BaseModel):
    results: list[SearchResult]
    total: int
    page: int
    limit: int
    institution: Optional[dict] = None


class UniversityResponse(BaseModel):
    institution: Institution
    alumni_count: int
    top_employers: list[dict]
    sector_breakdown: dict[str, int] = {}
    title_level_breakdown: dict[str, int] = {}


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"


class StatsResponse(BaseModel):
    institutions: int
    people: int
    cached_pages: int


class SourcesResponse(BaseModel):
    allowed_domains: list[str]


class ErrorResponse(BaseModel):
    error: str
    details: Optional[dict] = None
