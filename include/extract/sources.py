"""What each source is and how to read it.

Every object says which field tells us a record changed. The loader keeps the
highest value it has loaded (the watermark) and asks only for newer records next
time, so each run is incremental.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SourceObject:
    source: str          # stripe, hubspot, app_db, heap
    name: str            # customers, invoices, ...
    updated_field: str   # field that changes when a record changes

    @property
    def table(self) -> str:
        return f"{self.source}_{self.name}"


SOURCES: dict[str, list[SourceObject]] = {
    "stripe": [
        SourceObject("stripe", "customers", "updated"),
        SourceObject("stripe", "subscriptions", "updated"),
        SourceObject("stripe", "invoices", "updated"),
    ],
    "hubspot": [
        SourceObject("hubspot", "companies", "updatedAt"),
        SourceObject("hubspot", "deals", "updatedAt"),
    ],
    "app_db": [
        SourceObject("app_db", "accounts", "updated_at"),
        SourceObject("app_db", "prompt_runs", "updated_at"),
    ],
    "heap": [
        SourceObject("heap", "events", "time"),
    ],
}
