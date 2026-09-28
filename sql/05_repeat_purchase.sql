/*
==========================================================================
Business question:
  How loyal is the Olist customer base? What share of customers returned
  for a second or third purchase? This provides context for whether
  bad reviews are causing churn, and for the value of improving the
  delivery experience.

Output grain:
  Two result sets:
    Part A — one summary row: overall repeat purchase rate.
    Part B — one row per order-count bucket (1 order, 2 orders, 3+).

  Both are returned in a single UNION ALL query.

Key identity rule:
  customer_unique_id is used throughout — NOT customer_id.
  customer_id is order-scoped (a new one is issued per order for the
  same real person). Using customer_id would make every customer appear
  to have exactly 1 order, giving a false 0% repeat rate.
  See SCHEMA.md §5 and V2 (96,096 real customers vs 99,441 customer_ids).

Join-duplication risk and how it is handled:
  This query touches only orders and customers.
  orders has one row per order_id (no fan-out risk).
  customers has one row per customer_id; we bridge via customer_id to
  get customer_unique_id, then aggregate by customer_unique_id.
  No join to order_items, order_payments, or order_reviews — no
  multi-row-per-order tables are used, so no duplication risk.

Filter:
  Only delivered orders are counted as "purchases" for repeat-rate
  purposes. A cancelled or processing order should not count as a
  completed purchase that could trigger a return visit.
==========================================================================
*/

WITH
-- CTE 1: one row per (customer_unique_id, order_id) for delivered orders.
-- Bridge through customers to get the stable identity.
-- Grain: one row per delivered order, tagged with customer_unique_id.
customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id
    FROM orders o
    INNER JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),

-- CTE 2: count orders per real customer.
-- Grain: one row per customer_unique_id.
customer_order_counts AS (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS order_count
    FROM customer_orders
    GROUP BY customer_unique_id
),

-- CTE 3: assign bucket label.
-- Grain: one row per customer_unique_id.
customer_buckets AS (
    SELECT
        customer_unique_id,
        order_count,
        CASE
            WHEN order_count = 1 THEN '1_order'
            WHEN order_count = 2 THEN '2_orders'
            ELSE                      '3_or_more_orders'
        END AS bucket
    FROM customer_order_counts
),

-- CTE 4: summary stats for Part A.
summary AS (
    SELECT
        COUNT(*)                                                           AS total_customers,
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)                AS repeat_customers,
        ROUND(
            100.0 * SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(*), 0),
            2
        )                                                                  AS repeat_rate_pct,
        ROUND(AVG(order_count), 3)                                         AS avg_orders_per_customer,
        MAX(order_count)                                                    AS max_orders_by_one_customer
    FROM customer_order_counts
),

-- CTE 5: bucket counts for Part B.
bucket_counts AS (
    SELECT
        bucket,
        COUNT(*)                                                      AS customer_count,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)           AS pct_of_all_customers
    FROM customer_buckets
    GROUP BY bucket
)

-- Part A: overall summary (1 row)
SELECT
    1                        AS sort_order,
    'summary'                AS part,
    'repeat_rate'            AS metric,
    CAST(total_customers     AS VARCHAR) AS val_1,
    CAST(repeat_customers    AS VARCHAR) AS val_2,
    CAST(repeat_rate_pct     AS VARCHAR) AS val_3,
    CAST(avg_orders_per_customer AS VARCHAR) AS val_4,
    CAST(max_orders_by_one_customer AS VARCHAR) AS val_5
FROM summary

UNION ALL

-- Part B: bucket breakdown (3 rows)
SELECT
    2                        AS sort_order,
    'bucket_breakdown'       AS part,
    bucket                   AS metric,
    CAST(customer_count      AS VARCHAR) AS val_1,
    CAST(pct_of_all_customers AS VARCHAR) AS val_2,
    NULL, NULL, NULL
FROM bucket_counts

ORDER BY sort_order, metric;
