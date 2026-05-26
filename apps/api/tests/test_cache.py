import json
import time
from pathlib import Path

import pytest

import app.utils.cache as cache_module


def test_put_and_get(tmp_path, monkeypatch):
    monkeypatch.setattr(cache_module, "_key_path", lambda key: tmp_path / f"{abs(hash(key))}.json")
    monkeypatch.setattr("app.config.settings.cache_ttl_hours", 24)

    cache_module.put("mykey", {"x": 1})
    result = cache_module.get("mykey")
    assert result == {"x": 1}


def test_expired_returns_none(tmp_path, monkeypatch):
    monkeypatch.setattr(cache_module, "_key_path", lambda key: tmp_path / f"{abs(hash(key))}.json")
    monkeypatch.setattr("app.config.settings.cache_ttl_hours", 0)

    # Write with a timestamp in the past
    path = tmp_path / "old.json"
    path.write_text(json.dumps({"ts": time.time() - 3601, "value": {"y": 2}}))
    monkeypatch.setattr(cache_module, "_key_path", lambda key: path)

    result = cache_module.get("any")
    assert result is None


def test_missing_key_returns_none(tmp_path, monkeypatch):
    monkeypatch.setattr(cache_module, "_key_path", lambda key: tmp_path / "nonexistent_xyz.json")
    assert cache_module.get("nonexistent") is None
