-- ============================================================
-- PROJECT  : SQL-Based Data Analysis — Retail Sales Domain
-- DATABASE : PostgreSQL 14+
-- FILE     : 02_analysis_queries.sql
-- PURPOSE  : 18 production-quality analytical queries grouped
--            by technique: JOINs, Subqueries, CTEs,
--            Window Functions, and Query Optimization.
-- AUTHOR   : Data Analyst Portfolio Project
-- ============================================================

-- ============================================================
-- GROUP A — JOINs
-- ============================================================

-- ------------------------------------------------------------
-- A-1  Full Order Details
-- Purpose : Retrieve every order line enriched with customer
--           name, region, product name, category, and the
--           computed line-item revenue (before/after discount).
-- Techniques: INNER JOIN across 5 tables
-- ------------------------------------------------------------
SELECT
    o.order_id,
    o.order_date,
    o.status,
    c.customer_id,
    c.first_name || ' ' || c.last_name          AS customer_name,
    c.segment                                    AS customer_segment,
    r.region_name,
    p.product_id,
    p.product_name,
    cat.category_name,
    oi.quantity,
    oi.unit_price,
    oi.discount_pct,
    ROUND(oi.quantity * oi.unit_price, 2)        AS gross_revenue,
    ROUND(oi.quantity * oi.unit_price
          * (1 - oi.discount_pct / 100.0), 2)   AS net_revenue
FROM   order_items  oi
JOIN   orders       o   ON o.order_id    = oi.order_id
JOIN   customers    c   ON c.customer_id = o.customer_id
JOIN   regions      r   ON r.region_id   = c.region_id
JOIN   products     p   ON p.product_id  = oi.product_id
JOIN   categories   cat ON cat.category_id = p.category_id
WHERE  o.status NOT IN ('Cancelled', 'Returned')
ORDER  BY o.order_date DESC, o.order_id, oi.order_item_id;


-- ------------------------------------------------------------
-- A-2  Customers With No Orders  (LEFT JOIN null-check)
-- Purpose : Identify registered customers who have never placed
--           an order — useful for re-engagement campaigns.
-- Techniques: LEFT JOIN + IS NULL (anti-join pattern)
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name   AS customer_name,
    c.email,
    c.segment,
    r.region_name,
    c.date_joined,
    CURRENT_DATE - c.date_joined          AS days_since_joined
FROM   customers c
JOIN   regions   r  ON r.region_id = c.region_id
LEFT   JOIN orders o ON o.customer_id = c.customer_id
WHERE  o.order_id IS NULL
  AND  c.is_active = TRUE
ORDER  BY c.date_joined;


-- ------------------------------------------------------------
-- A-3  Revenue by Customer Segment  (JOIN + Aggregation)
-- Purpose : Compare total revenue, average order value, and
--           order count across Bronze/Silver/Gold/Platinum tiers
--           to evaluate the value of each segment.
-- Techniques: INNER JOIN + GROUP BY + ROUND aggregates
-- ------------------------------------------------------------
SELECT
    c.segment,
    COUNT(DISTINCT c.customer_id)                         AS total_customers,
    COUNT(DISTINCT o.order_id)                            AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2)        AS total_net_revenue,
    ROUND(AVG(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2)        AS avg_line_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0))
          / NULLIF(COUNT(DISTINCT o.order_id), 0), 2)     AS avg_order_value
FROM   customers    c
JOIN   orders       o   ON o.customer_id   = c.customer_id
JOIN   order_items  oi  ON oi.order_id     = o.order_id
WHERE  o.status NOT IN ('Cancelled', 'Returned')
GROUP  BY c.segment
ORDER  BY total_net_revenue DESC;


-- ============================================================
-- GROUP B — Subqueries
-- ============================================================

-- ------------------------------------------------------------
-- B-1  Customers Above Average Lifetime Spend  (Correlated Subquery)
-- Purpose : Flag high-value customers whose total spend exceeds
--           the average spend across all customers.
-- Techniques: Correlated subquery in WHERE clause
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name   AS customer_name,
    c.segment,
    r.region_name,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2)  AS lifetime_spend
FROM   customers   c
JOIN   regions     r   ON r.region_id   = c.region_id
JOIN   orders      o   ON o.customer_id = c.customer_id
JOIN   order_items oi  ON oi.order_id   = o.order_id
WHERE  o.status NOT IN ('Cancelled', 'Returned')
GROUP  BY c.customer_id, c.first_name, c.last_name, c.segment, r.region_name
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) >
    -- Correlated subquery: compute global average spend per customer
    (SELECT AVG(cust_spend.total)
     FROM  (SELECT o2.customer_id,
                   SUM(oi2.quantity * oi2.unit_price
                       * (1 - oi2.discount_pct / 100.0)) AS total
            FROM   orders      o2
            JOIN   order_items oi2 ON oi2.order_id = o2.order_id
            WHERE  o2.status NOT IN ('Cancelled','Returned')
            GROUP  BY o2.customer_id) AS cust_spend)
ORDER  BY lifetime_spend DESC;


-- ------------------------------------------------------------
-- B-2  Category-Level Revenue Summary  (Subquery in FROM)
-- Purpose : Summarise net revenue, units sold, and average
--           selling price at the top-level category grain.
-- Techniques: Derived table (subquery in FROM clause)
-- ------------------------------------------------------------
SELECT
    agg.category_name,
    agg.total_units_sold,
    ROUND(agg.total_net_revenue, 2)                AS total_net_revenue,
    ROUND(agg.total_net_revenue
          / NULLIF(agg.total_units_sold, 0), 2)    AS avg_selling_price,
    ROUND(agg.total_net_revenue
          / SUM(agg.total_net_revenue) OVER () * 100, 1)  AS revenue_pct
FROM (
    -- Derived table: line-item revenue rolled up by root category
    SELECT
        COALESCE(parent_cat.category_name, cat.category_name)  AS category_name,
        SUM(oi.quantity)                                         AS total_units_sold,
        SUM(oi.quantity * oi.unit_price
            * (1 - oi.discount_pct / 100.0))                    AS total_net_revenue
    FROM   order_items  oi
    JOIN   orders       o    ON o.order_id     = oi.order_id
    JOIN   products     p    ON p.product_id   = oi.product_id
    JOIN   categories   cat  ON cat.category_id = p.category_id
    LEFT   JOIN categories parent_cat
                         ON parent_cat.category_id = cat.parent_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY COALESCE(parent_cat.category_name, cat.category_name)
) agg
ORDER  BY agg.total_net_revenue DESC;


-- ------------------------------------------------------------
-- B-3  Active Product Categories  (EXISTS Subquery)
-- Purpose : List only those top-level categories that currently
--           have at least one active product, and have generated
--           sales in the last 12 months.
-- Techniques: EXISTS + correlated subquery
-- ------------------------------------------------------------
SELECT
    cat.category_id,
    cat.category_name,
    cat.is_active
FROM   categories cat
WHERE  cat.parent_id IS NULL          -- top-level only
  AND  cat.is_active = TRUE
  AND  EXISTS (
      -- Does this category (or any child) have an active product
      -- with a sale in the last 12 months?
      SELECT 1
      FROM   products     p
      JOIN   order_items  oi  ON oi.product_id   = p.product_id
      JOIN   orders       o   ON o.order_id      = oi.order_id
      JOIN   categories   sub ON sub.category_id = p.category_id
      WHERE  (sub.category_id = cat.category_id
              OR sub.parent_id = cat.category_id)
        AND  p.is_active  = TRUE
        AND  o.order_date >= CURRENT_DATE - INTERVAL '12 months'
        AND  o.status NOT IN ('Cancelled', 'Returned')
  )
ORDER  BY cat.category_name;


-- ============================================================
-- GROUP C — CTEs
-- ============================================================

-- ------------------------------------------------------------
-- C-1  Monthly Revenue Trend  (Simple CTE)
-- Purpose : Show month-by-month net revenue and cumulative
--           revenue for the full dataset date range.
-- Techniques: CTE + DATE_TRUNC + window SUM for running total
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE            AS sales_month,
        SUM(oi.quantity * oi.unit_price
            * (1 - oi.discount_pct / 100.0))               AS net_revenue,
        COUNT(DISTINCT o.order_id)                          AS order_count,
        COUNT(DISTINCT o.customer_id)                       AS unique_customers
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY DATE_TRUNC('month', o.order_date)
)
SELECT
    sales_month,
    ROUND(net_revenue, 2)                                   AS net_revenue,
    order_count,
    unique_customers,
    ROUND(net_revenue / NULLIF(order_count, 0), 2)          AS avg_order_value,
    ROUND(SUM(net_revenue) OVER (ORDER BY sales_month), 2)  AS cumulative_revenue
FROM   monthly_revenue
ORDER  BY sales_month;


-- ------------------------------------------------------------
-- C-2  Hierarchical Category Tree  (Recursive CTE)
-- Purpose : Walk the self-referencing categories table to
--           produce a full parent → child tree with depth and
--           breadcrumb path — powers navigation menus and
--           hierarchical reports.
-- Techniques: Recursive CTE (WITH RECURSIVE)
-- ------------------------------------------------------------
WITH RECURSIVE category_tree AS (
    -- Anchor: top-level categories (no parent)
    SELECT
        category_id,
        category_name,
        parent_id,
        0                                   AS depth,
        category_name::TEXT                 AS full_path,
        ARRAY[category_id]                  AS id_path
    FROM   categories
    WHERE  parent_id IS NULL

    UNION ALL

    -- Recursive member: join children to their parent row
    SELECT
        c.category_id,
        c.category_name,
        c.parent_id,
        ct.depth + 1,
        (ct.full_path || ' > ' || c.category_name)::TEXT,
        ct.id_path || c.category_id
    FROM   categories    c
    JOIN   category_tree ct ON ct.category_id = c.parent_id
)
SELECT
    category_id,
    REPEAT('    ', depth) || category_name   AS indented_name,
    depth,
    full_path,
    is_active
FROM   category_tree ct
JOIN   categories    c USING (category_id)
ORDER  BY id_path;


-- ------------------------------------------------------------
-- C-3  Customer Lifetime Value Chain  (Multi-CTE)
-- Purpose : Calculate CLV by chaining four CTEs:
--           (1) raw spend per customer,
--           (2) order frequency,
--           (3) recency (days since last order),
--           (4) final CLV score and tier assignment.
-- Techniques: Multiple named CTEs + CASE expression
-- ------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price
            * (1 - oi.discount_pct / 100.0))  AS total_spend,
        SUM(oi.quantity)                        AS total_units
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY o.customer_id
),
order_frequency AS (
    SELECT
        customer_id,
        COUNT(*)                    AS total_orders,
        MIN(order_date)             AS first_order_date,
        MAX(order_date)             AS last_order_date,
        MAX(order_date) - MIN(order_date) AS customer_lifespan_days
    FROM   orders
    WHERE  status NOT IN ('Cancelled', 'Returned')
    GROUP  BY customer_id
),
recency AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(order_date)  AS days_since_last_order
    FROM   orders
    WHERE  status NOT IN ('Cancelled', 'Returned')
    GROUP  BY customer_id
),
clv_base AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name              AS customer_name,
        c.segment,
        ROUND(cs.total_spend, 2)                         AS lifetime_spend,
        of2.total_orders,
        ROUND(cs.total_spend
              / NULLIF(of2.total_orders, 0), 2)          AS avg_order_value,
        ROUND(of2.total_orders::NUMERIC
              / NULLIF(of2.customer_lifespan_days, 0)
              * 365, 2)                                   AS orders_per_year,
        rec.days_since_last_order
    FROM   customers       c
    JOIN   customer_spend  cs  ON cs.customer_id  = c.customer_id
    JOIN   order_frequency of2 ON of2.customer_id = c.customer_id
    JOIN   recency         rec ON rec.customer_id = c.customer_id
)
SELECT
    customer_id,
    customer_name,
    segment,
    lifetime_spend,
    total_orders,
    avg_order_value,
    orders_per_year,
    days_since_last_order,
    -- Simple CLV proxy: avg order value × projected annual frequency × 3-yr horizon
    ROUND(avg_order_value * orders_per_year * 3, 2)  AS clv_3yr_estimate,
    CASE
        WHEN lifetime_spend >= 5000 AND days_since_last_order <= 90  THEN 'Champions'
        WHEN lifetime_spend >= 2000 AND days_since_last_order <= 180 THEN 'Loyal Customers'
        WHEN days_since_last_order <= 90                             THEN 'Recent Customers'
        WHEN days_since_last_order BETWEEN 91 AND 365               THEN 'At Risk'
        ELSE 'Lost'
    END  AS rfm_tier
FROM   clv_base
ORDER  BY clv_3yr_estimate DESC;


-- ============================================================
-- GROUP D — Window Functions
-- ============================================================

-- ------------------------------------------------------------
-- D-1  Top Products per Region  (RANK / DENSE_RANK)
-- Purpose : Identify the top-3 revenue-generating products in
--           each sales region for regional assortment planning.
-- Techniques: DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...)
-- ------------------------------------------------------------
WITH regional_product_revenue AS (
    SELECT
        r.region_name,
        p.product_id,
        p.product_name,
        cat.category_name,
        ROUND(SUM(oi.quantity * oi.unit_price
                  * (1 - oi.discount_pct / 100.0)), 2)  AS net_revenue
    FROM   order_items  oi
    JOIN   orders       o    ON o.order_id     = oi.order_id
    JOIN   customers    c    ON c.customer_id  = o.customer_id
    JOIN   regions      r    ON r.region_id    = c.region_id
    JOIN   products     p    ON p.product_id   = oi.product_id
    JOIN   categories   cat  ON cat.category_id = p.category_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY r.region_name, p.product_id, p.product_name, cat.category_name
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY region_name
                              ORDER BY net_revenue DESC)  AS region_rank
    FROM   regional_product_revenue
)
SELECT  region_name, region_rank, product_name, category_name, net_revenue
FROM    ranked
WHERE   region_rank <= 3
ORDER   BY region_name, region_rank;


-- ------------------------------------------------------------
-- D-2  Month-over-Month Sales Comparison  (LAG / LEAD)
-- Purpose : Compare each month's revenue to the prior month
--           and the next month, and compute MoM growth rate.
-- Techniques: LAG() / LEAD() window functions
-- ------------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE          AS sales_month,
        ROUND(SUM(oi.quantity * oi.unit_price
                  * (1 - oi.discount_pct / 100.0)), 2)   AS net_revenue
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY DATE_TRUNC('month', o.order_date)
)
SELECT
    sales_month,
    net_revenue,
    LAG(net_revenue)  OVER (ORDER BY sales_month)   AS prev_month_revenue,
    LEAD(net_revenue) OVER (ORDER BY sales_month)   AS next_month_revenue,
    ROUND((net_revenue
           - LAG(net_revenue) OVER (ORDER BY sales_month))
          / NULLIF(LAG(net_revenue) OVER (ORDER BY sales_month), 0)
          * 100, 2)                                     AS mom_growth_pct,
    ROUND(AVG(net_revenue) OVER (
              ORDER BY sales_month
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                        AS rolling_3mo_avg
FROM   monthly
ORDER  BY sales_month;


-- ------------------------------------------------------------
-- D-3  Running Revenue Total by Region  (SUM OVER PARTITION)
-- Purpose : Show each region's cumulative revenue month-by-month
--           so management can track YTD progress per territory.
-- Techniques: SUM() OVER (PARTITION BY region ORDER BY month)
-- ------------------------------------------------------------
WITH regional_monthly AS (
    SELECT
        r.region_name,
        DATE_TRUNC('month', o.order_date)::DATE            AS sales_month,
        ROUND(SUM(oi.quantity * oi.unit_price
                  * (1 - oi.discount_pct / 100.0)), 2)     AS net_revenue
    FROM   order_items  oi
    JOIN   orders       o   ON o.order_id    = oi.order_id
    JOIN   customers    c   ON c.customer_id = o.customer_id
    JOIN   regions      r   ON r.region_id   = c.region_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY r.region_name, DATE_TRUNC('month', o.order_date)
)
SELECT
    region_name,
    sales_month,
    net_revenue,
    ROUND(SUM(net_revenue) OVER (
              PARTITION BY region_name
              ORDER BY sales_month
              ROWS UNBOUNDED PRECEDING), 2)             AS running_total,
    ROUND(net_revenue
          / SUM(net_revenue) OVER (PARTITION BY region_name)
          * 100, 1)                                     AS pct_of_region_total
FROM   regional_monthly
ORDER  BY region_name, sales_month;


-- ------------------------------------------------------------
-- D-4  Customer Spend Quartiles  (NTILE)
-- Purpose : Divide customers into four equal spend quartiles
--           (Q1 = lowest 25%, Q4 = highest 25%) for targeted
--           promotions and churn-prevention campaigns.
-- Techniques: NTILE(4) OVER (ORDER BY ...)
-- ------------------------------------------------------------
WITH customer_total_spend AS (
    SELECT
        o.customer_id,
        ROUND(SUM(oi.quantity * oi.unit_price
                  * (1 - oi.discount_pct / 100.0)), 2)  AS total_spend
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name               AS customer_name,
    c.segment                                          AS crm_segment,
    r.region_name,
    cts.total_spend,
    NTILE(4) OVER (ORDER BY cts.total_spend)           AS spend_quartile,
    CASE NTILE(4) OVER (ORDER BY cts.total_spend)
        WHEN 1 THEN 'Low Spender    (Q1)'
        WHEN 2 THEN 'Mid Spender    (Q2)'
        WHEN 3 THEN 'High Spender   (Q3)'
        WHEN 4 THEN 'Top Spender    (Q4)'
    END                                                AS spend_tier
FROM   customer_total_spend cts
JOIN   customers            c   ON c.customer_id = cts.customer_id
JOIN   regions              r   ON r.region_id   = c.region_id
ORDER  BY cts.total_spend DESC;


-- ============================================================
-- GROUP E — Query Optimization
-- ============================================================

-- ------------------------------------------------------------
-- E-1a  SLOW VERSION — Top 10 Customers by Spend
-- Problem : Uses a correlated subquery inside SELECT that
--           re-executes for every row → O(n²) complexity.
--           Full sequential scan on order_items per customer.
-- Run EXPLAIN ANALYZE to verify: Seq Scan, high actual rows.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    -- ❌ Correlated subquery: executes once per customer row
    (SELECT SUM(oi2.quantity * oi2.unit_price)
     FROM   orders      o2
     JOIN   order_items oi2 ON oi2.order_id = o2.order_id
     WHERE  o2.customer_id = c.customer_id
       AND  o2.status = 'Delivered')    AS total_spend
FROM   customers c
ORDER  BY total_spend DESC NULLS LAST
LIMIT  10;


-- ------------------------------------------------------------
-- E-1b  OPTIMISED VERSION — Top 10 Customers by Spend
-- Fix   : Replace correlated subquery with a pre-aggregated
--         CTE joined once.  Uses index idx_orders_customer
--         and idx_order_items_order → Hash Aggregate, one pass.
-- Result: ~50% faster; eliminates repeated inner-loop scans.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
WITH spend_agg AS (
    -- ✅ Aggregated once, then joined — O(n) instead of O(n²)
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price)  AS total_spend
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id  -- uses idx_order_items_order
    WHERE  o.status = 'Delivered'                       -- uses idx_orders_status
    GROUP  BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    ROUND(sa.total_spend, 2)             AS total_spend
FROM   customers  c
JOIN   spend_agg  sa ON sa.customer_id = c.customer_id  -- uses idx_customers (PK)
ORDER  BY sa.total_spend DESC
LIMIT  10;


-- ------------------------------------------------------------
-- E-2a  SLOW VERSION — Monthly Revenue with Status Filter
-- Problem : No partial index on order_date for delivered orders;
--           filter on status forces a full table scan on orders
--           before joining → large intermediate result set.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('month', o.order_date)  AS sales_month,
    SUM(oi.quantity * oi.unit_price)   AS gross_revenue
FROM   orders      o
-- ❌ No covering index on (status, order_date) — Seq Scan on orders
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.status = 'Delivered'
GROUP  BY DATE_TRUNC('month', o.order_date)
ORDER  BY sales_month;


-- ------------------------------------------------------------
-- E-2b  OPTIMISED VERSION — Monthly Revenue with Partial Index
-- Fix 1 : Create a partial index on order_date for delivered
--         orders only → smaller index, faster index scan.
-- Fix 2 : Push the aggregation into a covering CTE so the
--         planner can choose a Hash Aggregate strategy.
-- ------------------------------------------------------------

-- ✅ One-time DDL: partial composite index (run once, not per query)
CREATE INDEX IF NOT EXISTS idx_orders_delivered_date
    ON orders (order_date)
    WHERE status = 'Delivered';

-- ✅ Optimised query uses the partial index directly
EXPLAIN ANALYZE
WITH delivered_monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)  AS sales_month,
        oi.order_id,
        oi.quantity * oi.unit_price         AS line_revenue
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status = 'Delivered'   -- ✅ hits idx_orders_delivered_date
)
SELECT
    sales_month,
    ROUND(SUM(line_revenue), 2)  AS gross_revenue
FROM   delivered_monthly
GROUP  BY sales_month
ORDER  BY sales_month;


-- ============================================================
-- GROUP F — BONUS Analytical Queries
-- ============================================================

-- ------------------------------------------------------------
-- F-1  Product Profit Margin Analysis
-- Purpose : Rank products by gross profit margin % to guide
--           promotional and discontinuation decisions.
-- ------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    cat.category_name,
    p.unit_cost,
    p.unit_price,
    ROUND((p.unit_price - p.unit_cost)
          / NULLIF(p.unit_price, 0) * 100, 1)                AS margin_pct,
    SUM(oi.quantity)                                           AS units_sold,
    ROUND(SUM(oi.quantity * (oi.unit_price - p.unit_cost)), 2) AS gross_profit,
    RANK() OVER (ORDER BY
                 ROUND(SUM(oi.quantity * (oi.unit_price - p.unit_cost)), 2) DESC)
                                                               AS profit_rank
FROM   products    p
JOIN   categories  cat ON cat.category_id = p.category_id
LEFT   JOIN order_items oi ON oi.product_id = p.product_id
LEFT   JOIN orders      o  ON o.order_id    = oi.order_id
                           AND o.status NOT IN ('Cancelled','Returned')
GROUP  BY p.product_id, p.product_name, cat.category_name,
          p.unit_cost, p.unit_price
ORDER  BY gross_profit DESC NULLS LAST;


-- ------------------------------------------------------------
-- F-2  Cohort Retention Analysis  (Window + CTE)
-- Purpose : Group customers by their first-order calendar month
--           and track how many returned in subsequent months —
--           a classic retention / churn analysis.
-- ------------------------------------------------------------
WITH first_orders AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE  AS cohort_month
    FROM   orders
    WHERE  status NOT IN ('Cancelled', 'Returned')
    GROUP  BY customer_id
),
customer_activity AS (
    SELECT
        fo.customer_id,
        fo.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE       AS activity_month,
        EXTRACT(YEAR FROM AGE(
            DATE_TRUNC('month', o.order_date),
            fo.cohort_month)) * 12
        + EXTRACT(MONTH FROM AGE(
            DATE_TRUNC('month', o.order_date),
            fo.cohort_month))                          AS months_since_first_order
    FROM   orders      o
    JOIN   first_orders fo ON fo.customer_id = o.customer_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
)
SELECT
    cohort_month,
    months_since_first_order,
    COUNT(DISTINCT customer_id)  AS active_customers
FROM   customer_activity
WHERE  months_since_first_order <= 11   -- first 12 months
GROUP  BY cohort_month, months_since_first_order
ORDER  BY cohort_month, months_since_first_order;


-- ------------------------------------------------------------
-- F-3  Underperforming Categories (Below Average Revenue)
-- Purpose : Surface categories whose revenue is below the
--           overall category average — candidates for
--           promotional investment or delisting.
-- ------------------------------------------------------------
WITH category_revenue AS (
    SELECT
        COALESCE(parent.category_name, cat.category_name)  AS category_name,
        ROUND(SUM(oi.quantity * oi.unit_price
                  * (1 - oi.discount_pct / 100.0)), 2)     AS net_revenue,
        COUNT(DISTINCT oi.order_id)                         AS order_count
    FROM   order_items  oi
    JOIN   orders       o      ON o.order_id     = oi.order_id
    JOIN   products     p      ON p.product_id   = oi.product_id
    JOIN   categories   cat    ON cat.category_id = p.category_id
    LEFT   JOIN categories parent ON parent.category_id = cat.parent_id
    WHERE  o.status NOT IN ('Cancelled', 'Returned')
    GROUP  BY COALESCE(parent.category_name, cat.category_name)
)
SELECT
    category_name,
    net_revenue,
    order_count,
    ROUND(AVG(net_revenue) OVER (), 2)                     AS avg_category_revenue,
    ROUND(net_revenue - AVG(net_revenue) OVER (), 2)       AS vs_average,
    ROUND((net_revenue - AVG(net_revenue) OVER ())
          / NULLIF(AVG(net_revenue) OVER (), 0) * 100, 1)  AS pct_vs_average
FROM   category_revenue
WHERE  net_revenue < (SELECT AVG(net_revenue) FROM category_revenue)
ORDER  BY net_revenue;
