"""Heuristic company-name to sector mapper."""
SECTOR_KEYWORDS: dict[str, list[str]] = {
    "technology": ["software", "tech", "ai", "data", "cloud", "cyber", "google", "meta", "microsoft", "apple"],
    "finance": ["bank", "capital", "invest", "financial", "fund", "asset", "goldman", "morgan"],
    "healthcare": ["health", "medical", "pharma", "biotech", "hospital", "clinic", "pfizer"],
    "government": ["department", "agency", "ministry", "federal", "state of", "city of"],
    "education": ["university", "college", "school", "institute", "academy"],
    "media": ["media", "news", "publishing", "broadcast", "times", "post"],
    "consulting": ["consulting", "advisory", "mckinsey", "deloitte", "bain", "bcg"],
    "legal": ["law", "legal", "attorney", "counsel"],
    "nonprofit": ["foundation", "nonprofit", "ngo", "charity"],
}


def map_sector(company_name: str) -> str:
    if not company_name:
        return "other"
    lower = company_name.lower()
    for sector, keywords in SECTOR_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            return sector
    return "other"
