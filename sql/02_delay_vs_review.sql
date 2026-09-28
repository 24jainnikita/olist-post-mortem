/*
==========================================================================
Business question:
  Does late delivery drive 1–2 star reviews? How does review score
  distribution shift as delivery delay increases? This is a primary
  candidate for "what should Olist fix first."

Output grain:
  One row per delay bucket (4 buckets total).

Delay definition:
  delay_days = order_delivered_customer_date - order_estimated_delivery_date
  measured in fractional days (EPOCH difference / 86400).
  Negative or zero = on time or early.
  Positive = late.

  Buckets:
    'on_time_or_early'  : delay_days <= 0
    '1_to_3_days_late'  : delay_days >  0 AND <= 3
    '4_to_7_days_late'  : delay_days >  3 AND <= 7
    'over_7_days_late'  : delay_days >  7

Filter:
  Only delivered orders with a non-NULL order_delivered_customer_date.
  V3 (SCHEMA.md) confirmed 8 delivered orders have NULL delivery dates;
  those are excluded here because delay cannot be calculated without
  the actual delivery timestamp.

Join-duplication risk and how it is handled:
  We join orders (one row per order) to order_reviews (not one row per
  order — see SCHEMA.md V1: order_id not unique in order_reviews).
  order_reviews is deduplicated to one row per order_id in the
  reviews_deduped CTE before joining, using the standard tiebreaker:
  review_answer_timestamp DESC, review_id DESC.
  No join to order_items or order_payments — no additional fan-out risk.
==========================================================================
*/

WITH
-- CTE 1: delivered orders with calculable delay.
-- Grain: one row per order_id.
delivered AS (
    SELECT
        order_id,
        -- delay in days (positive = late, negative = early)
        EPOCH(order_delivered_customer_date - order_estimated_delivery_date)
            / 86400.0   AS delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

-- CTE 2: deduplicate order_reviews to one row per order_id.
-- Grain: one row per order_id.
-- Tiebreaker: latest answer timestamp; review_id DESC for ties.
-- (SCHEMA.md V1: review_id not unique, order_id not unique in raw table.)
reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
),

-- CTE 3: join orders to reviews, assign delay bucket.
-- Grain: one row per order_id (both source CTEs are at order grain).
-- LEFT JOIN: keeps orders with no review (review_score will be NULL).
orders_with_delay AS (
    SELECT
        d.order_id,
        d.delay_days,
        r.review_score,
        CASE
            WHEN d.delay_days <= 0            THEN 'on_time_or_early'
            WHEN d.delay_days <= 3            THEN '1_to_3_days_late'
            WHEN d.delay_days <= 7            THEN '4_to_7_days_late'
            ELSE                                   'over_7_days_late'
        END AS delay_bucket,
        -- Sort key so results display in logical order
        CASE
            WHEN d.delay_days <= 0            THEN 1
            WHEN d.delay_days <= 3            THEN 2
            WHEN d.delay_days <= 7            THEN 3
            ELSE                                   4
        END AS bucket_sort
    FROM delivered d
    LEFT JOIN reviews_deduped r ON r.order_id = d.order_id
)

-- Final aggregation: one row per delay bucket.
SELECT
    bucket_sort,
    delay_bucket,
    COUNT(*)                                             AS order_count,
    ROUND(AVG(review_score), 3)                          AS avg_review_score,
    ROUND(
        100.0 * SUM(CASE WHEN review_score IN (1, 2) THEN 1 ELSE 0 END)
              / NULLIF(COUNT(review_score), 0),
        1
    )                                                    AS pct_low_review,
    -- orders with no review at all (review_score IS NULL)
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) AS orders_without_review
FROM orders_with_delay
GROUP BY delay_bucket, bucket_sort
ORDER BY bucket_sort;
