# Olist Post-Mortem — Project Steering Rules

## Project Overview

**Project name:** Olist Post-Mortem  
**Dataset:** Olist Brazilian E-Commerce Public Dataset  
**Central business question:** What drives 1–2 star reviews, and what should Olist fix first?

---

## Database

- Use **DuckDB only**. SQLite is the only acceptable fallback for environments where DuckDB cannot be installed.
- Do **not** use PostgreSQL, MySQL, or any server-based database. This project runs entirely local and serverless.

---

## SQL Rules

- All SQL lives in `/sql`. One file per question, named descriptively (e.g., `01_review_score_distribution.sql`).
- Every SQL file must be **commented**: explain what the query answers, what each CTE does, and why any filter or join was written the way it was.
- Use **CTEs** for all multi-step logic. Avoid subqueries in the `FROM` clause when a CTE would be clearer.
- Use **window functions** wherever ranking, running totals, or lag/lead comparisons are needed.

---

## Customer Identity

- Always use **`customer_unique_id`** for any customer-level analysis (repeat purchase rates, cohorts, churn, etc.).
- Never use `customer_id` for customer-level aggregation — it is order-scoped and will overcount customers.

---

## Join Grain — Critical Rule

- `order_items` has **multiple rows per order** (one per item). Joining it directly to `orders`, `order_payments`, or `order_reviews` **will duplicate revenue and review scores**.
- Every query that touches `order_items` must:
  1. Aggregate it to order grain first (in a CTE), *then* join to other tables.
  2. Include a comment that explicitly states the grain of each CTE and confirms duplication has been handled.

Example comment pattern:
```sql
-- CTE grain: one row per order_id (aggregated from order_items)
-- Safe to join to order_reviews (also one row per order_id) without duplication
```

---

## Number Integrity

- Every figure shown anywhere — in the README, a memo, the web UI, a slide — **must trace back to a query in this repo**.
- Never invent, estimate, or eyeball a number. If a number cannot be produced by a query, it does not appear.

---

## Build Script Logging

- The build/ETL script must **log row counts before and after every join**, e.g.:
  ```
  [orders]         before join: 99,441 rows
  [order_reviews]  before join:  99,224 rows
  [joined]         after join:   99,224 rows  ← explain any difference
  ```
- Any unexpected drop or inflation in row count must raise a warning and be explained in a comment.

---

## Plain-Language Explanations

- Every query, transform, and analytical decision must be explainable in plain language to a non-technical stakeholder.
- Write a one-paragraph plain-language summary at the top of each SQL file, above the code, describing what question it answers and what the result means for the business.
- Assume the author must be able to defend every query in a live interview: if you cannot explain *why* a join condition, filter, or aggregation was written that way, rewrite it until you can.
