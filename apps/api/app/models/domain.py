"""Core domain types. Pydantic models for safe IO."""
from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field

TitleLevel = Literal["c_suite", "founder", "vp", "director", "manager", "individual", "unknown"]
SourceType = Literal["wikidata", "wikipedia", "company_site", "sec_filing", "university_page"]


class Institution(BaseModel):
    id: str
    name: str
    slug: str
    aliases: list[str] = Field(default_factory=list)
    country: Optional[str] = None
    wikidata_id: Optional[str] = None


class Company(BaseModel):
    id: str
    name: str
    slug: str
    sector: Optional[str] = None
    domain: Optional[str] = None


class Employment(BaseModel):
    company: Optional[Company] = None
    title: str = ""
    title_level: TitleLevel = "unknown"
    sector: str = "other"
    is_current: bool = False


class Person(BaseModel):
    id: str
    full_name: str
    source_url: str
    source_type: SourceType
    retrieved_at: datetime
    confidence: float = 0.5
    verified_fields: list[str] = Field(default_factory=list)


class SearchResult(BaseModel):
    person: Person
    employment: list[Employment] = Field(default_factory=list)
    institution: Optional[Institution] = None
