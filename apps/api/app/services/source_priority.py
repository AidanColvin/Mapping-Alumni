"""Pick the higher-priority source type when records conflict."""
PRIORITY: dict[str, int] = {
    "sec_filing": 5,
    "wikidata": 4,
    "wikipedia": 3,
    "company_site": 2,
    "university_page": 1,
}


def higher(a: str, b: str) -> str:
    return a if PRIORITY.get(a, 0) >= PRIORITY.get(b, 0) else b
