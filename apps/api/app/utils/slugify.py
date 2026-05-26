"""URL-safe slug generation."""
import re
import unicodedata


def slugify(text: str) -> str:
    """Convert text to a lowercase URL-safe slug, handling non-ASCII characters."""
    # Normalize unicode → decompose accents → encode as ASCII
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")
