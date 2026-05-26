from app.models.domain import Company
from app.services.company_enricher import enrich


def test_adds_sector_when_missing():
    c = Company(id="1", name="Goldman Sachs", slug="goldman-sachs")
    result = enrich(c)
    assert result.sector == "finance"


def test_does_not_overwrite_existing_sector():
    c = Company(id="1", name="Goldman Sachs", slug="goldman-sachs", sector="consulting")
    result = enrich(c)
    assert result.sector == "consulting"


def test_adds_slug_when_missing():
    c = Company(id="1", name="OpenAI Inc", slug="")
    result = enrich(c)
    assert result.slug == "openai-inc"


def test_does_not_overwrite_existing_slug():
    c = Company(id="1", name="OpenAI Inc", slug="custom-slug")
    result = enrich(c)
    assert result.slug == "custom-slug"


def test_unknown_company_gets_other_sector():
    c = Company(id="1", name="Obscure Widget Corp", slug="obscure")
    result = enrich(c)
    assert result.sector == "other"
