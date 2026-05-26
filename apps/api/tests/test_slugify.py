from app.utils.slugify import slugify


def test_basic():
    assert slugify("University of North Carolina") == "university-of-north-carolina"


def test_strips_punctuation():
    assert slugify("Harvard University!!") == "harvard-university"


def test_transliterates_unicode():
    # É → E (via NFKD) → "ecole-normale" not "cole-normale"
    assert slugify("École Normale") == "ecole-normale"


def test_collapses_multiple_hyphens():
    assert slugify("a  b   c") == "a-b-c"


def test_strips_leading_trailing_hyphens():
    assert slugify("  -test-  ") == "test"


def test_empty_string():
    assert slugify("") == ""
