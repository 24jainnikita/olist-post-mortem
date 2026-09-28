/*
==========================================================================
Business question:
  How many bad reviews are "excess" — i.e. above the number we would
  expect if late orders had the same bad-review rate as on-time orders?
  This gives a concrete, defensible estimate of the bad-review burden
  attributable to late delivery.

  Formula:
    expected_bad_reviews_from_late = late_order_count × on_time_bad_review_rate
    excess_bad_reviews = actual_bad_reviews_from_late − expected
    excess_share_of_all_bad = excess / total_bad_reviews

  This is an UPPER BOUND on the causal effect of late delivery because:
    1. Category confounding: late-delivered categories may have higher
       baseline dissatisfaction even when on time (see query 03 — e.g.
       office_furniture has 25.5% bad-review rate regardless of delay).
       If categories with worse products also ship late more often, the
       excess figure overstates delivery's independent contribution.
    2. Regional confounding: Northeast customers (MA, AL, SE) both receive
       more late deliveries AND rate worse overall. The "on-time rate"
       baseline is an average that may not apply to late-skewed regions.
    3. Seller confounding: sellers who ship late may also sell
       lower-quality products, pack poorly, or have worse customer service.
       The bad review may be about the product, not the delay.
    4. This is an observational association, not a randomised experiment.
       Fixing delivery lateness would likely reduce bad reviews, but by
       less than the excess figure suggests because the confounders above
       would still operate.

Output grain:
  One row — the single excess figure and its components.

Join-duplication risk:
  Same as query 07. orders → reviews_deduped only, both at order grain.
  No fan-out risk.

Lateness definition:
  Matches query 07 exactly: delivered orders with non-NULL delivery date,
  late = actual > estimated.
==========================================================================
*/

WITH
-- CTE 1: delivered orders with lateness flag.
-- Grain: one row per order_id.
delivered AS (
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'late'
            ELSE 'on_time'
        END AS delivery_status
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

-- CTE 2: deduplicate reviews.
reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
),

-- CTE 3: join to get review status per order.
orders_reviewed AS (
    SELECT
        d.delivery_status,
        CASE WHEN r.review_score IN (1, 2) THEN 1 ELSE 0 END AS is_low_review,
        CASE WHEN r.review_score IS NOT NULL THEN 1 ELSE 0 END AS has_review
    FROM delivered d
    LEFT JOIN reviews_deduped r ON r.order_id = d.order_id
),

-- CTE 4: aggregate by delivery status.
by_status AS (
    SELECT
        delivery_status,
        COUNT(*)            AS order_count,
        SUM(has_review)     AS orders_with_review,
        SUM(is_low_review)  AS bad_review_count,
        -- bad-review rate = bad reviews / orders that have a review
        SUM(is_low_review) * 1.0 / NULLIF(SUM(has_review), 0) AS bad_review_rate
    FROM orders_reviewed
    GROUP BY delivery_status
)

-- Final: compute excess in a single row.
SELECT
    -- Actual counts
    MAX(CASE WHEN delivery_status = 'late'    THEN order_count       END) AS late_order_count,
    MAX(CASE WHEN delivery_status = 'on_time' THEN order_count       END) AS ontime_order_count,
    MAX(CASE WHEN delivery_status = 'late'    THEN bad_review_count  END) AS actual_bad_late,
    MAX(CASE WHEN delivery_status = 'on_time' THEN bad_review_count  END) AS actual_bad_ontime,

    -- On-time baseline rate (the counterfactual rate applied to late orders)
    ROUND(
        100.0 * MAX(CASE WHEN delivery_status = 'on_time' THEN bad_review_rate END),
        2
    )                                                                      AS ontime_bad_review_rate_pct,

    -- Expected bad reviews if late orders had the on-time rate
    ROUND(
        MAX(CASE WHEN delivery_status = 'late' THEN orders_with_review END)
        * MAX(CASE WHEN delivery_status = 'on_time' THEN bad_review_rate END)
    )                                                                      AS expected_bad_from_late,

    -- Excess = actual − expected
    ROUND(
        MAX(CASE WHEN delivery_status = 'late' THEN bad_review_count END)
        - MAX(CASE WHEN delivery_status = 'late' THEN orders_with_review END)
          * MAX(CASE WHEN delivery_status = 'on_time' THEN bad_review_rate END)
    )                                                                      AS excess_bad_reviews,

    -- Total bad reviews across all delivered orders (denominator)
    SUM(bad_review_count)                                                  AS total_bad_reviews,

    -- Excess as % of all bad reviews (upper-bound attribution to late delivery)
    ROUND(
        100.0 * (
            MAX(CASE WHEN delivery_status = 'late' THEN bad_review_count END)
            - MAX(CASE WHEN delivery_status = 'late' THEN orders_with_review END)
              * MAX(CASE WHEN delivery_status = 'on_time' THEN bad_review_rate END)
        ) / NULLIF(SUM(bad_review_count), 0),
        1
    )                                                                      AS excess_as_pct_of_all_bad

FROM by_status;
