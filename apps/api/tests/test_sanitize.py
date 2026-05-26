from app.utils.sanitize import escape_sparql_string, sanitize_search_name


def test_escape_quotes():
    assert escape_sparql_string('say "hello"') == 'say \\"hello\\"'


def test_escape_backslash():
    assert escape_sparql_string("back\\slash") == "back\\\\slash"


def test_strips_control_chars():
    assert sanitize_search_name("UNC\x00Chapel Hill") == "UNC Chapel Hill"


def test_empty_string():
    assert sanitize_search_name("") == ""
