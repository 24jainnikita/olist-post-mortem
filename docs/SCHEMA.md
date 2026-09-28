# Olist Dataset — Schema Reference

**Database:** `data/olist.duckdb`  
**Source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)  
**Loaded by:** `build/load_data.py`  
**Verified by:** `tests/verify_schema.py` — run after the loader to regenerate all figures below.

This document describes every table loaded into DuckDB: what it represents, what one row means (grain), which column is the primary key, and how it connects to other tables. Tables where the grain can cause duplicate rows when joined are explicitly flagged.

Every number in this document was produced by a query in this repository. No figure was assumed or estimated.

---

## Table of Contents

1. [orders](#1-orders)
2. [order_items](#2-order_items) ⚠️ duplication risk
3. [order_payments](#3-order_payments) ⚠️ duplication risk
4. [order_reviews](#4-order_reviews) ⚠️ duplication risk — no single-column PK
5. [customers](#5-customers)
6. [sellers](#6-sellers)
7. [products_raw / products](#7-products_raw--products-view)
8. [geolocation](#8-geolocation) ⚠️ duplication risk
9. [category_translation](#9-category_translation)

---

## Loaded Row Counts

Produced by `build/load_data.py` on the full dataset.

| Table | Rows |
|---|---|
| `orders` | 99,441 |
| `order_items` | 112,650 |
| `order_payments` | 103,886 |
| `order_reviews` | 99,224 |
| `customers` | 99,441 |
| `sellers` | 3,095 |
| `products_raw` | 32,951 |
| `geolocation` | 1,000,163 |
| `category_translation` | 71 |
| `products` (view, same grain as products_raw) | 32,951 |

---

## CSV vs DuckDB Row Counts

| CSV file | CSV data rows | DuckDB rows | Match |
|---|---|---|---|
| olist_orders_dataset.csv | 99,441 | 99,441 | ✓ |
| olist_order_items_dataset.csv | 112,650 | 112,650 | ✓ |
| olist_order_payments_dataset.csv | 103,886 | 103,886 | ✓ |
| olist_order_reviews_dataset.csv | 104,719 | 99,224 | ⚠️ see note |
| olist_customers_dataset.csv | 99,441 | 99,441 | ✓ |
| olist_sellers_dataset.csv | 3,095 | 3,095 | ✓ |
| olist_products_dataset.csv | 32,951 | 32,951 | ✓ |
| olist_geolocation_dataset.csv | 1,000,163 | 1,000,163 | ✓ |
| product_category_name_translation.csv | 71 | 71 | ✓ |

**Note on `order_reviews`:** The raw CSV has 104,719 newline-delimited lines after the header, but only 99,224 logical rows. The difference (5,495) is caused by embedded newline characters inside `review_comment_message` fields. These are quoted multi-line strings and are valid RFC 4180 CSV. DuckDB's parser handles them correctly — the row count of 99,224 is right; the line count is misleading. Confirmed by loading with `all_varchar=True`, which also produces 99,224 rows.

---

## Verified Facts

All results produced by `tests/verify_schema.py`. To regenerate: `python tests/verify_schema.py`.

---

### V1 — `order_reviews` key uniqueness

```sql
-- V1: totals
SELECT COUNT(*)                  AS rows,
       COUNT(DISTINCT review_id) AS uniq_review_id,
       COUNT(DISTINCT order_id)  AS uniq_order_id
FROM order_reviews;

-- V1b: how many review_id values appear more than once?
SELECT COUNT(*) AS review_id_dupe_count
FROM (
    SELECT review_id FROM order_reviews
    GROUP BY review_id HAVING COUNT(*) > 1
);

-- V1c: how many orders have more than one review row?
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT order_id FROM order_reviews
    GROUP BY order_id HAVING COUNT(*) > 1
);
```

| rows | uniq_review_id | uniq_order_id |
|---|---|---|
| 99,224 | 98,410 | 98,673 |

| review_id_dupe_count | orders_with_multiple_reviews |
|---|---|
| 789 | 547 |

**Interpretation — this contradicts an earlier assumption:**
- `review_id` is **not unique**. 789 `review_id` values appear in more than one row.
- `order_id` is also not unique. 547 orders have more than one review row.
- **There is no single-column primary key in `order_reviews`.** The practical composite key for deduplication is `(order_id, review_answer_timestamp DESC, review_id DESC)` — see §4 for the safe pattern.

---

### V2 — `customers` identity split

```sql
SELECT COUNT(*)                           AS rows,
       COUNT(DISTINCT customer_id)        AS uniq_customer_id,
       COUNT(DISTINCT customer_unique_id) AS uniq_people
FROM customers;
```

| rows | uniq_customer_id | uniq_people |
|---|---|---|
| 99,441 | 99,441 | 96,096 |

**Interpretation:** `rows` = `uniq_customer_id` confirms one row per order-scoped ID (no duplicates in this table). `uniq_people` (96,096) < `rows` (99,441) confirms that 3,345 order slots belong to customers who placed more than one order. Always use `customer_unique_id` for customer-level analysis — using `customer_id` would overcount real customers by ~3.5%.

---

### V3 — Delivered orders with missing delivery timestamp

```sql
SELECT COUNT(*) AS count
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
```

| count |
|---|
| 8 |

**Interpretation:** 8 orders are marked `delivered` but have no `order_delivered_customer_date`. This is a small number but it means `order_status = 'delivered'` cannot be used as a proxy for "delivery timestamp exists." Always filter on `order_delivered_customer_date IS NOT NULL` when computing delivery lateness or days-to-deliver.

---

### V4 — Zip code prefix integrity (type and leading zeros)

```sql
-- Customers
SELECT COUNT(*) AS short_zips FROM customers WHERE LENGTH(customer_zip_code_prefix) < 5;
-- Sellers
SELECT COUNT(*) AS short_zips FROM sellers WHERE LENGTH(seller_zip_code_prefix) < 5;
-- Geolocation
SELECT COUNT(*) AS short_zips FROM geolocation WHERE LENGTH(geolocation_zip_code_prefix) < 5;
-- Data type
SELECT typeof(customer_zip_code_prefix) AS zip_type FROM customers LIMIT 1;
```

| table | short_zips | zip_type |
|---|---|---|
| customers | 0 | VARCHAR |
| sellers | 0 | VARCHAR |
| geolocation | 0 | VARCHAR |

**Interpretation:** All three zip prefix columns are VARCHAR and all values are exactly 5 characters. Leading zeros are intact. DuckDB 1.5.6 infers these as VARCHAR naturally; `load_data.py` also pins them explicitly with `types=` as a forward-compatibility guard.

---

### V5 — Products with missing category names

```sql
-- Missing English translation
SELECT COUNT(*) AS null_english   FROM products WHERE product_category_name_english IS NULL;
-- Missing Portuguese name entirely
SELECT COUNT(*) AS null_portuguese FROM products WHERE product_category_name IS NULL;
```

| null_english | null_portuguese |
|---|---|
| 623 | 610 |

**Interpretation:**
- 623 products have no English category name. Most of these (610) are because `product_category_name` itself is NULL in the source data — the translation table has nothing to match against. The remaining 13 have a Portuguese name but no entry in `category_translation`.
- Use `COALESCE(product_category_name_english, product_category_name, 'unknown')` in all category-level grouping. Never filter these rows out — they represent real sales.

---

### V6 — `geolocation` grain

```sql
SELECT COUNT(*)                                    AS total_rows,
       COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_prefixes
FROM geolocation;
```

| total_rows | distinct_prefixes |
|---|---|
| 1,000,163 | 19,015 |

**Interpretation:** 1,000,163 rows cover only 19,015 distinct zip prefixes — an average of ~52.6 readings per prefix. Joining customers or sellers directly to `geolocation` without deduplication first will fan each customer/seller row out by ~52× on average. Use the `AVG(lat)/AVG(lng) GROUP BY prefix` pattern in §8 before any join.

---

## 1. `orders`

**Purpose:** The central fact table of the dataset. Records every order placed on the Olist marketplace, its current status, and the key timestamps in the order lifecycle.

**Grain:** One row per order.

**Primary key:** `order_id`

**Row count:** 99,441

**Columns:**

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR | Unique order identifier (PK) |
| `customer_id` | VARCHAR | FK → `customers.customer_id` — order-scoped, not a stable customer identity |
| `order_status` | VARCHAR | Current status: `delivered`, `shipped`, `canceled`, `invoiced`, `processing`, `approved`, `created`, `unavailable` |
| `order_purchase_timestamp` | TIMESTAMP | When the customer placed the order |
| `order_approved_at` | TIMESTAMP | When payment was approved |
| `order_delivered_carrier_date` | TIMESTAMP | When the seller handed the parcel to the carrier |
| `order_delivered_customer_date` | TIMESTAMP | When the customer received the parcel (NULL if not yet delivered) |
| `order_estimated_delivery_date` | TIMESTAMP | Delivery deadline shown to the customer at checkout |

**Join keys:**
- → `customers` on `customer_id`
- ← `order_items` on `order_id`
- ← `order_payments` on `order_id`
- ← `order_reviews` on `order_id`

**Notes:**
- Use `customer_id` only to bridge to `customers`. For any customer-level analysis, use `customers.customer_unique_id`.
- Delivery lateness = `order_delivered_customer_date - order_estimated_delivery_date`. A positive interval means late.
- V3 confirmed: 8 orders are marked `delivered` but have NULL `order_delivered_customer_date`. Always filter on the timestamp column directly, not `order_status`.

---

## 2. `order_items` ⚠️

> **⚠️ GRAIN WARNING**
> This table has **multiple rows per `order_id`** (one per item purchased). The right approach depends on the question you are answering:
>
> - **Analysing at order grain** (e.g. joining to `order_reviews` or `order_payments`): aggregate `order_items` to order grain in a CTE first, then join.
> - **Analysing at item/seller/category grain** (e.g. revenue per seller, review score per category): keep item grain and use `COUNT(DISTINCT order_id)` — not `COUNT(*)` — to count orders. Do not join `order_reviews` directly; one review covers the whole order, so at item grain a multi-seller order will assign that review score to every seller involved.
>
> In short: **choose your target grain first, then aggregate other tables to match it.**

**Purpose:** Records the individual line items within each order — which product was purchased, from which seller, at what price, with what freight cost.

**Grain:** One row per (order_id, order_item_id) — one row per item slot within an order.

**Primary key:** Composite (`order_id`, `order_item_id`)

**Row count:** 112,650

**Columns:**

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR | FK → `orders.order_id` |
| `order_item_id` | INTEGER | Position of this item within the order (1, 2, 3 …) |
| `product_id` | VARCHAR | FK → `products_raw.product_id` |
| `seller_id` | VARCHAR | FK → `sellers.seller_id` |
| `shipping_limit_date` | TIMESTAMP | Latest date the seller must dispatch the item |
| `price` | DOUBLE | Item sale price in BRL |
| `freight_value` | DOUBLE | Freight cost for this item in BRL |

**Join keys:**
- → `orders` on `order_id`
- → `products_raw` / `products` on `product_id`
- → `sellers` on `seller_id`

**Pattern A — aggregating up to order grain:**
```sql
-- CTE grain: one row per order_id (aggregated from order_items)
-- Safe to join to orders, order_reviews, order_payments without duplication
WITH order_items_agg AS (
    SELECT
        order_id,
        COUNT(*)                    AS item_count,
        SUM(price)                  AS total_price,
        SUM(freight_value)          AS total_freight,
        SUM(price + freight_value)  AS total_order_value
    FROM order_items
    GROUP BY order_id
)
```

**Pattern B — staying at item/seller grain:**
```sql
-- CTE grain: one row per seller_id
-- COUNT(DISTINCT order_id) counts orders, not items
-- review_score is order-level: a multi-seller order shares one score across all sellers.
-- Document this attribution assumption in any output using these numbers.
WITH seller_items AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id)  AS order_count,
        SUM(oi.price)                AS total_revenue,
        AVG(r.review_score)          AS avg_review_score
    FROM order_items oi
    JOIN order_reviews r ON r.order_id = oi.order_id
    GROUP BY oi.seller_id
)
```

---

## 3. `order_payments` ⚠️

> **⚠️ DUPLICATION RISK — read before joining**
> A single order can be paid with **multiple payment methods** (e.g. a voucher + a credit card), producing multiple rows per `order_id`. Joining this table directly to any other order-level table without aggregating first will duplicate order records.
> **Always aggregate to order grain in a CTE first**, then join.

**Purpose:** Records every payment transaction associated with an order. An order can have multiple rows if the customer used multiple payment methods or installments.

**Grain:** One row per (order_id, payment_sequential) — one row per payment method used.

**Primary key:** Composite (`order_id`, `payment_sequential`)

**Row count:** 103,886

**Columns:**

| Column | Type | Description |
|---|---|---|
| `order_id` | VARCHAR | FK → `orders.order_id` |
| `payment_sequential` | INTEGER | Payment attempt number within the order (1 = first method) |
| `payment_type` | VARCHAR | Method: `credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined` |
| `payment_installments` | INTEGER | Number of installments chosen (1 = paid in full) |
| `payment_value` | DOUBLE | Amount paid in this row, in BRL |

**Join keys:**
- → `orders` on `order_id`

**Safe aggregation pattern:**
```sql
-- CTE grain: one row per order_id
-- Sums all payment rows for the order into a single total
WITH payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value)           AS total_payment,
        MAX(payment_installments)    AS max_installments,
        COUNT(DISTINCT payment_type) AS payment_method_count
    FROM order_payments
    GROUP BY order_id
)
```

---

## 4. `order_reviews` ⚠️

> **⚠️ NO SINGLE-COLUMN PRIMARY KEY — read before joining**
>
> - `review_id` is **not unique**: 789 `review_id` values appear in more than one row (V1b).
> - `order_id` is **not unique**: 547 orders have more than one review row (V1c).
> - **There is no single-column primary key in this table.** The practical deduplication key is `order_id`, keeping one row per order using `review_answer_timestamp DESC, review_id DESC` as the tiebreaker.
>
> Always deduplicate to one row per `order_id` in a CTE before joining to other tables.

**Purpose:** Records customer satisfaction surveys sent after order delivery. Contains the star rating (1–5) and optional text comments. This is the primary target variable for the post-mortem analysis.

**Grain:** Approximately one row per order, but neither `review_id` nor `order_id` is unique. Both have duplicates in the raw data.

**Primary key:** None (no single-column key is unique). Practical deduplication key: `order_id`.

**Row count:** 99,224 (CSV has 104,719 lines; difference is embedded newlines in `review_comment_message` — not data loss)

**Columns:**

| Column | Type | Description |
|---|---|---|
| `review_id` | VARCHAR | Identifier for the review — **not unique** (789 values repeat) |
| `order_id` | VARCHAR | FK → `orders.order_id` — **not unique** (547 orders have multiple rows) |
| `review_score` | INTEGER | Customer rating: 1 (worst) to 5 (best) |
| `review_comment_title` | VARCHAR | Optional short title (often NULL) |
| `review_comment_message` | VARCHAR | Optional free-text comment (often NULL); may contain embedded newlines |
| `review_creation_date` | TIMESTAMP | When the survey was sent to the customer |
| `review_answer_timestamp` | TIMESTAMP | When the customer submitted the review |

**Join keys:**
- → `orders` on `order_id`

**Safe deduplication pattern:**
```sql
-- CTE grain: one row per order_id
-- Tiebreaker 1: keep the latest submission (review_answer_timestamp DESC)
-- Tiebreaker 2: review_id DESC — deterministic when timestamps tie
-- Note: review_id is not unique in the raw table (V1b), so it is used only
--       as a tiebreaker here, not as an identifier.
WITH reviews_deduped AS (
    SELECT DISTINCT ON (order_id)
        order_id,
        review_id,
        review_score,
        review_comment_message,
        review_answer_timestamp
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
)
```

**Analysis note:** For the central business question ("what drives 1–2 star reviews?"), `review_score IN (1, 2)` is the primary filter. Always deduplicate first. See V1 for the verified counts.

---

## 5. `customers`

**Purpose:** Maps the order-scoped `customer_id` to a stable `customer_unique_id`, and provides the customer's location (city, state, zip code prefix).

**Grain:** One row per `customer_id` (order-scoped). A real customer who placed multiple orders has one `customer_id` per order, all sharing the same `customer_unique_id`.

**Primary key:** `customer_id`

**Row count:** 99,441

**Columns:**

| Column | Type | Description |
|---|---|---|
| `customer_id` | VARCHAR | Order-scoped customer key (PK); matches `orders.customer_id` |
| `customer_unique_id` | VARCHAR | **Stable customer identity across all orders** — use this for any customer-level analysis |
| `customer_zip_code_prefix` | VARCHAR | First 5 digits of the customer's zip code — stored as VARCHAR; leading zeros confirmed intact (V4) |
| `customer_city` | VARCHAR | Customer's city |
| `customer_state` | VARCHAR | Customer's state (2-letter code) |

**Join keys:**
- → `orders` on `customer_id` (then use `customer_unique_id` for customer-level aggregation)
- → `geolocation` on `customer_zip_code_prefix`

> **⚠️ Key distinction:**
> `customer_id` is **order-scoped** — it changes between orders for the same real customer. V2 confirmed: 99,441 `customer_id` values map to only 96,096 real people. Always use `customer_unique_id` for questions like repeat purchase rate or cohort analysis. Using `customer_id` overcounts customers by ~3.5%.

---

## 6. `sellers`

**Purpose:** Describes the third-party merchants who list products on the Olist marketplace.

**Grain:** One row per seller.

**Primary key:** `seller_id`

**Row count:** 3,095

**Columns:**

| Column | Type | Description |
|---|---|---|
| `seller_id` | VARCHAR | Unique seller identifier (PK) |
| `seller_zip_code_prefix` | VARCHAR | First 5 digits of the seller's zip code — VARCHAR; leading zeros confirmed intact (V4) |
| `seller_city` | VARCHAR | Seller's city |
| `seller_state` | VARCHAR | Seller's state (2-letter code) |

**Join keys:**
- ← `order_items` on `seller_id`
- → `geolocation` on `seller_zip_code_prefix`

---

## 7. `products_raw` / `products` (view)

**Purpose:**
- `products_raw`: the raw product catalogue with Portuguese category names.
- `products` (view): `products_raw` LEFT JOINed to `category_translation` for English names. **Use `products` in all queries.**

**Grain:** One row per product.

**Primary key:** `product_id`

**Row count:** 32,951

**Columns (on `products` view):**

| Column | Type | Description |
|---|---|---|
| `product_id` | VARCHAR | Unique product identifier (PK) |
| `product_category_name` | VARCHAR | Category in Portuguese — NULL for 610 products (V5) |
| `product_category_name_english` | VARCHAR | Category in English — NULL for 623 products (V5) |
| `product_name_lenght` | INTEGER | Character count of the product name (typo in source: "lenght") |
| `product_description_lenght` | INTEGER | Character count of the description (typo in source: "lenght") |
| `product_photos_qty` | INTEGER | Number of product photos listed |
| `product_weight_g` | INTEGER | Product weight in grams |
| `product_length_cm` | INTEGER | Package length in cm |
| `product_height_cm` | INTEGER | Package height in cm |
| `product_width_cm` | INTEGER | Package width in cm |

**Join keys:**
- ← `order_items` on `product_id`
- → `category_translation` on `product_category_name` (already done in the view)

**Notes:**
- Column names `product_name_lenght` and `product_description_lenght` contain a typo in the source CSV. Preserved as-is to match the raw data.
- **NULL Portuguese names (V5):** 610 products have NULL `product_category_name`. These have no Portuguese name to translate, so their `product_category_name_english` is also NULL (accounts for the majority of the 623 NULL-English count). The remaining 13 have a Portuguese name with no entry in the translation table.
- **NULL handling rule:** Always use `COALESCE(product_category_name_english, product_category_name, 'unknown')` in any category-level grouping. Never drop these rows — they represent real sales.
- **Untested hypothesis:** `product_photos_qty` may correlate with review scores. This has not been tested — treat as a hypothesis to investigate, not a confirmed finding.

---

## 8. `geolocation` ⚠️

**Purpose:** Maps Brazilian zip code prefixes to latitude/longitude coordinates. The main analysis uses state-level aggregation, so **this table is optional** — all core queries run without it.

**Grain:** Multiple rows per zip prefix (average ~52.6 readings per prefix — V6). Not one canonical point per zip code.

**Primary key:** None. `geolocation_zip_code_prefix` is not unique.

**Row count:** 1,000,163 (covering 19,015 distinct prefixes)

**Columns:**

| Column | Type | Description |
|---|---|---|
| `geolocation_zip_code_prefix` | VARCHAR | 5-digit zip code prefix — VARCHAR; leading zeros confirmed intact (V4) |
| `geolocation_lat` | DOUBLE | Latitude |
| `geolocation_lng` | DOUBLE | Longitude |
| `geolocation_city` | VARCHAR | City name |
| `geolocation_state` | VARCHAR | State (2-letter code) |

**Join keys:**
- ← `customers` on `customer_zip_code_prefix`
- ← `sellers` on `seller_zip_code_prefix`

> **⚠️ Join warning:** Joining customers or sellers directly to `geolocation` without deduplication first fans each row out by ~52× on average (V6). Always deduplicate to one row per prefix first.

**Safe dedupe pattern — AVG coordinates:**
```sql
-- CTE grain: one row per zip prefix
-- AVG(lat/lng) averages all recorded observations — preferred over DISTINCT ON
-- because no single GPS reading is authoritative; averaging reduces outlier effect.
-- Only join this CTE when you need point coordinates. For state-level analysis,
-- use customers.customer_state or sellers.seller_state directly — no join needed.
WITH geo_deduped AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
```

---

## 9. `category_translation`

**Purpose:** Lookup table mapping Portuguese product category names to English equivalents.

**Grain:** One row per Portuguese category name.

**Primary key:** `product_category_name` (Portuguese name)

**Row count:** 71

**Columns:**

| Column | Type | Description |
|---|---|---|
| `product_category_name` | VARCHAR | Category name in Portuguese (PK) |
| `product_category_name_english` | VARCHAR | Category name in English |

**Join keys:**
- → `products_raw` on `product_category_name` (already materialised in the `products` view)

---

## Entity Relationship Summary

```
customers ──────────────── orders ──────────────── order_items ─── products
(customer_unique_id         (order_id)              (⚠️ multi-row    (products view
 is stable identity;            │                    one per item)    adds English
 99,441 rows = 96,096           │                        │            categories;
 real people)                   │                        └─── sellers  623 NULL english,
                                ├── order_payments                     610 NULL portuguese)
                                │   (⚠️ multi-row)
                                │
                                └── order_reviews
                                    (⚠️ no single-column PK;
                                     review_id not unique;
                                     order_id not unique;
                                     dedupe on order_id)

geolocation ← customers (via zip_code_prefix) — optional; AVG dedupe, ~52× fan-out risk
geolocation ← sellers   (via zip_code_prefix) — optional; AVG dedupe, ~52× fan-out risk
```

---

## Quick Reference: Duplication Risks

| Table | Risk | Safe Pattern |
|---|---|---|
| `order_items` | Multiple rows per `order_id` (one per item) | Choose target grain first; aggregate to it; use `COUNT(DISTINCT order_id)` at item grain |
| `order_payments` | Multiple rows per `order_id` (one per payment method) | Aggregate to order grain in a CTE before joining |
| `order_reviews` | Neither `review_id` nor `order_id` is unique; no single-column PK | Deduplicate on `order_id` with `review_answer_timestamp DESC, review_id DESC` tiebreaker |
| `geolocation` | ~52.6 rows per zip prefix on average (1,000,163 rows / 19,015 prefixes) | `AVG(lat)/AVG(lng) GROUP BY prefix`; table is optional for state-level analysis |

*All numbers and row counts in this document come from queries in this repository. None were assumed or estimated.*
 