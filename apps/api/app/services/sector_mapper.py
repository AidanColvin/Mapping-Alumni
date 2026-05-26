"""Map company names and employer labels to industry sectors."""

_KEYWORD_MAP: list[tuple[list[str], str]] = [
    (["bank", "capital", "invest", "finance", "financial", "asset", "hedge", "equity", "credit", "insurance"], "finance"),
    (["health", "pharma", "bio", "medical", "hospital", "clinic", "therapeutics", "genomics"], "healthcare"),
    (["tech", "software", "cloud", "data", "ai", "cyber", "digital", "compute", "platform", "saas"], "technology"),
    (["consult", "advisory", "mckinsey", "bain", "bcg", "deloitte", "pwc", "kpmg", "accenture"], "consulting"),
    (["law", "legal", "llp", "attorney", "counsel", "litigation"], "legal"),
    (["media", "news", "publish", "broadcast", "entertainment", "film", "music", "studio"], "media"),
    (["university", "college", "school", "academy", "institute", "education", "research"], "education"),
    (["government", "federal", "state", "department", "agency", "bureau", "ministry"], "government"),
    (["nonprofit", "foundation", "charity", "ngo", "association", "society"], "nonprofit"),
    (["energy", "oil", "gas", "solar", "wind", "renewable", "utility", "power"], "energy"),
    (["retail", "consumer", "brand", "store", "fashion", "food", "beverage", "restaurant"], "consumer"),
    (["real estate", "property", "realty", "reit"], "real_estate"),
    (["telecom", "wireless", "mobile", "network", "communications"], "telecom"),
    (["transport", "logistics", "shipping", "aviation", "airline", "rail", "auto"], "transportation"),
    (["defense", "aerospace", "military", "security", "intelligence"], "defense"),
]


def map_sector(company_name: str) -> str:
    """Return the best-match sector for a company name string."""
    if not company_name:
        return "unknown"
    lower = company_name.lower()
    for keywords, sector in _KEYWORD_MAP:
        if any(kw in lower for kw in keywords):
            return sector
    return "other"
