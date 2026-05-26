"""Stats route — returns aggregate counts from DB."""
from fastapi import APIRouter
from app.db import get_stats

router = APIRouter()


@router.get("/stats")
async def stats() -> dict:
    return get_stats()
