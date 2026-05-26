"""robots.txt-aware fetch guard (async-safe via thread executor)."""
import asyncio
import urllib.robotparser as rp
from functools import lru_cache
from urllib.parse import urlparse

from app.config import settings


@lru_cache(maxsize=256)
def _parser_for_sync(host: str) -> rp.RobotFileParser:
    parser = rp.RobotFileParser()
    parser.set_url(f"https://{host}/robots.txt")
    try:
        parser.read()
    except Exception:
        pass
    return parser


async def _parser_for(host: str) -> rp.RobotFileParser:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _parser_for_sync, host)


async def is_allowed(url: str) -> bool:
    """Async robots.txt check. Defaults to True if robots.txt is unreadable."""
    parsed = urlparse(url)
    if not parsed.netloc:
        return False
    parser = await _parser_for(parsed.netloc)
    try:
        return parser.can_fetch(settings.user_agent, url)
    except Exception:
        return True


def is_allowed_sync(url: str) -> bool:
    """Synchronous fallback for non-async contexts."""
    parsed = urlparse(url)
    if not parsed.netloc:
        return False
    parser = _parser_for_sync(parsed.netloc)
    try:
        return parser.can_fetch(settings.user_agent, url)
    except Exception:
        return True
