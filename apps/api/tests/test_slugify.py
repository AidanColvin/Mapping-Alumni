from app.utils.slugify import slugify


def test_basic():
    assert slugify("University of North Carolina") == "university-of-north-carolina"


def test_accented():
    result = slugify("École Normale Supérieure")
    assert result == "ecole-normale-superieure"


def test_special_chars():
    assert slugify("MIT (Massachusetts)") == "mit-massachusetts"


def test_multiple_spaces():
    assert slugify("Duke  University") == "duke-university"
