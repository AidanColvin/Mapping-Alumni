from app.services.title_classifier import classify


def test_ceo():
    assert classify("Chief Executive Officer") == "c_suite"


def test_cto():
    assert classify("CTO") == "c_suite"


def test_vp_before_president():
    assert classify("Vice President of Engineering") == "vp"


def test_president():
    assert classify("President") == "c_suite"


def test_founder():
    assert classify("Co-Founder & CEO") == "founder"


def test_director():
    assert classify("Director of Product") == "director"


def test_manager():
    assert classify("Senior Manager") == "manager"


def test_unknown():
    assert classify("") == "unknown"


def test_professor():
    assert classify("Professor") == "academic"


def test_politician():
    assert classify("Senator") == "government"
