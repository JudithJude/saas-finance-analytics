"""Load records into the warehouse's raw schema, untouched.

Each raw table keeps the full record as JSON, plus when it changed and when we
loaded it. Records are upserted on id, so a record sent twice is stored once.
A watermark table remembers how far each object has been loaded.
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime

import psycopg2
from psycopg2.extras import execute_values

from include.extract.clients import get_client, parse_ts
from include.extract.sources import SOURCES, SourceObject

log = logging.getLogger(__name__)


def connect():
    return psycopg2.connect(
        host=os.getenv("WAREHOUSE_HOST", "localhost"),
        port=int(os.getenv("WAREHOUSE_PORT", "5432")),
        dbname=os.getenv("WAREHOUSE_DB", "warehouse"),
        user=os.getenv("WAREHOUSE_USER", "postgres"),
        password=os.getenv("WAREHOUSE_PASSWORD", "postgres"),
    )


def ensure_tables(cur, obj: SourceObject) -> None:
    cur.execute("create schema if not exists raw")
    cur.execute(
        """create table if not exists raw._watermarks (
               table_name text primary key,
               last_updated_at timestamptz not null,
               loaded_at timestamptz not null default now())"""
    )
    cur.execute(
        f"""create table if not exists raw.{obj.table} (
                id text primary key,
                record jsonb not null,
                updated_at timestamptz not null,
                _loaded_at timestamptz not null default now())"""
    )


def get_watermark(cur, obj: SourceObject) -> datetime | None:
    cur.execute("select last_updated_at from raw._watermarks where table_name = %s", (obj.table,))
    row = cur.fetchone()
    return row[0] if row else None


def load_object(conn, obj: SourceObject) -> int:
    with conn.cursor() as cur:
        ensure_tables(cur, obj)
        since = get_watermark(cur, obj)
        total, newest = 0, since
        for page in get_client(obj).fetch(obj, since):
            rows = [(r["id"], json.dumps(r), parse_ts(r[obj.updated_field])) for r in page]
            execute_values(
                cur,
                f"""insert into raw.{obj.table} (id, record, updated_at) values %s
                    on conflict (id) do update
                    set record = excluded.record, updated_at = excluded.updated_at, _loaded_at = now()""",
                rows,
            )
            total += len(rows)
            page_max = max(r[2] for r in rows)
            newest = page_max if newest is None else max(newest, page_max)
        if newest is not None:
            cur.execute(
                """insert into raw._watermarks (table_name, last_updated_at) values (%s, %s)
                   on conflict (table_name) do update
                   set last_updated_at = excluded.last_updated_at, loaded_at = now()""",
                (obj.table, newest),
            )
    conn.commit()
    log.info("Loaded %s rows into raw.%s (watermark %s)", total, obj.table, newest)
    return total


def run(source: str) -> dict[str, int]:
    """Extract and load every object of one source. Used by the DAGs and the CLI."""
    conn = connect()
    try:
        return {obj.table: load_object(conn, obj) for obj in SOURCES[source]}
    finally:
        conn.close()
