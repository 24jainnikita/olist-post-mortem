/*
==========================================================================
Business question:
  How did Olist's revenue trend month-over-month, and are there seasonal
  patterns or growth plateaus that could set context for the review-quality
  analysis?

Output grain:
  One row per calendar month (order_purchase year-month).

Revenue definition:
  Revenue = SUM(price) only — item sale price in BRL.
  Freight (freight_value) is EXCLUDED from the revenue figure because
  freight is charged by the carrier and passed through; it is not Olist
  marketplace revenue. All references to "revenue" in this file mean
  item price only.
  If you need GMV including freight, replace SUM(oi.price) with
  SUM(oi.price + oi.freight_value) throughout.

Join-duplication risk and how it is handled:
  order_items has multiple rows per order_id (one per item).
  orders has one row per order_id.
  We join orders → order_items (one-to-many), then GROUP BY month,
  so the fan-out is intentional and correct: each item's price
  contributes independently to monthly revenue.
  There is no join to order_reviews or order_payments here, so no
  additional fan-out risk.

Filter:
  Only orders with order_status = 'delivered' are included.
  Rationale: undelivered orders have not yet generated confirmed revenue,
  and their absence from reviews would skew downstream analysis.
  V3 (SCHEMA.md) confirmed 8 delivered orders have NULL
  order_delivered_customer_date; those are still included here because
  the purchase timestamp is valid and the order was confirmed delivered.
==========================================================================
*/

WITH
-- CTE 1: delivered orders only.
-- Grain: one row per order_id.
delivered_orders AS (
    SELECT
        order_id,
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month
    FROM orders
    WHERE order_status = 'delivered'
),

-- CTE 2: item prices for those orders.
-- Grain: one row per (order_id, order_item_id) — item grain, intentional.
-- We sum price per item; freight excluded (see revenue definition above).
items AS (
    SELECT
        oi.order_id,
        oi.price          AS item_revenue   -- freight excluded
    FROM order_items oi
    INNER JOIN delivered_orders d ON d.order_id = oi.order_id
),

-- CTE 3: aggregate to month grain.
-- Grain: one row per order_month.
-- order_count uses COUNT(DISTINCT order_id) because items is at item grain.
monthly AS (
    SELECT
        d.order_month,
        COUNT(DISTINCT i.order_id)  AS order_count,
        SUM(i.item_revenue)         AS revenue_brl
    FROM items i
    INNER JOIN delivered_orders d ON d.order_id = i.order_id
    GROUP BY d.order_month
),

-- CTE 4: add month-over-month growth using LAG.
-- LAG looks back one row in order_month order to get prior month revenue.
-- growth_pct is NULL for the first month (no prior row to compare to).
monthly_with_growth AS (
    SELECT
        order_month,
        order_count,
        ROUND(revenue_brl, 2)                         AS revenue_brl,
        LAG(revenue_brl) OVER (ORDER BY order_month)  AS prev_month_revenue,
        ROUND(
            100.0 * (revenue_brl - LAG(revenue_brl) OVER (ORDER BY order_month))
                  / NULLIF(LAG(revenue_brl) OVER (ORDER BY order_month), 0),
            1
        )                                             AS mom_growth_pct
    FROM monthly
)

SELECT
    order_month,
    order_count,
    revenue_brl,
    prev_month_revenue,
    mom_growth_pct
FROM monthly_with_growth
ORDER BY order_month;
