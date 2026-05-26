from pydantic import BaseModel
from typing import List, Dict, Optional, Any
from app.models.domain import SearchResult, Institution

SearchResultSchema = SearchResult

class SearchInput(BaseModel):
    university: str
    sector: Optional[str] = None
    title_level: Optional[str] = None
    company_type: Optional[str] = None
    region: Optional[str] = None
    keyword: Optional[str] = None
    limit: int = 50
    offset: int = 0

class SearchResponse(BaseModel):
    results: List[SearchResultSchema]
    total: int
    institution: Optional[Dict[str, Any]] = None

class SourcesResponse(BaseModel):
    sources: List[Dict[str, str]]

class HealthResponse(BaseModel):
    status: str
    database: str

class UniversityResponse(BaseModel):
    institution: Dict[str, Any]
    top_employers: List[Dict[str, Any]] = []
