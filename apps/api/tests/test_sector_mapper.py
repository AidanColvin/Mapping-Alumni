from app.services.sector_mapper import map_sector


def test_tech():
    assert map_sector("Google Cloud Platform") == "technology"


def test_finance():
    assert map_sector("Goldman Sachs Capital") == "finance"


def test_healthcare():
    assert map_sector("UNC Health Hospitals") == "healthcare"


def test_consulting():
    assert map_sector("McKinsey & Company") == "consulting"


def test_education():
    assert map_sector("Duke University") == "education"


def test_unknown():
    assert map_sector("") == "unknown"


def test_other():
    assert map_sector("Zorg Industries") == "other"
