from __future__ import annotations

from datetime import datetime, timedelta
import os
from typing import Callable, Dict, List, Optional

from flask import Flask, jsonify
from dotenv import load_dotenv
from flask_cors import CORS

from mediathek import fetch_mediathek_items


class SimpleCache:
    def __init__(self, ttl_seconds: int = 300) -> None:
        self.ttl_seconds = ttl_seconds
        self._store: Dict[str, Dict[str, object]] = {}

    def get(self, key: str) -> Optional[object]:
        entry = self._store.get(key)
        if not entry:
            return None
        expires_at = entry["expires_at"]
        if datetime.utcnow() >= expires_at:
            self._store.pop(key, None)
            return None
        return entry["value"]

    def set(self, key: str, value: object) -> None:
        self._store[key] = {
            "value": value,
            "expires_at": datetime.utcnow() + timedelta(seconds=self.ttl_seconds),
        }


def _parse_date(date_str: str) -> Optional[datetime.date]:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except (TypeError, ValueError):
        return None


def _group_week(items: List[dict], today: datetime.date) -> List[dict]:
    min_date = today - timedelta(days=6)
    grouped: Dict[str, List[dict]] = {}
    for item in items:
        item_date = _parse_date(item.get("date"))
        if not item_date:
            continue
        if item_date < min_date or item_date > today:
            continue
        grouped.setdefault(item["date"], []).append(item)

    output = []
    for date_key in sorted(grouped.keys(), reverse=True):
        output.append({"date": date_key, "items": grouped[date_key]})
    return output


def _read_ttl() -> int:
    value = os.getenv("CACHE_TTL_SECONDS", "300")
    try:
        return max(30, int(value))
    except ValueError:
        return 300


def create_app(fetcher: Callable[[], List[dict]] = fetch_mediathek_items) -> Flask:
    load_dotenv()
    app = Flask(__name__)
    CORS(app)
    cache = SimpleCache(ttl_seconds=_read_ttl())

    @app.errorhandler(Exception)
    def handle_exception(error: Exception):  # type: ignore[override]
        return jsonify({"error": "internal_error", "message": str(error)}), 500

    @app.get("/health")
    def health() -> object:
        return jsonify({"ok": True})

    @app.get("/mediathek/today")
    def mediathek_today() -> object:
        cached = cache.get("today")
        if cached is not None:
            return jsonify(cached)

        try:
            items = fetcher()
            today = datetime.now().date()
            today_items = [item for item in items if _parse_date(item.get("date")) == today]
            cache.set("today", today_items)
            return jsonify(today_items)
        except Exception:
            return jsonify([]), 200

    @app.get("/mediathek/week")
    def mediathek_week() -> object:
        cached = cache.get("week")
        if cached is not None:
            return jsonify(cached)

        try:
            items = fetcher()
            today = datetime.now().date()
            week_items = _group_week(items, today)
            cache.set("week", week_items)
            return jsonify(week_items)
        except Exception:
            return jsonify([]), 200

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=5000)
