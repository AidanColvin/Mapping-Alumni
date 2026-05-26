from app.utils.normalize import name_key, normalize


def test_normalize_collapses_whitespace():
    assert normalize("  Hello   World  ") == "hello world"


def test_name_key_strips_punctuation():
    assert name_key("Jane A. Smith Jr.") == name_key("jane a smith jr")
