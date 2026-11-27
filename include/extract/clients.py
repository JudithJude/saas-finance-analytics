"""API clients.

`FakeClient` reads the files made by `include/generate_fake_data.py` and behaves
like a paginated API. `StripeClient` shows what the real call looks like. Set
USE_FAKE_API=false and STRIPE_API_KEY to use it. HubSpot, the app database and
Heap would follow the same pattern: one class, one `fetch` method.
"""

from __future__ import annotations

import json
import os
from collections.abc import Iterator
from datetime import datetime, timezone
from pathlib import Path

import requests

from include.extract.sources import SourceObject

FAKE_DIR = Path(__file__).resolve().parents[2] / "data" / "fake_api"
PAGE_SIZE = 100


def parse_ts(value: str) -> datetime:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


class FakeClient:
    """Reads local JSON and returns records changed after the watermark, in pages."""

    def fetch(self, obj: SourceObject, since: datetime | None) -> Iterator[list[dict]]:
        rows = json.loads((FAKE_DIR / f"{obj.table}.json").read_text())
        rows = [r for r in rows if since is None or parse_ts(r[obj.updated_field]) > since]
        rows.sort(key=lambda r: r[obj.updated_field])
        for i in range(0, len(rows), PAGE_SIZE):
            yield rows[i : i + PAGE_SIZE]


class StripeClient:
    """The real Stripe list API, paginated with `starting_after`."""

    BASE = "https://api.stripe.com/v1"

    def __init__(self, api_key: str):
        self.session = requests.Session()
        self.session.auth = (api_key, "")

    def fetch(self, obj: SourceObject, since: datetime | None) -> Iterator[list[dict]]:
        params: dict = {"limit": PAGE_SIZE}
        if since is not None:
            # Stripe filters list endpoints on `created`; changed records are
            # caught by re-reading a short lookback window in practice.
            params["created[gte]"] = int(since.timestamp())
        while True:
            resp = self.session.get(f"{self.BASE}/{obj.name}", params=params, timeout=30)
            resp.raise_for_status()
            body = resp.json()
            page = body["data"]
            if page:
                yield page
            if not body.get("has_more"):
                break
            params["starting_after"] = page[-1]["id"]


def get_client(obj: SourceObject):
    if os.getenv("USE_FAKE_API", "true").lower() == "true":
        return FakeClient()
    if obj.source == "stripe":
        return StripeClient(os.environ["STRIPE_API_KEY"])
    raise NotImplementedError(f"No real client for {obj.source} yet. Set USE_FAKE_API=true.")
