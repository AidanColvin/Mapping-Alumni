from app.models.domain import Person, Institution, Company, Employment, SearchResult
from app.services.deduper import dedupe


def _make(name: str, qid: str, inst_id: str = "Q1", confidence: float = 0.8) -> SearchResult:
    return SearchResult(
        person=Person(full_name=name, wikidata_id=qid),
        institution=Institution(name="UNC", wikidata_id=inst_id),
        employment=Employment(company=Company(name="Acme"), title="CEO"),
        confidence=confidence,
        source_type="wikidata",
    )


def test_removes_exact_duplicate():
    r1 = _make("Alice Smith", "Q1")
    r2 = _make("Alice Smith", "Q1", confidence=0.6)
    out = dedupe([r1, r2])
    assert len(out) == 1
    assert out[0].confidence == 0.8


def test_keeps_different_institutions():
    r1 = _make("James Wilson", "Q10", inst_id="Q100")
    r2 = _make("James Wilson", "Q11", inst_id="Q200")
    out = dedupe([r1, r2])
    assert len(out) == 2


def test_keeps_different_names():
    r1 = _make("Alice Smith", "Q1")
    r2 = _make("Bob Jones", "Q2")
    out = dedupe([r1, r2])
    assert len(out) == 2
