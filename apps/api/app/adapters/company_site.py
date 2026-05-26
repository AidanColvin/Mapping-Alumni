"""Parse public company leadership/about pages."""
from bs4 import BeautifulSoup

from app.adapters.public_web import fetch_text


async def parse_leadership(url: str) -> list[dict]:
    """Extract heuristic name+title pairs from a public leadership page."""
    html = await fetch_text(url)
    if not html:
        return []
    soup = BeautifulSoup(html, "lxml")
    people: list[dict] = []
    for h in soup.find_all(["h2", "h3", "h4"]):
        name = h.get_text(strip=True)
        nxt = h.find_next(["p", "span", "div"])
        title = nxt.get_text(strip=True) if nxt else ""
        if name and 2 < len(name) < 80:
            people.append({"name": name, "title": title[:120], "source_url": url})
    return people
