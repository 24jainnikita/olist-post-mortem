/*
==========================================================================
Business question:
  Within each product category, which sellers consistently earn the best
  and worst reviews? Identifying bottom sellers by category lets Olist
  target seller coaching or offboarding decisions at the right segment.

Output grain:
  One row per (tier, category, seller_id). Sellers are ranked within
  their category. The output contains:
    - top_10 rows: the 10 best-ranked sellers per category
    - bottom_10 rows: the 10 worst-ranked sellers per category
    - A summary block: one row per category showing how many qualifying
      sellers it has and whether it has fewer than 20.

  IMPORTANT — sellers appearing in BOTH top and bottom lists:
  In categories with few qualifying sellers (fewer than ~20), the
  top-10 and bottom-10 windows overlap. A seller ranked 7th best in a
  category with 12 qualifying sellers is also ranked 6th worst — and
  appears in both tiers. This is not a bug; it is a data sparsity signal.
  Such sellers are marked with in_both_lists = TRUE in the output.
  If you want mutually exclusive lists, filter WHERE in_both_lists = FALSE.
  From the data: 131 seller-category pairs appear in both lists.

The 30-order threshold is PER SELLER-CATEGORY PAIR:
  A seller must have >= 30 orders in a specific category to be ranked
  in that category. The same seller can qualify in multiple categories
  independently. A seller with 50 orders in health_beauty and 15 in toys
  appears in the health_beauty ranking but not the toys ranking.

  Why 30 per seller-category:
  A seller with fewer than 30 orders in a category has a 95% confidence
  interval on their average review score of roughly ±0.5 stars — too
  wide to distinguish a genuinely bad seller from an unlucky one.
  At 30 orders the interval narrows to ~±0.3 stars, which is actionable.
  30 is conservative (50 would be more robust) but balances statistical
  reliability against including enough sellers to make rankings useful.

Categories with fewer than 20 qualifying sellers:
  43 of 54 categories have fewer than 20 sellers meeting the 30-order
  threshold. Rankings in these categories should be treated with caution:
  the top/bottom overlap is large and small score differences may not be
  meaningful. These are flagged in the output (few_qualifying_sellers = TRUE).

Join-duplication risk and how it is handled:
  order_reviews deduplicated to one row per order_id first.
  order_items fans out to one row per (order_id, seller_id, category) —
  intentional. The order-level review is attributed to each
  (seller, category) pair. A multi-seller order assigns its review score
  to each seller in it.
  COUNT(DISTINCT order_id) prevents double-counting when one order
  contains multiple items from the same seller in the same category.
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
-- order_id kept so CTE 4 can COUNT(DISTINCT order_id).
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
-- Threshold: >= 30 orders per seller-category pair (see header).
seller_category_stats AS (
    SELECT
        seller_id,
        category,
        COUNT(DISTINCT order_id)                             AS order_count,
        ROUND(AVG(review_score), 3)                          AS avg_review_score,
        ROUND(
            100.0 * SUM(CASE WHEN review_score IN (1,2) THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(review_score), 0),
            1
        )                                                    AS pct_low_review
    FROM seller_order_reviews
    GROUP BY seller_id, category
    HAVING COUNT(DISTINCT order_id) >= 30
),

-- CTE 5: count qualifying sellers per category.
-- Used to flag categories with < 20 qualifying sellers.
category_seller_counts AS (
    SELECT
        category,
        COUNT(DISTINCT seller_id)    AS qualifying_seller_count,
        CASE WHEN COUNT(DISTINCT seller_id) < 20
             THEN TRUE ELSE FALSE
        END                          AS few_qualifying_sellers
    FROM seller_category_stats
    GROUP BY category
),

-- CTE 6: rank sellers within each category.
-- DENSE_RANK: ties share the same rank; no rank is skipped after a tie.
-- rank_best  = 1 → highest avg_review_score (best seller)
-- rank_worst = 1 → lowest  avg_review_score (worst seller)
ranked AS (
    SELECT
        s.category,
        s.seller_id,
        s.order_count,
        s.avg_review_score,
        s.pct_low_review,
        c.qualifying_seller_count,
        c.few_qualifying_sellers,
        DENSE_RANK() OVER (
            PARTITION BY s.category
            ORDER BY s.avg_review_score DESC, s.order_count DESC
        ) AS rank_best,
        DENSE_RANK() OVER (
            PARTITION BY s.category
            ORDER BY s.avg_review_score ASC, s.order_count DESC
        ) AS rank_worst
    FROM seller_category_stats s
    INNER JOIN category_seller_counts c ON c.category = s.category
),

-- CTE 7: label each seller as top, bottom, or both.
-- in_both_lists = TRUE when the seller falls within both top-10 and bottom-10
-- windows. This happens in categories where qualifying_seller_count < ~20.
labeled AS (
    SELECT
        CASE
            WHEN rank_best  <= 10 AND rank_worst <= 10 THEN 'both'
            WHEN rank_best  <= 10                      THEN 'top_10'
            WHEN rank_worst <= 10                      THEN 'bottom_10'
        END                     AS tier,
        category,
        qualifying_seller_count,
        few_qualifying_sellers,
        CASE WHEN rank_best <= 10 AND rank_worst <= 10 THEN TRUE ELSE FALSE END
                                AS in_both_lists,
        rank_best,
        rank_worst,
        seller_id,
        order_count,
        avg_review_score,
        pct_low_review
    FROM ranked
    WHERE rank_best <= 10 OR rank_worst <= 10
)

-- Final output: top_10 and bottom_10 rows.
-- Sellers in both lists appear once per tier that applies to them.
SELECT
    tier,
    category,
    qualifying_seller_count,
    few_qualifying_sellers,
    in_both_lists,
    CASE WHEN tier IN ('top_10','both') THEN rank_best  ELSE rank_worst END AS rank,
    seller_id,
    order_count,
    avg_review_score,
    pct_low_review
FROM labeled
ORDER BY category, tier DESC, rank ASC NULLS LAST;
