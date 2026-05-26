"""Aggregate statistics over a list of SearchResults for a university page."""
from collections import Counter
from app.models.domain import SearchResult


def top_employers(alumni: list[SearchResult], n: int = 10) -> list[dict]:
    """Return the top-n employers by alumni count."""
    counts: Counter[str] = Counter()
    for r in alumni:
        if r.employment and r.employment.company:
            name = r.employment.company.name
            if name and name != "Unknown":
                counts[name] += 1
    return [{"employer": name, "count": cnt} for name, cnt in counts.most_common(n)]


def sector_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return a sector → count mapping."""
    counts: Counter[str] = Counter()
    for r in alumni:
        counts[r.sector or "unknown"] += 1
    return dict(counts)


def title_level_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return a title_level → count mapping."""
    counts: Counter[str] = Counter()
    for r in alumni:
        counts[r.title_level or "unknown"] += 1
    return dict(counts)
