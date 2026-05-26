"""Aggregation helpers for university detail pages."""
from collections import Counter

from app.models.domain import SearchResult


def top_employers(alumni: list[SearchResult], n: int = 10) -> list[dict]:
    """Return the n most common employers across all alumni records."""
    counts: Counter = Counter()
    for r in alumni:
        for e in r.employment:
            if e.company:
                counts[e.company.name] += 1
    return [{"company": name, "count": cnt} for name, cnt in counts.most_common(n)]


def sector_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return count of alumni by sector."""
    counts: Counter = Counter()
    for r in alumni:
        for e in r.employment:
            counts[e.sector] += 1
    return dict(counts.most_common())


def title_level_breakdown(alumni: list[SearchResult]) -> dict[str, int]:
    """Return count of alumni by title level."""
    counts: Counter = Counter()
    for r in alumni:
        for e in r.employment:
            counts[e.title_level] += 1
    return dict(counts.most_common())
