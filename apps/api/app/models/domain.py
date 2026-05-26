"""Core domain models — pure Python dataclasses, no FastAPI/Pydantic coupling."""
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass
class Institution:
    name: str
    wikidata_id: str | None = None
    source_url: str | None = None


@dataclass
class Company:
    name: str
    wikidata_id: str | None = None
    sector: str | None = None
    website: str | None = None
    source_url: str | None = None


@dataclass
class Employment:
    company: Company
    title: str | None = None
    is_current: bool = False


@dataclass
class Person:
    full_name: str
    wikidata_id: str | None = None
    source_url: str | None = None


@dataclass
class SearchResult:
    person: Person
    institution: Institution
    employment: Employment | None = None
    source_url: str | None = None
    source_type: str | None = None
    confidence: float = 0.0
    title_level: str | None = None
    sector: str | None = None
