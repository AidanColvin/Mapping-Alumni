"""Map raw job titles / Wikidata occupation labels to a TitleLevel enum value."""
import re

from app.models.domain import TitleLevel

PATTERNS: list[tuple[re.Pattern, TitleLevel]] = [
    (re.compile(r"\b(ceo|cto|coo|cfo|cpo|cmo|chief\b)", re.I), "c_suite"),
    (re.compile(r"\b(founder|co-?founder|entrepreneur)\b", re.I), "founder"),
    # Check "vice president" before "president" to avoid false match
    (re.compile(r"\b(vp|vice[\s-]president|svp|evp)\b", re.I), "vp"),
    (re.compile(r"\b(president|partner)\b", re.I), "c_suite"),
    (re.compile(r"\bdirector\b", re.I), "director"),
    (re.compile(r"\bmanager\b", re.I), "manager"),
    # Wikidata P106 occupation labels
    (re.compile(r"\b(politician|statesperson|senator|congressman|congresswoman|governor|mayor|diplomat|legislator)\b", re.I), "c_suite"),
    (re.compile(r"\b(businessperson|business person|executive|administrator|corporate officer)\b", re.I), "c_suite"),
    (re.compile(r"\b(lawyer|attorney|judge|jurist)\b", re.I), "director"),
    (re.compile(r"\b(professor|academic|researcher|scientist)\b", re.I), "director"),
    (re.compile(r"\b(journalist|writer|author|editor)\b", re.I), "individual"),
    (re.compile(r"\b(physician|surgeon|doctor)\b", re.I), "director"),
]


def classify(title: str) -> TitleLevel:
    if not title:
        return "unknown"
    for pattern, level in PATTERNS:
        if pattern.search(title):
            return level
    return "individual"
