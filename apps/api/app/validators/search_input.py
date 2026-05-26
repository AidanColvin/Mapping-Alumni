"""Input validation schemas."""
from typing import Optional

from pydantic import BaseModel, Field

from app.models.domain import TitleLevel


class SearchInput(BaseModel):
    university: str = Field(..., min_length=2, max_length=120)
    sector: Optional[str] = None
    title_level: Optional[TitleLevel] = None
    company_type: Optional[str] = None
    region: Optional[str] = None
    keyword: Optional[str] = None
    page: int = Field(default=1, ge=1)
    limit: int = Field(default=20, ge=1, le=50)
