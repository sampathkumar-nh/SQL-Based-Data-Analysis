# SQL-Based Data Analysis

> **Tools:** SQL | PostgreSQL | CTEs | Window Functions | Joins  
> **Domain:** Retail Sales — Customers, Orders, Products  
> **Scale:** 50,000+ rows | 6 Tables | 18 Complex Queries

## Project Overview
Authored 15+ complex SQL queries using joins, subqueries, CTEs, and window functions to interrogate structured datasets of 50,000+ rows across 3 business domains. Optimized slow-running queries achieving a 50% reduction in execution time, significantly improving reporting efficiency.

## Key Features
- 6 normalized tables with proper PKs, FKs, and indexes (star schema)
- 18 production-quality queries across 5 technique groups
- Query optimization with before/after EXPLAIN ANALYZE comparison
- 50%+ execution time reduction documented with real examples

## Files
| File | Description |
|---|---|
| `01_schema_and_data.sql` | DDL + 52,000 rows generated via cross joins (PostgreSQL) |
| `02_analysis_queries.sql` | 18 queries — JOINs, Subqueries, CTEs, Window Functions, Optimization |
| `Query_Optimization_Notes.md` | Before/after query optimization with 50%+ speed improvement |
| `Business_Insights.md` | Business report from SQL findings |
| `project_summary.html` | Portfolio one-pager (open in browser) |

## Database Schema
```
regions ──< customers ──< orders ──< order_items >── products >── categories
```

## Query Techniques Covered
| Group | Technique | Queries |
|---|---|---|
| A | JOINs (INNER, LEFT, multi-table) | 3 |
| B | Subqueries (correlated, FROM, EXISTS) | 3 |
| C | CTEs (single, recursive, multi-CTE chain) | 3 |
| D | Window Functions (RANK, LAG/LEAD, SUM OVER, NTILE) | 4 |
| E | Query Optimization (slow vs fast with EXPLAIN) | 2 |
| F | Bonus analytical queries | 3 |

## How to Use
1. Install [PostgreSQL](https://www.postgresql.org/download/) + [pgAdmin](https://www.pgadmin.org/) (both free)
2. Create a database: `CREATE DATABASE retail_analytics;`
3. Run `01_schema_and_data.sql` to create tables and populate data
4. Run queries from `02_analysis_queries.sql` one by one

## Business Impact
- Interrogated **50,000+ rows** across 3 business domains
- Achieved **50% query execution time reduction** through optimization
- Delivered actionable insights on top products, customer segments, regional revenue
