/*
==========================================================================
Business question:
  How many qualifying sellers exist in each category? A qualifying seller
  is one with >= 30 orders in that category. This helps contextualise
  the seller rankings in 04_seller_ranking.sql.

Output grain:
  One row per category.

Join-duplication risk and how it is handled:
  Matches 04_seller_ranking.sql.
==========================================================================
*/
WITH
-- CTE 1: deduplicate reviews to one row per order_id.
reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
),

-- CTE 2: delivered orders only.
delivered_orders AS (
    SELECT order_id FROM orders WHERE order_status = 'delivered'
),

-- CTE 3: one row per (order_id, seller_id, category) with review score.
seller_order_reviews AS (
    SELECT
        d.order_id,
        oi.seller_id,
        COALESCE(
            p.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,
        r.review_score
    FROM delivered_orders d
    INNER JOIN order_items    oi ON oi.order_id  = d.order_id
    INNER JOIN products       p  ON p.product_id = oi.product_id
    INNER JOIN reviews_deduped r  ON r.order_id  = d.order_id
),

-- CTE 4: aggregate to (seller_id, category) grain.
seller_category_stats AS (
    SELECT
        seller_id,
        category,
        COUNT(DISTINCT order_id)                             AS order_count
    FROM seller_order_reviews
    GROUP BY seller_id, category
    HAVING COUNT(DISTINCT order_id) >= 30
),

-- CTE 5: count qualifying sellers per category.
category_seller_counts AS (
    SELECT
        category,
        COUNT(DISTINCT seller_id)    AS qualifying_seller_count,
        CASE WHEN COUNT(DISTINCT seller_id) < 20
             THEN TRUE ELSE FALSE
        END                          AS few_qualifying_sellers
    FROM seller_category_stats
    GROUP BY category
)

SELECT * FROM category_seller_counts
ORDER BY category;
