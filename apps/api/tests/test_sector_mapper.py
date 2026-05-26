from app.services.sector_mapper import map_sector


def test_tech_company():
    assert map_sector("Google LLC") == "technology"


def test_bank():
    assert map_sector("Goldman Sachs") == "finance"


def test_hospital():
    assert map_sector("Mayo Clinic") == "healthcare"


def test_unknown():
    assert map_sector("Random Co") == "other"


def test_empty():
    assert map_sector("") == "other"
