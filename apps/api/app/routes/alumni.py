from fastapi import APIRouter, HTTPException

from app.adapters import wikipedia

router = APIRouter(prefix="/api/alumni", tags=["alumni"])


@router.get("/{wikidata_qid}")
async def get_alumnus(wikidata_qid: str) -> dict:
    """Return a brief bio for a person by their Wikidata QID."""
    # Resolve the QID to a Wikipedia article title first
    title = await wikipedia.resolve_title_from_qid(wikidata_qid)
    if not title:
        raise HTTPException(status_code=404, detail="No Wikipedia article found for this person")

    summary = await wikipedia.fetch_summary(title)
    if not summary:
        raise HTTPException(status_code=404, detail="Wikipedia summary not available")
    return summary
