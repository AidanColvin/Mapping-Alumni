from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.university_stats import top_employers, sector_breakdown


def _r(company: str, sector: str | None = None) -> SearchResult:
    return SearchResult(
        person=Person(full_name="X"),
        institution=Institution(name="UNC"),
        employment=Employment(company=Company(name=company)),
        sector=sector,
    )


def test_top_employers():
    alumni = [_r("Google"), _r("Google"), _r("Apple")]
    top = top_employers(alumni, n=2)
    assert top[0]["employer"] == "Google"
    assert top[0]["count"] == 2


def test_sector_breakdown():
    alumni = [_r("x", sector="technology"), _r("y", sector="technology"), _r("z", sector="finance")]
    bd = sector_breakdown(alumni)
    assert bd["technology"] == 2
    assert bd["finance"] == 1
