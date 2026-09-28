/*
==========================================================================
Business question:
  Of all 1–2 star reviews in the dataset, what fraction came from
  late-delivered orders? And how does the 1–2 star rate compare between
  late and on-time orders? This provides the headline number for the
  post-mortem ("X% of bad reviews are attributable to late delivery").

Output grain:
  Three result sets combined via UNION ALL:
    Part A — 2 rows: late vs on-time, showing order count, 1-2 star
             count, 1-2 star rate, and share of all 1-2 star reviews.
    Part B — 1 row: of ALL 1-2 star reviews, what % came from late orders.
    Part C — 1 row: lift — how many times more likely is a 1-2 star
             review in a late order vs an on-time order.

Lateness definition:
  late = order_delivered_customer_date > order_estimated_delivery_date
  on_time = order_delivered_customer_date <= order_estimated_delivery_date
  Orders with NULL delivery date are excluded (8 orders per V3).

What this analysis DOES NOT prove — confounders to investigate next:
  1. Category confounding: certain product categories (e.g. office_furniture,
     electronics) may have both higher late-delivery rates AND inherently
     higher customer expectations, producing bad reviews even when on time.
     The delivery effect and the category effect are not separated here.
  2. Regional confounding: customers in the Northeast (MA, AL, SE) face
     longer shipping distances and higher late-delivery rates AND may have
     different baseline rating behaviour. Query 03 shows they rate worse
     overall; it is not yet clear how much is delivery vs other factors.
  3. Seller confounding: some sellers may pack poorly, ship late, AND
     operate in categories with low satisfaction — the bad review could
     stem from product quality, not delivery.
  4. Causation vs correlation: this analysis shows association. A customer
     who received a late delivery may have given 1 star for that reason,
     or may have given 1 star because the product was defective and the
     lateness was incidental. Review comment text (not yet analysed) would
     be needed to separate these.
  5. Survivorship: orders still in transit have no review yet. If late
     orders are less likely to ever receive a review, the late-delivery
     bad-review rate could be understated.

Join-duplication risk and how it is handled:
  orders (one row per order_id) joined to order_reviews (deduplicated
  to one row per order_id). Both sides are at order grain before joining
  — no fan-out risk. No join to order_items or order_payments.
==========================================================================
*/

WITH
-- CTE 1: delivered orders with lateness flag.
-- Grain: one row per order_id.
-- Excludes 8 orders with NULL delivery date (cannot compute lateness).
delivered AS (
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'late'
            ELSE 'on_time'
        END AS delivery_status,
        -- raw delay in days for reference (not used in final output)
        EPOCH(order_delivered_customer_date - order_estimated_delivery_date)
            / 86400.0 AS delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

-- CTE 2: deduplicate order_reviews to one row per order_id.
-- Grain: one row per order_id.
reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
),

-- CTE 3: join delivered orders to their review.
-- Grain: one row per order_id (both CTEs are at order grain — no fan-out).
-- LEFT JOIN: orders without a review are retained (review_score = NULL).
orders_reviewed AS (
    SELECT
        d.order_id,
        d.delivery_status,
        r.review_score,
        CASE WHEN r.review_score IN (1, 2) THEN 1 ELSE 0 END AS is_low_review
    FROM delivered d
    LEFT JOIN reviews_deduped r ON r.order_id = d.order_id
),

-- CTE 4: aggregate by delivery status.
-- Grain: one row per delivery_status (2 rows: late, on_time).
by_status AS (
    SELECT
        delivery_status,
        COUNT(*)                                      AS order_count,
        SUM(CASE WHEN review_score IS NOT NULL
                 THEN 1 ELSE 0 END)                  AS orders_with_review,
        SUM(is_low_review)                            AS low_review_count,
        ROUND(
            100.0 * SUM(is_low_review)
                  / NULLIF(SUM(CASE WHEN review_score IS NOT NULL
                                    THEN 1 ELSE 0 END), 0),
            2
        )                                             AS low_review_rate_pct
    FROM orders_reviewed
    GROUP BY delivery_status
),

-- CTE 5: total low reviews across all delivered orders (denominator for share).
totals AS (
    SELECT SUM(low_review_count) AS total_low_reviews
    FROM by_status
)

-- Part A: late vs on-time breakdown
SELECT
    1                     AS sort_order,
    'A_by_status'         AS part,
    delivery_status,
    CAST(order_count               AS VARCHAR) AS col1,
    CAST(orders_with_review        AS VARCHAR) AS col2,
    CAST(low_review_count          AS VARCHAR) AS col3,
    CAST(low_review_rate_pct       AS VARCHAR) AS col4,
    CAST(
        ROUND(100.0 * low_review_count / NULLIF((SELECT total_low_reviews FROM totals), 0), 1)
        AS VARCHAR
    )                                          AS col5_pct_of_all_bad_reviews
FROM by_status

UNION ALL

-- Part B: headline — of all 1-2 star reviews, % from late orders
SELECT
    2,
    'B_late_share_of_all_bad_reviews',
    'pct_of_1_2_star_from_late_orders',
    CAST(
        ROUND(
            100.0 * SUM(CASE WHEN delivery_status = 'late' THEN low_review_count ELSE 0 END)
                  / NULLIF(SUM(low_review_count), 0),
            1
        ) AS VARCHAR
    ),
    NULL, NULL, NULL, NULL
FROM by_status

UNION ALL

-- Part C: lift — how many times more likely to get a bad review if late
SELECT
    3,
    'C_lift',
    'late_vs_ontime_bad_review_rate_lift',
    CAST(
        ROUND(
            MAX(CASE WHEN delivery_status = 'late'    THEN low_review_rate_pct END) /
            NULLIF(MAX(CASE WHEN delivery_status = 'on_time' THEN low_review_rate_pct END), 0),
            2
        ) AS VARCHAR
    ),
    NULL, NULL, NULL, NULL
FROM by_status

ORDER BY sort_order, delivery_status;
