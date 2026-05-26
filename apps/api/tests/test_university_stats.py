from datetime import datetime, timezone

from app.models.domain import Company, Employment, Institution, Person, SearchResult
from app.services.university_stats import sector_breakdown, title_level_breakdown, top_employers

_INST = Institution(id="u1", name="Test U", slug="test-u")


def _make(name: str, employer: str | None, sector: str = "other", level: str = "individual") -> SearchResult:
    emp = []
    if employer:
        emp.append(
            Employment(
                company=Company(id="c1", name=employer, slug="e"),
                title="role",
                title_level=level,
                sector=sector,
                is_current=True,
            )
        )
    return SearchResult(
        person=Person(
            id=name,
            full_name=name,
            source_url="https://x",
            source_type="wikidata",
            retrieved_at=datetime.now(timezone.utc),
            confidence=0.6,
        ),
        employment=emp,
        institution=_INST,
    )


def test_top_employers_counts_correctly():
    alumni = [
        _make("A", "Google"),
        _make("B", "Google"),
        _make("C", "Apple"),
    ]
    result = top_employers(alumni, n=5)
    assert result[0] == {"company": "Google", "count": 2}
    assert result[1] == {"company": "Apple", "count": 1}


def test_top_employers_respects_limit():
    alumni = [_make(str(i), f"Co{i}") for i in range(20)]
    assert len(top_employers(alumni, n=5)) == 5


def test_sector_breakdown():
    alumni = [
        _make("A", "G", sector="technology"),
        _make("B", "M", sector="technology"),
        _make("C", "B", sector="finance"),
    ]
    bd = sector_breakdown(alumni)
    assert bd["technology"] == 2
    assert bd["finance"] == 1


def test_title_level_breakdown():
    alumni = [
        _make("A", "G", level="c_suite"),
        _make("B", "M", level="c_suite"),
        _make("C", "B", level="director"),
    ]
    bd = title_level_breakdown(alumni)
    assert bd["c_suite"] == 2
    assert bd["director"] == 1
