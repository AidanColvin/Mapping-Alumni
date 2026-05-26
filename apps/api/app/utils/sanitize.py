"""Input sanitization helpers."""
import re


def escape_sparql_string(s: str) -> str:
    """Escape characters that would break a SPARQL string literal."""
    return (
        s.replace("\\", "\\\\")
         .replace('"', '\\"')
         .replace("\n", " ")
         .replace("\r", " ")
    )


def strip_control_chars(s: str) -> str:
    """Remove ASCII control characters from user input."""
    return re.sub(r"[\x00-\x1f\x7f]", "", s)


def sanitize_search_name(name: str) -> str:
    """Normalize and escape a university/person name for external queries."""
    return escape_sparql_string(strip_control_chars(name).strip())
