"""
tests/sanity_checks.py
======================
Sanity checks that cross-verify SQL query outputs against direct database
queries. Each check prints PASS or FAIL with actual numbers.

If a check fails, the SQL file is wrong — fix the SQL, not this test.

Run:
    python tests/sanity_checks.py

Requires:
    - data/olist.duckdb to exist (run build/load_data.py first)
    - All SQL files in /sql to have been run (exports/ populated)
"""

import sys
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("ERROR: duckdb not installed. Run: pip install duckdb")

ROOT    = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "olist.duckdb"
SQL_DIR = ROOT / "sql"

if not DB_PATH.exists():
    sys.exit("ERROR: database not found — run build/load_data.py first")

con = duckdb.connect(str(DB_PATH), read_only=True)

results = []
all_passed = True


def check(name: str, passed: bool, detail: str) -> None:
    global all_passed
    status = "PASS" if passed else "FAIL"
    if not passed:
        all_passed = False
    line = f"  [{status}] {name}\n         {detail}"
    results.append(line)
    print(line, flush=True)


def run_sql(path: Path):
    """Execute a SQL file and return (cols, rows)."""
    sql = path.read_text(encoding="utf-8")
    rel = con.execute(sql)
    cols = [d[0] for d in rel.description]
    rows = rel.fetchall()
    return cols, rows


print("=" * 65)
print("Olist Post-Mortem — Sanity checks")
print(f"Database: {DB_PATH}")
print("=" * 65)

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 1
# Revenue in 01_monthly_revenue.sql summed equals SUM(price) on order_items
# for delivered orders.
# ─────────────────────────────────────────────────────────────────────────────
print("\nCheck 1: Revenue total — query 01 vs direct SUM(price)")

direct_revenue = con.execute("""
    SELECT SUM(oi.price)
    FROM order_items oi
    INNER JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
""").fetchone()[0]

_, rows01 = run_sql(SQL_DIR / "01_monthly_revenue.sql")
# revenue_brl is column index 2
query_revenue = sum(r[2] for r in rows01 if r[2] is not None)

diff = abs(direct_revenue - query_revenue)
check(
    "01 monthly revenue total matches direct SUM(price) on delivered order_items",
    passed = diff < 0.01,
    detail = (f"direct={direct_revenue:,.4f}  query_sum={query_revenue:,.4f}  "
              f"diff={diff:,.4f}  {'OK' if diff < 0.01 else 'MISMATCH'}")
)

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 2
# No duplicate order_id in any order-level output.
# Checks: 02_delay_vs_review (order_count per bucket should sum to total
# delivered orders with non-null dates), 07 part A order counts should
# also sum to that same total.
# More precisely: verify the outputs themselves don't double-count by
# checking the sum of order_count across buckets equals our baseline.
# ─────────────────────────────────────────────────────────────────────────────
print("\nCheck 2: No duplicate order_id in order-level outputs")

baseline_delivered = con.execute("""
    SELECT COUNT(*)
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
""").fetchone()[0]

# Query 02: sum of order_count across all buckets
_, rows02 = run_sql(SQL_DIR / "02_delay_vs_review.sql")
# Columns: bucket_sort, delay_bucket, order_count, avg_review_score, pct_low_review, orders_without_review
sum02 = sum(r[2] for r in rows02)

check(
    "02 delay buckets: sum of order_count equals delivered orders with non-null dates",
    passed = sum02 == baseline_delivered,
    detail = (f"sum_of_bucket_order_counts={sum02:,}  "
              f"baseline_delivered_non_null={baseline_delivered:,}  "
              f"diff={sum02 - baseline_delivered:,}")
)

# Query 07: sum of order_count across late + on_time (Part A rows only)
_, rows07 = run_sql(SQL_DIR / "07_late_delivery_attribution.sql")
# Columns: sort_order, part, delivery_status, col1, col2, col3, col4, col5
# Part A rows have sort_order=1
part_a_rows = [r for r in rows07 if r[0] == 1]
sum07 = sum(int(r[3]) for r in part_a_rows)  # col1 = order_count

check(
    "07 attribution: late + on_time order counts equal delivered orders with non-null dates",
    passed = sum07 == baseline_delivered,
    detail = (f"late+ontime={sum07:,}  "
              f"baseline_delivered_non_null={baseline_delivered:,}  "
              f"diff={sum07 - baseline_delivered:,}")
)

# Query 08: late_order_count + ontime_order_count
_, rows08 = run_sql(SQL_DIR / "08_excess_bad_reviews.sql")
# late_order_count is col 0, ontime_order_count is col 1
sum08 = int(rows08[0][0]) + int(rows08[0][1])

check(
    "08 excess bad reviews: late + ontime order counts equal delivered orders with non-null dates",
    passed = sum08 == baseline_delivered,
    detail = (f"late+ontime={sum08:,}  "
              f"baseline_delivered_non_null={baseline_delivered:,}  "
              f"diff={sum08 - baseline_delivered:,}")
)

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 3
# In query 07:
#   (a) late + on_time order counts = delivered orders with non-null delivery date
#       (already done above as part of Check 2)
#   (b) with-review counts = delivered orders with non-null delivery date
#       that have at least one review
# ─────────────────────────────────────────────────────────────────────────────
print("\nCheck 3: Query 07 with-review counts match database")

baseline_with_review = con.execute("""
    SELECT COUNT(DISTINCT o.order_id)
    FROM orders o
    INNER JOIN order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
""").fetchone()[0]

# col2 = orders_with_review for Part A rows
sum07_with_review = sum(int(r[4]) for r in part_a_rows)

check(
    "07 attribution: sum of with-review counts = delivered+non-null+has-review",
    passed = sum07_with_review == baseline_with_review,
    detail = (f"query_sum_with_review={sum07_with_review:,}  "
              f"baseline={baseline_with_review:,}  "
              f"diff={sum07_with_review - baseline_with_review:,}")
)

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 4
# Cohort sizes in 06 (before the minimum-size filter) summed = total customers
# in 05 (93,358 delivered-only customers).
#
# Query 06 applies a >= 100 cohort size filter in its output. To check the
# unfiltered total, we recompute cohort sizes directly from the database.
# ─────────────────────────────────────────────────────────────────────────────
print("\nCheck 4: Cohort sizes (unfiltered) sum = customers in 05")

# Ground truth from 05: total_customers column (val_1 of the summary row)
_, rows05 = run_sql(SQL_DIR / "05_repeat_purchase.sql")
# Row with metric='repeat_rate' has val_1 = total_customers
summary_row = next(r for r in rows05 if r[2] == 'repeat_rate')
total_customers_05 = int(summary_row[3])  # val_1

# Recompute cohort sizes directly — no size filter
unfiltered_cohort_total = con.execute("""
    SELECT COUNT(DISTINCT c.customer_unique_id)
    FROM orders o
    INNER JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
""").fetchone()[0]

check(
    "Unfiltered cohort total (all delivered customers) = total_customers in 05",
    passed = unfiltered_cohort_total == total_customers_05,
    detail = (f"unfiltered_cohort_total={unfiltered_cohort_total:,}  "
              f"query05_total_customers={total_customers_05:,}  "
              f"diff={unfiltered_cohort_total - total_customers_05:,}")
)

# Calculate excluded cohorts (before 2017-01-01)
excluded_cohort_total = con.execute("""
    WITH first_purchase AS (
        SELECT c.customer_unique_id, MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) AS cohort_month
        FROM orders o
        INNER JOIN customers c ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    )
    SELECT COUNT(*) FROM first_purchase WHERE cohort_month < '2017-01-01'
""").fetchone()[0]

# Verify the filtered 06 output is exactly unfiltered minus excluded
_, rows06 = run_sql(SQL_DIR / "06_cohort_retention.sql")
# cohort_size is column index 1
filtered_cohort_total = sum(r[1] for r in rows06)

expected_filtered = unfiltered_cohort_total - excluded_cohort_total

check(
    "Filtered cohort total = unfiltered total minus excluded cohorts",
    passed = filtered_cohort_total == expected_filtered,
    detail = (f"filtered_cohort_total={filtered_cohort_total:,}  "
              f"expected_filtered={expected_filtered:,}  "
              f"(unfiltered {unfiltered_cohort_total:,} - excluded {excluded_cohort_total:,})")
)

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "=" * 65)
if all_passed:
    print("  ALL CHECKS PASSED")
else:
    print("  ONE OR MORE CHECKS FAILED — fix the SQL, not this test")
print("=" * 65)

con.close()
