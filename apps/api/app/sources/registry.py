"""Allowed source domains. Add new sources here, not in code."""

ALLOWED_DOMAINS: list[str] = [
    "wikidata.org",
    "query.wikidata.org",
    "en.wikipedia.org",
    "www.sec.gov",
    "www.unc.edu",
    "unc.edu",
]


def is_allowed_domain(domain: str) -> bool:
    return any(domain.endswith(d) for d in ALLOWED_DOMAINS)
