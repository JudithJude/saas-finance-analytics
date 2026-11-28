"""Remove personal fields from the raw Stripe records of customers who asked to be forgotten.

dbt already hides their personal data from every model (see stg_stripe__customers).
This step also strips it from the raw layer, so it isn't sitting in the warehouse at all.
Financial fields (ids, currency, invoices) are kept, because finance must keep invoices
for the legal retention period.

Run it after every extract: if the customer still exists in Stripe, the next load
brings the fields back, so the request must also be handled in Stripe itself.

    python -m include.privacy.erase_raw
"""

from __future__ import annotations

import csv
import logging
from pathlib import Path

from include.extract.load import connect

log = logging.getLogger(__name__)

ERASURES = Path(__file__).resolve().parents[2] / "dbt" / "seeds" / "privacy_erasures.csv"
PERSONAL_FIELDS = ["name", "email", "phone", "address", "shipping"]


def erasure_ids(path: Path = ERASURES) -> list[str]:
    with path.open(newline="") as f:
        return [row["customer_id"] for row in csv.DictReader(f) if row.get("customer_id")]


def erase(conn, ids: list[str]) -> int:
    if not ids:
        return 0
    with conn.cursor() as cur:
        cur.execute(
            "update raw.stripe_customers set record = record - %s::text[] "
            "where id = any(%s) and record ?| %s::text[]",
            (PERSONAL_FIELDS, ids, PERSONAL_FIELDS),
        )
        changed = cur.rowcount
    conn.commit()
    return changed


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    ids = erasure_ids()
    with connect() as conn:
        changed = erase(conn, ids)
    log.info("Erasure list has %d customers; removed personal fields from %d raw records", len(ids), changed)


if __name__ == "__main__":
    main()
