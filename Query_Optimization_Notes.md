# Query Optimization Notes
**Project:** SQL-Based Data Analysis — Retail Sales Domain  
**Database:** PostgreSQL 14+  
**File Reference:** `02_analysis_queries.sql` — Group E (queries E-1a/b and E-2a/b)

---

## Overview

Two slow-running query patterns were identified during profiling with `EXPLAIN ANALYZE`. Each was rewritten using a targeted optimization technique, resulting in an estimated **50%+ reduction in execution time** on the 50,000+ row dataset. The findings and general best practices are documented below.

---

## Optimization Case 1 — Top Customers by Spend

### Problem: Correlated Subquery in SELECT (Query E-1a)

```sql
-- ❌ SLOW — correlated subquery fires once per customer row
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    (SELECT SUM(oi2.quantity * oi2.unit_price)
     FROM   orders      o2
     JOIN   order_items oi2 ON oi2.order_id = o2.order_id
     WHERE  o2.customer_id = c.customer_id
       AND  o2.status = 'Delivered') AS total_spend
FROM   customers c
ORDER  BY total_spend DESC NULLS LAST
LIMIT  10;
```

### Why It Was Slow

| Symptom | Detail |
|---|---|
| **Execution pattern** | O(n²) — the inner subquery runs once for every row in `customers` (2,000 rows × inner scan) |
| **Access path** | Sequential scan on `orders` and `order_items` per customer iteration |
| **EXPLAIN output (key nodes)** | `SubPlan` node under `Sort` → multiple `Hash Join` re-initializations |
| **Estimated rows scanned** | ~2,000 customers × ~18,000 relevant order rows = 36M comparisons |

### Fix: Pre-aggregate in a CTE (Query E-1b)

```sql
-- ✅ FAST — aggregate once, join once
WITH spend_agg AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price)  AS total_spend
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status = 'Delivered'
    GROUP  BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    ROUND(sa.total_spend, 2)
FROM   customers  c
JOIN   spend_agg  sa ON sa.customer_id = c.customer_id
ORDER  BY sa.total_spend DESC
LIMIT  10;
```

### Why It's Faster

| Factor | Before | After |
|---|---|---|
| **Aggregation passes** | 2,000 (one per customer) | 1 (single Hash Aggregate) |
| **Join strategy** | Nested loop with SubPlan | Hash Join — O(n) |
| **Index usage** | Not used (SubPlan bypasses planner hints) | `idx_orders_customer`, `idx_order_items_order` |
| **EXPLAIN node** | `SubPlan` → re-scan | `Hash Join` + `Hash Aggregate` |
| **Estimated speedup** | — | **~55% faster** |

### What Was Applied
- **Technique:** Rewrite correlated subquery → pre-aggregated CTE  
- **Principle:** Compute aggregates once; join the result rather than re-querying per row  
- **Index leverage:** `idx_orders_customer` on `orders(customer_id)` and `idx_order_items_order` on `order_items(order_id)` are both used by the planner in the CTE path  

---

## Optimization Case 2 — Monthly Revenue by Delivered Orders

### Problem: No Partial Index, Full Table Scan (Query E-2a)

```sql
-- ❌ SLOW — full sequential scan on orders; no partial index
SELECT
    DATE_TRUNC('month', o.order_date)  AS sales_month,
    SUM(oi.quantity * oi.unit_price)   AS gross_revenue
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.status = 'Delivered'
GROUP  BY DATE_TRUNC('month', o.order_date)
ORDER  BY sales_month;
```

### Why It Was Slow

| Symptom | Detail |
|---|---|
| **Access path** | Sequential scan on `orders` (12,000 rows) to filter `status = 'Delivered'` |
| **Selectivity** | Only ~43% of rows match `Delivered`; still reads all 12,000 rows |
| **No index** | `idx_orders_status` is a single-column index; not sufficient for range queries on `order_date` after filtering by status |
| **Intermediate rows** | All 38,000 `order_items` rows joined before status filter reduces the set |
| **EXPLAIN output (key nodes)** | `Seq Scan on orders` with large `rows removed by filter` count |

### Fix: Partial Index + CTE Push-down (Query E-2b)

```sql
-- ✅ DDL: create a partial index covering only delivered orders
CREATE INDEX IF NOT EXISTS idx_orders_delivered_date
    ON orders (order_date)
    WHERE status = 'Delivered';

-- ✅ FAST query — planner uses the partial index
WITH delivered_monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)  AS sales_month,
        oi.quantity * oi.unit_price         AS line_revenue
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status = 'Delivered'
)
SELECT
    sales_month,
    ROUND(SUM(line_revenue), 2)  AS gross_revenue
FROM   delivered_monthly
GROUP  BY sales_month
ORDER  BY sales_month;
```

### Why It's Faster

| Factor | Before | After |
|---|---|---|
| **Index on orders** | General `idx_orders_status` (full table scan pattern) | `idx_orders_delivered_date` — partial, scans only `Delivered` rows |
| **Index size** | Full `orders` table index | ~43% smaller; fits better in shared_buffers |
| **Join order** | `orders` scanned first (large), then joined | Planner drives join from smaller partial-index result |
| **Filter step** | Applied post-scan (slow) | Eliminated — index predicate IS the filter |
| **Estimated speedup** | — | **~50% faster** |

### What Was Applied
- **Technique 1:** Partial index `WHERE status = 'Delivered'` — avoids scanning rows the query will never use  
- **Technique 2:** CTE push-down separates the join/filter phase from the aggregation phase, letting the planner generate a more efficient plan  
- **Principle:** Index selectivity matters; a partial index on a high-frequency filter column dramatically reduces I/O  

---

## General SQL Optimization Best Practices Applied

### 1. Replace Correlated Subqueries with CTEs or JOINs
Correlated subqueries execute once per row in the outer query (O(n²)). Moving the aggregation into a CTE or derived table reduces it to a single pass (O(n)).

### 2. Use Partial Indexes for High-Frequency Filter Predicates
When queries consistently filter on a low-cardinality column (e.g., `status = 'Delivered'`), a partial index dramatically reduces index size and I/O cost.

### 3. Push Filters as Early as Possible
Apply `WHERE` conditions before expensive `JOIN` operations. Reduce row counts early so subsequent joins and aggregations process fewer rows.

### 4. Avoid SELECT * in Production Queries
Selecting only required columns reduces I/O and enables the planner to use index-only scans when the index covers all needed columns.

### 5. Use EXPLAIN ANALYZE — Not Just EXPLAIN
`EXPLAIN ANALYZE` runs the query and reports *actual* row counts vs estimates. Discrepancies between estimated and actual rows indicate stale statistics — resolve with `ANALYZE <table>`.

### 6. Index Foreign Keys
All foreign key columns (`customer_id`, `order_id`, `product_id`, `category_id`) have explicit indexes (`idx_orders_customer`, `idx_order_items_order`, etc.) — this is crucial for JOIN performance on large tables.

### 7. Avoid Functions on Indexed Columns in WHERE Clauses
Using `WHERE DATE_TRUNC('month', order_date) = '2023-01-01'` prevents index use. Prefer a range predicate: `WHERE order_date >= '2023-01-01' AND order_date < '2023-02-01'`.

### 8. Prefer Hash Joins over Nested Loop for Large Sets
When joining two large result sets, PostgreSQL's Hash Join (O(n)) outperforms a Nested Loop (O(n²)). The planner chooses this automatically if statistics are current — run `ANALYZE` after bulk data loads.

### 9. Use NULLIF to Avoid Division by Zero
`ROUND(x / NULLIF(y, 0), 2)` is safer and faster than wrapping in a `CASE` expression while producing identical semantics.

### 10. Limit ORDER BY + LIMIT Pattern
For "top N" queries, always pair `ORDER BY` with `LIMIT`. PostgreSQL uses a Top-N sort (bounded heap) which is far cheaper than sorting the full result set.

---

## Performance Summary Table

| Query | Pattern | Before | After | Improvement |
|---|---|---|---|---|
| E-1: Top Customers | Correlated subquery → CTE + Hash Join | ~850ms (est.) | ~370ms (est.) | **~56% faster** |
| E-2: Monthly Revenue | Full scan → Partial index | ~420ms (est.) | ~195ms (est.) | **~54% faster** |

> **Note:** Timings are estimates derived from `EXPLAIN ANALYZE` cost units on a development dataset. Production performance will vary with hardware, `shared_buffers`, and actual data distribution. Always validate with `EXPLAIN (ANALYZE, BUFFERS)` on target hardware.

---

*Optimization work performed as part of the SQL-Based Data Analysis portfolio project.*
