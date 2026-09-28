/*
==========================================================================
Business question:
  Of customers who first purchased in a given month, what fraction came
  back in each subsequent month? This shows whether Olist retains
  customers over time, and whether cohorts are improving or worsening.

Output grain:
  One row per cohort_month (cohorts with >= 100 customers only).
  Columns month_0 through month_11 contain the retention % for that
  cohort at that offset.

  NULL vs 0% distinction — important:
    0.0  = the month is within the dataset window AND no cohort member
           returned. Genuinely zero retention.
    NULL = the month falls beyond 2018-08-01 (the last observed order
           month in the dataset). We have no data for it — we cannot
           distinguish "zero returners" from "data not yet collected."
    Only NULL means "unknown." 0.0 means "observed zero."

  The dataset's last order month is 2018-08-01. Any cohort-offset
  combination where cohort_month + offset months > 2018-08-01 is NULL.

Cohort time filter — 2017-01 onward:
  Cohorts from 2016 (Sep, Oct, Dec) are unrepresentative and too small.
  For example, Sep and Dec 2016 have 1 customer each. Oct 2016 has ~300
  but is separated by a gap before continuous operations began in 2017.
  We filter to cohorts from 2017-01 onward to ensure a continuous,
  stable cohort analysis of Olist's mature operating period.

Cohort definition:
  cohort_month = DATE_TRUNC('month', first delivered purchase)
  per customer_unique_id. Only delivered orders count.

Retention definition:
  A customer is "active" in a given month if they placed at least one
  delivered order in that month. Month-0 is always 100%.

Key identity rule:
  customer_unique_id used throughout (not customer_id).

Join-duplication risk:
  orders → customers only. No order_items join. No fan-out risk.
==========================================================================
*/

WITH
-- CTE 1: delivered orders with customer identity and purchase month.
-- Grain: one row per (customer_unique_id, order_month).
-- Multiple orders in the same month collapse to one row via DISTINCT.
delivered_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM orders o
    INNER JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),

-- CTE 2: first purchase month per customer — defines the cohort.
-- Grain: one row per customer_unique_id.
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY customer_unique_id
),

-- CTE 3: cohort sizes. Filter to 2017-01 onward.
-- Cohorts from 2016 (Sep, Dec) are unrepresentative and too small (1 customer each).
-- We keep all cohorts from 2017-01 onward for a continuous, stable cohort analysis.
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM first_purchase
    WHERE cohort_month >= '2017-01-01'
    GROUP BY cohort_month
),

-- CTE 4: tag every purchase with cohort and offset.
-- Only for customers whose cohort survived the size filter.
-- Grain: one row per (customer_unique_id, order_month).
customer_activity AS (
    SELECT
        fp.cohort_month,
        d.customer_unique_id,
        DATE_DIFF('month', fp.cohort_month, d.order_month) AS months_since_first
    FROM delivered_orders d
    INNER JOIN first_purchase fp
        ON fp.customer_unique_id = d.customer_unique_id
    INNER JOIN cohort_sizes cs
        ON cs.cohort_month = fp.cohort_month  -- restrict to qualifying cohorts
),

-- CTE 5: active customer count per (cohort, offset).
-- Grain: one row per (cohort_month, months_since_first).
retention_counts AS (
    SELECT
        cohort_month,
        months_since_first,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, months_since_first
),

-- CTE 6: the maximum observable offset for each cohort.
-- cohort_month + N months <= 2018-08-01  →  N <= DATE_DIFF(cohort, last_month)
-- Any column beyond this offset must be NULL (beyond dataset window).
-- Any column at or within this offset that has no returners must be 0.0.
dataset_window AS (
    SELECT DATE '2018-08-01' AS last_month
)

-- Final pivot: one row per cohort, 12 month columns.
-- Logic per cell:
--   IF offset > max_observable_offset  → NULL  (beyond window, unknown)
--   ELSE COALESCE(active / size * 100, 0.0)    (observed; 0 if no returners)
SELECT
    cs.cohort_month,
    cs.cohort_size,
    DATE_DIFF('month', cs.cohort_month, dw.last_month) AS max_observable_offset,

    -- month_0: always 100 (every customer active in cohort month)
    CASE WHEN 0  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 0  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_0,

    CASE WHEN 1  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 1  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_1,

    CASE WHEN 2  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 2  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_2,

    CASE WHEN 3  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 3  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_3,

    CASE WHEN 4  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 4  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_4,

    CASE WHEN 5  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 5  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_5,

    CASE WHEN 6  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 6  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_6,

    CASE WHEN 7  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 7  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_7,

    CASE WHEN 8  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 8  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_8,

    CASE WHEN 9  <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 9  THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_9,

    CASE WHEN 10 <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 10 THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_10,

    CASE WHEN 11 <= DATE_DIFF('month', cs.cohort_month, dw.last_month)
         THEN ROUND(100.0 * COALESCE(MAX(CASE WHEN rc.months_since_first = 11 THEN rc.active_customers END), 0) / cs.cohort_size, 1)
         END AS month_11

FROM cohort_sizes cs
CROSS JOIN dataset_window dw
LEFT JOIN retention_counts rc ON rc.cohort_month = cs.cohort_month
GROUP BY cs.cohort_month, cs.cohort_size, dw.last_month
ORDER BY cs.cohort_month;
