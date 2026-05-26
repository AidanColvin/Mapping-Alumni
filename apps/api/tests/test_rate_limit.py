import importlib

import pytest

import app.utils.rate_limit as rl
from app.config import settings


def _reset():
    """Clear rate limit state between tests."""
    rl._windows.clear()


def test_allows_under_limit():
    _reset()
    for _ in range(5):
        assert rl.allow("test_client") is True


def test_blocks_over_limit(monkeypatch):
    _reset()
    monkeypatch.setattr(settings, "rate_limit_per_min", 3)
    for _ in range(3):
        rl.allow("over_client")
    assert rl.allow("over_client") is False


def test_different_keys_are_independent(monkeypatch):
    _reset()
    monkeypatch.setattr(settings, "rate_limit_per_min", 1)
    rl.allow("client_a")
    assert rl.allow("client_a") is False
    assert rl.allow("client_b") is True


def test_remaining_decreases():
    _reset()
    initial = rl.remaining("rem_client")
    rl.allow("rem_client")
    assert rl.remaining("rem_client") == initial - 1
