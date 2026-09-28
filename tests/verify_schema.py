"""
tests/verify_schema.py
======================
Runs the verification queries documented in docs/SCHEMA.md (Verified Facts section)
and prints results to stdout. Also writes results to tests/_verify_schema_out.txt.

Run after build/load_data.py:
    python tests/verify_schema.py

Paste the output into the Verified Facts tables in docs/SCHEMA.md.
"""

import sys
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("ERROR: duckdb not installed. Run: pip install duckdb")

ROOT    = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "olist.duckdb"
OUT     = Path(__file__).resolve().parent / "_verify_schema_out.txt"

if not DB_PATH.exists():
    sys.exit("DB_NOT_FOUND — run build/load_data.py first")

con = duckdb.connect(str(DB_PATH), read_only=True)

QUERIES = [
    (
        "V1 — order_reviews key uniqueness",
        """
        SELECT COUNT(*)                  AS rows,
               COUNT(DISTINCT review_id) AS uniq_review_id,
               COUNT(DISTINCT order_id)  AS uniq_order_id
        FROM order_reviews
        """,
    ),
    (
        "V1b — review_id duplicates (rows where review_id appears more than once)",
        """
        SELECT COUNT(*) AS review_id_dupe_count
        FROM (
            SELECT review_id
            FROM order_reviews
            GROUP BY review_id
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "V1c — order_id duplicates (orders with more than one review row)",
        """
        SELECT COUNT(*) AS orders_with_multiple_reviews
        FROM (
            SELECT order_id
            FROM order_reviews
            GROUP BY order_id
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "V2 — customers identity split",
        """
        SELECT COUNT(*)                           AS rows,
               COUNT(DISTINCT customer_id)        AS uniq_customer_id,
               COUNT(DISTINCT customer_unique_id) AS uniq_people
        FROM customers
        """,
    ),
    (
        "V3 — delivered orders with missing delivery timestamp",
        """
        SELECT COUNT(*) AS count
        FROM orders
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
        """,
    ),
    (
        "V4a — customer zip prefix shorter than 5 chars",
        """
        SELECT COUNT(*) AS short_zips
        FROM customers
        WHERE LENGTH(customer_zip_code_prefix) < 5
        """,
    ),
    (
        "V4b — seller zip prefix shorter than 5 chars",
        """
        SELECT COUNT(*) AS short_zips
        FROM sellers
        WHERE LENGTH(seller_zip_code_prefix) < 5
        """,
    ),
    (
        "V4c — geolocation zip prefix shorter than 5 chars",
        """
        SELECT COUNT(*) AS short_zips
        FROM geolocation
        WHERE LENGTH(geolocation_zip_code_prefix) < 5
        """,
    ),
    (
        "V4d — zip prefix data type",
        """
        SELECT typeof(customer_zip_code_prefix) AS zip_type
        FROM customers LIMIT 1
        """,
    ),
    (
        "V5a — products without an English category name",
        """
        SELECT COUNT(*) AS null_english
        FROM products
        WHERE product_category_name_english IS NULL
        """,
    ),
    (
        "V5b — products without a Portuguese category name",
        """
        SELECT COUNT(*) AS null_portuguese
        FROM products
        WHERE product_category_name IS NULL
        """,
    ),
    (
        "V6 — geolocation grain (rows vs distinct prefixes)",
        """
        SELECT COUNT(*)                                    AS total_rows,
               COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_prefixes
        FROM geolocation
        """,
    ),
]

output_lines = []

def emit(s=""):
    print(s, flush=True)
    output_lines.append(str(s))

emit("=" * 60)
emit("Olist Post-Mortem — Schema verification")
emit(f"Database: {DB_PATH}")
emit("=" * 60)

for label, sql in QUERIES:
    try:
        result = con.execute(sql.strip()).fetchall()
        cols = [d[0] for d in con.description]
        emit(f"\n-- {label}")
        emit("  " + " | ".join(cols))
        for row in result:
            emit("  " + " | ".join(str(v) for v in row))
    except Exception as e:
        emit(f"\n-- {label}  ERROR: {e}")

con.close()
emit("\nDone.")

OUT.write_text("\n".join(output_lines), encoding="utf-8")
