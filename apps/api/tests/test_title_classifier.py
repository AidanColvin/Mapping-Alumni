from app.services.title_classifier import classify


def test_ceo_is_c_suite():
    assert classify("CEO") == "c_suite"
    assert classify("Chief Technology Officer") == "c_suite"


def test_founder():
    assert classify("Co-Founder") == "founder"


def test_vp():
    assert classify("VP of Engineering") == "vp"
    assert classify("Senior Vice President") == "vp"


def test_director():
    assert classify("Director of Sales") == "director"


def test_unknown_falls_through():
    assert classify("Analyst") == "individual"
    assert classify("") == "unknown"
