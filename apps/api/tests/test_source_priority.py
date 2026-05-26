from app.services.source_priority import higher


def test_sec_beats_wikidata():
    assert higher("sec_filing", "wikidata") == "sec_filing"


def test_wikidata_beats_wikipedia():
    assert higher("wikidata", "wikipedia") == "wikidata"


def test_wikipedia_beats_company_site():
    assert higher("wikipedia", "company_site") == "wikipedia"


def test_same_priority_keeps_first():
    assert higher("wikidata", "wikidata") == "wikidata"


def test_unknown_source_loses():
    assert higher("sec_filing", "unknown_source") == "sec_filing"
