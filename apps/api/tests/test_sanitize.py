from app.utils.sanitize import escape_sparql_string, sanitize_search_name, strip_control_chars


def test_escapes_double_quotes():
    result = escape_sparql_string('say "hello"')
    assert '\\"' in result
    # Original unescaped standalone " should not appear (only as part of \")
    assert result == 'say \\"hello\\"'


def test_escapes_backslash():
    assert escape_sparql_string("a\\b") == "a\\\\b"


def test_strips_newlines():
    result = escape_sparql_string("foo\nbar")
    assert "\n" not in result


def test_strip_control_chars():
    assert strip_control_chars("hello\x00world") == "helloworld"


def test_sanitize_search_name_removes_control_chars():
    result = sanitize_search_name("University\x01Name")
    assert "\x01" not in result


def test_sanitize_search_name_escapes_quotes():
    result = sanitize_search_name('"quoted"')
    assert result.startswith('\\"')
