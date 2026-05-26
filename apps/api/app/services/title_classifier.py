"""Classify a job title string into a seniority tier."""
import re

# Order matters — check more specific patterns first
_PATTERNS: list[tuple[str, str]] = [
    (r"\bfounder\b|\bco-founder\b|\bcofounder\b", "founder"),
    (r"\bchief\b.*\bofficer\b|\bceo\b|\bcto\b|\bcoo\b|\bcfo\b|\bciso\b|\bcmo\b", "c_suite"),
    (r"\bpresident\b", "c_suite"),
    (r"\bvice\s+president\b|\bvp\b|\bsvp\b|\bevp\b|\bexecutive\s+vice\b", "vp"),
    (r"\bdirector\b|\bhead\s+of\b|\bprincipal\b", "director"),
    (r"\bmanager\b|\blead\b|\bsenior\b", "manager"),
    # Wikidata P106 occupation labels
    (r"\bbusiness\s*person\b|\bentrepreneur\b|\bexecutive\b", "c_suite"),
    (r"\bpolitician\b|\bsenator\b|\bgovernor\b|\bminister\b", "government"),
    (r"\bscientist\b|\bresearcher\b|\bprofessor\b|\bacademic\b", "academic"),
    (r"\bphysician\b|\bdoctor\b|\bsurgeon\b", "medical"),
    (r"\bengine?er\b|\bdeveloper\b|\bprogrammer\b", "individual_contributor"),
    (r"\banalyst\b|\bassociate\b|\bspecialist\b|\bconsultant\b", "individual_contributor"),
]


def classify(title: str) -> str:
    """Return a seniority/occupation tier for the given title string."""
    if not title:
        return "unknown"
    lower = title.lower()
    for pattern, tier in _PATTERNS:
        if re.search(pattern, lower):
            return tier
    return "other"
