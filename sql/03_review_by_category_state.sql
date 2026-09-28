/*
==========================================================================
Business question:
  Which product categories and which customer states have the worst
  review scores? Are the problems concentrated in specific segments,
  or spread evenly? This helps Olist prioritise where to intervene.

Output grain:
  Two separate result sets:
    Part A — one row per product category (English name), min 100 orders.
    Part B — one row per customer state, min 100 orders.

  Both are in this single file separated by a comment. Run them
  individually in run_query.py by splitting on the separator, or adapt
  the runner to execute both and display them sequentially.

Join-duplication risk and how it is handled:
  The core join chain is:
    order_reviews (deduplicated to order grain)
    → orders          (one row per order_id — safe)
    → order_items     (MULTIPLE rows per order_id — fan-out risk)
    → products view   (one row per product_id — safe once at item grain)
    → customers       (reached via orders.customer_id — one row — safe)

  order_items fan-out handling:
    We need one category per order for the category analysis. An order
    can contain items from multiple categories. We handle this by
    grouping at (order_id, category) level — each (order_id, category)
    pair gets one row, and the review score is attributed to that pair.
    This means a multi-category order contributes its review score to
    EACH category it contains. That is the correct attribution for the
    question "which categories receive bad reviews?" because we cannot
    tell which item within the order caused the bad review.
    This assumption is documented in the output column names.

  order_reviews deduplication:
    Deduplicated to one row per order_id using the standard tiebreaker
    (review_answer_timestamp DESC, review_id DESC) before any join.

Filter:
  Only delivered orders (order_status = 'delivered').
  Minimum 100 (order_id, category/state) pairs per group to exclude
  noisy small-volume segments.

Category NULL handling:
  Products with no English category name use
  COALESCE(product_category_name_english, product_category_name, 'unknown')
  per the rule in SCHEMA.md §7. They are included, not dropped.
==========================================================================
*/

WITH
-- CTE 1: deduplicate order_reviews to one row per order_id.
-- Grain: one row per order_id.
reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
),

-- CTE 2: delivered orders joined to their review and customer state.
-- Grain: one row per order_id.
order_base AS (
    SELECT
        o.order_id,
        o.customer_id,
        r.review_score
    FROM orders o
    INNER JOIN reviews_deduped r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),

-- CTE 3: expand to (order_id, category) grain by joining order_items → products.
-- Grain: one row per (order_id, product_category).
-- Fan-out from order_items is intentional here (see header note).
-- A single order with items from 3 categories produces 3 rows;
-- its review_score is attributed to all 3 categories.
order_category AS (
    SELECT
        ob.order_id,
        ob.review_score,
        COALESCE(
            p.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category
    FROM order_base ob
    INNER JOIN order_items oi ON oi.order_id = ob.order_id
    INNER JOIN products    p  ON p.product_id = oi.product_id
),

-- CTE 4: join order_base to customers for state.
-- Grain: one row per order_id (customers has one row per customer_id,
-- and orders has one row per order_id — no fan-out).
order_state AS (
    SELECT
        ob.order_id,
        ob.review_score,
        c.customer_state
    FROM order_base ob
    INNER JOIN orders   o ON o.order_id    = ob.order_id
    INNER JOIN customers c ON c.customer_id = o.customer_id
),

-- ── PART A: aggregate by category ────────────────────────────────────────────
-- Grain: one row per category (min 100 order-category pairs).
category_agg AS (
    SELECT
        category,
        COUNT(DISTINCT order_id)                                  AS order_count,
        ROUND(AVG(review_score), 3)                               AS avg_review_score,
        ROUND(
            100.0 * SUM(CASE WHEN review_score IN (1,2) THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(review_score), 0),
            1
        )                                                         AS pct_low_review
    FROM order_category
    GROUP BY category
    HAVING COUNT(DISTINCT order_id) >= 100
),

-- ── PART B: aggregate by customer state ──────────────────────────────────────
-- Grain: one row per state (min 100 orders).
state_agg AS (
    SELECT
        customer_state,
        COUNT(DISTINCT order_id)                                  AS order_count,
        ROUND(AVG(review_score), 3)                               AS avg_review_score,
        ROUND(
            100.0 * SUM(CASE WHEN review_score IN (1,2) THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(review_score), 0),
            1
        )                                                         AS pct_low_review
    FROM order_state
    GROUP BY customer_state
    HAVING COUNT(DISTINCT order_id) >= 100
)

-- ── Output: run_query.py will display both result sets ───────────────────────
-- sort_group keeps categories (1) before separator (2) before states (3).
-- Within each group, rows are ordered by avg_review_score ASC (worst first).
-- PART A: categories
SELECT
    1                AS sort_group,
    'category'       AS dimension,
    category         AS segment,
    order_count,
    avg_review_score,
    pct_low_review
FROM category_agg

UNION ALL

-- Separator row so the two result sets are visually distinct in terminal output
SELECT 2, '---', '--- state results below ---', NULL, NULL, NULL

UNION ALL

-- PART B: states
SELECT
    3                AS sort_group,
    'state'          AS dimension,
    customer_state   AS segment,
    order_count,
    avg_review_score,
    pct_low_review
FROM state_agg

ORDER BY sort_group, avg_review_score ASC NULLS LAST;
