from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.confidence_scorer import score


def _result(source_type: str, has_title: bool = True, wikidata_id: str | None = "Q1") -> SearchResult:
    return SearchResult(
        person=Person(full_name="Alice", wikidata_id=wikidata_id, source_url="https://wikidata.org/wiki/Q1"),
        institution=Institution(name="UNC", wikidata_id="Q902595"),
        employment=Employment(
            company=Company(name="Google"),
            title="CEO" if has_title else None,
        ),
        source_url="https://wikidata.org/wiki/Q1",
        source_type=source_type,
    )


def test_wikidata_with_full_data():
    s = score(_result("wikidata"))
    assert 0.9 <= s <= 1.0


def test_sec_filing_high():
    s = score(_result("sec_filing"))
    assert s > 0.8


def test_public_web_lower():
    s = score(_result("public_web"))
    assert s < 0.8


def test_clamped_to_one():
    s = score(_result("sec_filing"))
    assert s <= 1.0
