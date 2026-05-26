"""Enrich a company record with sector and slug."""
from app.models.domain import Company
from app.services.sector_mapper import map_sector
from app.utils.slugify import slugify


def enrich(company: Company) -> Company:
    company.sector = company.sector or map_sector(company.name)
    company.slug = company.slug or slugify(company.name)
    return company
