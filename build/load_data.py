"""
build/load_data.py
==================
Loads the 9 Olist Brazilian E-Commerce CSVs into a local DuckDB database
(data/olist.duckdb). Run this once before any analysis.

What this script does, step by step:
  1. Reads each CSV from /data using DuckDB's native CSV reader.
  2. For columns where inference might produce the wrong type, explicit types are
     passed via the SQL 'types' parameter — applied at parse time, before DuckDB
     tokenises cell values, so no leading zeros can be lost and no timestamp can
     be misread as VARCHAR.
     NOTE: DuckDB 1.5.6 infers zip prefixes as VARCHAR and timestamps as TIMESTAMP
     correctly without help, but the explicit overrides are kept as a forward-
     compatible safety net in case behaviour changes across DuckDB versions.
  3. Logs the row count of every table so you can spot loading problems immediately.
  4. Creates an enriched `products` view joining in English category names.
  5. Logs row counts before and after every join to catch grain surprises.

Usage:
    python build/load_data.py

Requirements:
    pip install duckdb
"""

import sys
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("ERROR: duckdb is not installed. Run: pip install duckdb")

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT     = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
DB_PATH  = DATA_DIR / "olist.duckdb"

# ---------------------------------------------------------------------------
# CSV → table manifest
#
# Each entry: (csv_filename, table_name, type_overrides_dict)
#
# type_overrides_dict maps column_name → DuckDB type string.
# Passed as the 'types' parameter to read_csv_auto — DuckDB infers all columns,
# then overrides only the named ones. Does NOT require listing every column.
# ---------------------------------------------------------------------------
TABLES = [
    (
        "olist_orders_dataset.csv",
        "orders",
        {
            "order_purchase_timestamp":       "TIMESTAMP",
            "order_approved_at":              "TIMESTAMP",
            "order_delivered_carrier_date":   "TIMESTAMP",
            "order_delivered_customer_date":  "TIMESTAMP",
            "order_estimated_delivery_date":  "TIMESTAMP",
        },
    ),
    (
        "olist_order_items_dataset.csv",
        "order_items",
        {
            "shipping_limit_date": "TIMESTAMP",
        },
    ),
    (
        "olist_order_payments_dataset.csv",
        "order_payments",
        {},
    ),
    (
        "olist_order_reviews_dataset.csv",
        "order_reviews",
        {
            "review_creation_date":    "TIMESTAMP",
            "review_answer_timestamp": "TIMESTAMP",
        },
    ),
    (
        "olist_customers_dataset.csv",
        "customers",
        {
            # DuckDB 1.5.6 infers this as VARCHAR already, but we pin it
            # explicitly to guard against version-dependent inference changes.
            "customer_zip_code_prefix": "VARCHAR",
        },
    ),
    (
        "olist_sellers_dataset.csv",
        "sellers",
        {
            "seller_zip_code_prefix": "VARCHAR",
        },
    ),
    (
        "olist_products_dataset.csv",
        "products_raw",
        {},
    ),
    (
        "olist_geolocation_dataset.csv",
        "geolocation",
        {
            "geolocation_zip_code_prefix": "VARCHAR",
        },
    ),
    (
        "product_category_name_translation.csv",
        "category_translation",
        {},
    ),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    print(msg, flush=True)


def row_count(con: duckdb.DuckDBPyConnection, table: str) -> int:
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def build_types_sql(type_overrides: dict) -> str:
    """
    Build a SQL struct literal for the read_csv_auto 'types' parameter.
    Example: {'customer_zip_code_prefix': 'VARCHAR', 'order_approved_at': 'TIMESTAMP'}
    """
    if not type_overrides:
        return ""
    parts = [f"'{col}': '{typ}'" for col, typ in type_overrides.items()]
    return "{" + ", ".join(parts) + "}"


def load_table(
    con: duckdb.DuckDBPyConnection,
    csv_path: Path,
    table_name: str,
    type_overrides: dict,
) -> int:
    """
    Read a CSV into a DuckDB table using read_csv_auto with optional type overrides.
    The 'types' parameter applies overrides at parse time, before cell values are
    interpreted, so leading zeros and timestamp formats are never lost.
    Returns the number of rows loaded.
    """
    if not csv_path.exists():
        log(f"  [SKIP] {csv_path.name} not found — table '{table_name}' not created.")
        return 0

    path_str = str(csv_path).replace("\\", "/")
    types_sql = build_types_sql(type_overrides)

    if types_sql:
        sql = (
            f"CREATE OR REPLACE TABLE {table_name} AS "
            f"SELECT * FROM read_csv_auto('{path_str}', "
            f"header=True, types={types_sql})"
        )
    else:
        sql = (
            f"CREATE OR REPLACE TABLE {table_name} AS "
            f"SELECT * FROM read_csv_auto('{path_str}', header=True)"
        )

    con.execute(sql)
    n = row_count(con, table_name)
    log(f"  [{table_name:<35}] loaded {n:>10,} rows  ✓")
    return n


def create_products_enriched(con: duckdb.DuckDBPyConnection) -> None:
    """
    Create a `products` view: products_raw LEFT JOIN category_translation.

    Grain check:
      products_raw        → one row per product_id (PK)
      category_translation → one row per product_category_name (PK)
      Result grain: one row per product_id — no duplication risk.
    """
    raw_rows   = row_count(con, "products_raw")
    trans_rows = row_count(con, "category_translation")
    log(f"\n  [products_raw]         before join: {raw_rows:>10,} rows")
    log(f"  [category_translation] before join: {trans_rows:>10,} rows")

    con.execute("DROP VIEW IF EXISTS products")
    con.execute("""
        CREATE VIEW products AS
        -- Grain: one row per product_id (preserved from products_raw).
        -- LEFT JOIN so products with no translation still appear.
        SELECT
            p.product_id,
            p.product_category_name,
            t.product_category_name_english,
            p.product_name_lenght,
            p.product_description_lenght,
            p.product_photos_qty,
            p.product_weight_g,
            p.product_length_cm,
            p.product_height_cm,
            p.product_width_cm
        FROM products_raw p
        LEFT JOIN category_translation t
            ON p.product_category_name = t.product_category_name
    """)

    joined_rows = row_count(con, "products")
    log(f"  [products view]        after join:  {joined_rows:>10,} rows")

    if joined_rows != raw_rows:
        log(
            f"  ⚠  WARNING: row count changed after join "
            f"({raw_rows:,} → {joined_rows:,}). "
            f"Investigate category_translation for duplicate category keys."
        )
    else:
        log(f"  [products view]        row count stable — no duplication ✓")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    log("=" * 60)
    log("Olist Post-Mortem — DuckDB loader")
    log(f"Database : {DB_PATH}")
    log(f"Data dir : {DATA_DIR}")
    log("=" * 60)

    if DB_PATH.exists():
        DB_PATH.unlink()
        log(f"\n  Removed existing {DB_PATH.name} — starting fresh.")

    con = duckdb.connect(str(DB_PATH))
    results = {}

    log("\n── Loading CSVs ──────────────────────────────────────────")
    for csv_name, table_name, type_overrides in TABLES:
        csv_path = DATA_DIR / csv_name
        n = load_table(con, csv_path, table_name, type_overrides)
        results[table_name] = n

    log("\n── Enriched products view ────────────────────────────────")
    existing = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
    if "products_raw" in existing and "category_translation" in existing:
        create_products_enriched(con)
    else:
        log("  [SKIP] products_raw or category_translation missing — skipping view.")

    total_tables = sum(1 for n in results.values() if n > 0)
    total_rows   = sum(results.values())

    log("\n── Summary ───────────────────────────────────────────────")
    log(f"  Tables loaded : {total_tables}")
    log(f"  Total rows    : {total_rows:,}")
    log("\n  Final row counts (all tables including view):")
    for tbl in con.execute("SHOW TABLES").fetchall():
        tbl_name = tbl[0]
        n = row_count(con, tbl_name)
        log(f"    {tbl_name:<40} {n:>10,}")

    con.close()
    log(f"\nDone. Database written to {DB_PATH}")
    log("=" * 60)


if __name__ == "__main__":
    main()
