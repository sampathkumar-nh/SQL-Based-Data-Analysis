# Business Insights Report
**Project:** SQL-Based Data Analysis — Retail Sales Domain  
**Prepared by:** Data Analyst Portfolio Project  
**Dataset:** 50,000+ rows across Customers, Orders, Products (PostgreSQL)  
**Report Period:** Full dataset (Jan 2020 – Dec 2023)

---

## Executive Summary

Analysis of the retail sales database (2,000 customers, 12,000 orders, 38,000+ line items) reveals strong Electronics and Clothing performance, an untapped Platinum customer segment, notable regional revenue concentration on the West Coast and North East, and double-digit month-over-month growth in Q4 of each year. Three categories are significantly underperforming relative to the average, and immediate promotional investment or catalogue rationalisation is recommended for those areas.

---

## 1. Top 5 Performing Products

*Source: Query A-1 + F-1 — full-order detail with margin analysis*

| Rank | Product | Category | Units Sold | Net Revenue | Gross Margin % |
|---|---|---|---|---|---|
| 1 | Apple MacBook Pro 14" | Laptops | ~1,450 | ~$2.9M | 40% |
| 2 | Samsung Galaxy S24 Ultra | Smartphones | ~1,320 | ~$1.6M | 32% |
| 3 | Dell XPS 15 Laptop | Laptops | ~1,180 | ~$1.77M | 37% |
| 4 | Herman Miller Aeron Chair | Furniture | ~890 | ~$1.33M | 46% |
| 5 | Apple iPhone 15 Pro | Smartphones | ~1,050 | ~$1.15M | 29% |

**Key takeaway:** Laptops and premium Smartphones dominate revenue. The Herman Miller chair punches above its weight with a 46% gross margin — highest among the top 5. Consider bundling the MacBook Pro with accessories (AirPods, keyboard) to increase basket size.

---

## 2. Revenue by Region

*Source: Query D-3 — running total with SUM() OVER (PARTITION BY region)*

| Region | Annual Net Revenue | % of Total | YoY Trend |
|---|---|---|---|
| West Coast | ~$4.2M | 22% | ↑ +8% |
| North East | ~$3.9M | 21% | ↑ +5% |
| South East | ~$3.4M | 18% | ↔ Flat |
| Mid West | ~$3.1M | 16% | ↑ +3% |
| South West | ~$2.7M | 14% | ↓ -2% |
| Northwest | ~$1.8M | 9% | ↑ +11% |

**Key takeaway:** West Coast and North East account for 43% of total revenue. The Northwest is the fastest-growing region (+11% YoY) from a smaller base — a strategic investment opportunity. South West is the only declining region; investigate whether it reflects competitive pressure, lower customer density, or assortment gaps.

---

## 3. Customer Segments Analysis

*Source: Query A-3 — revenue by customer segment; Query D-4 — NTILE quartile analysis; Query C-3 — CLV multi-CTE*

| Segment | Customers | % of Base | Total Revenue | Avg Order Value | Avg CLV (3yr est.) |
|---|---|---|---|---|---|
| Bronze | ~1,000 | 50% | ~$6.1M | ~$148 | ~$890 |
| Silver | ~600 | 30% | ~$5.3M | ~$192 | ~$1,380 |
| Gold | ~300 | 15% | ~$4.0M | ~$259 | ~$1,920 |
| Platinum | ~100 | 5% | ~$3.6M | ~$388 | ~$3,310 |

**Key takeaway:**
- Platinum customers (5% of base) generate **18% of total revenue** — a classic 80/20 dynamic. Implement a dedicated Platinum loyalty programme with early access and personalised offers to protect this segment.
- Bronze customers represent 50% of the base but only 32% of revenue. A targeted upsell programme converting even 10% of Bronze to Silver would add an estimated **~$185K** in annual revenue.
- NTILE analysis confirms that Q4 spenders (top 25%) account for ~60% of total revenue, validating the disproportionate value of high-spend customers.

---

## 4. Month-over-Month Growth Trend

*Source: Query C-1 — CTE monthly trend; Query D-2 — LAG/LEAD MoM comparison*

| Period | Observation |
|---|---|
| Jan–Mar (Q1) | Consistent soft patch; avg MoM growth –3% to –5% (post-holiday slowdown) |
| Apr–Jun (Q2) | Recovery phase; avg MoM growth +4% to +6% |
| Jul–Sep (Q3) | Steady growth; avg MoM growth +2% to +4%; back-to-school Electronics spike in Aug |
| Oct–Dec (Q4) | Peak season; avg MoM growth +12% to +18%; November shows the single highest monthly revenue |

**Standout months:**
- **November** — highest revenue month each year (~2× the January baseline), driven by Holiday/Black Friday promotions across Electronics and Clothing
- **March** — consistent low point; opportunity for a "Spring Refresh" campaign targeting Home & Garden and Fitness categories

**3-month rolling average trend:** Upward across the full dataset period, confirming sustained organic growth rather than one-off spikes.

---

## 5. Underperforming Categories

*Source: Query F-3 — below-average revenue using window AVG()*

| Category | Net Revenue | vs. Category Average | Gap |
|---|---|---|---|
| Books & Media | ~$0 | –100% | Inactive (no active products) |
| Garden Tools | ~$142K | –68% | Well below average |
| Camping | ~$195K | –55% | Below average |
| Nutrition | ~$218K | –50% | Below average |

**Key takeaway:**
- **Books & Media** is marked inactive — consider fully retiring from the catalogue or relaunching with a digital-first offering.
- **Garden Tools** suffers from low average selling price and infrequent purchases. A seasonal bundle strategy (e.g., "Spring Gardening Kit") could lift basket size.
- **Camping** has solid unit economics (Yeti cooler, REI tent) but low order frequency. Email re-targeting of Q2/Q3 purchasers before the camping season could improve repeatpurchase rates.
- **Nutrition** is a high-frequency, low-price category. Growth requires volume; consider a subscription model for protein and supplement replenishment to smooth revenue.

---

## 6. Key Recommendations

### Immediate Actions (0–90 days)
1. **Launch Platinum Loyalty Programme** — protect and grow the 5% of customers contributing 18% of revenue. Introduce early access, dedicated support, and free shipping threshold.
2. **Q1 Re-engagement Campaign** — deploy a "New Year, New Gear" email series targeting Bronze customers who lapsed since November peak, using discount codes with a 14-day expiry to create urgency.
3. **Garden Tools & Camping Bundles** — introduce 3-item seasonal bundles before Q2 to lift average order value in underperforming categories.

### Medium-Term (90–180 days)
4. **Northwest Territory Investment** — fastest-growing region (+11% YoY) is under-indexed vs. West Coast. Evaluate whether increasing inventory allocation and regional marketing spend there would yield a positive ROI.
5. **Electronics Cross-Sell** — the top 2 revenue categories (Laptops, Smartphones) have natural accessory attachment rates. Implement "Frequently Bought Together" recommendations for Audio and Wearables.
6. **Bronze-to-Silver Upgrade Path** — design a "progress bar" loyalty mechanic showing Bronze customers how close they are to Silver status. Even a 10% conversion rate is worth ~$185K annually.

### Strategic (180+ days)
7. **Nutrition Subscription Model** — model recurring revenue potential for high-replenishment SKUs (protein powder, vitamins). A 500-subscriber base at $50/month = $300K ARR with minimal acquisition cost.
8. **South West Recovery Analysis** — commission a deeper dive into the only declining region: segment by product category, compare customer demographics, and test a localised promotion to diagnose whether the decline is assortment-, price-, or awareness-driven.
9. **Retire Books & Media** — with zero active products and no revenue contribution, maintaining the category adds operational overhead. Archive it and reallocate catalogue management resources.

---

## Analytical Methodology

| Insight | SQL Technique Used |
|---|---|
| Top products by revenue & margin | JOIN × 5 tables + RANK() window function |
| Revenue by region | SUM() OVER (PARTITION BY region) running total |
| Customer segment value | GROUP BY segment + NTILE(4) quartile segmentation |
| CLV estimation | Multi-CTE chain (spend → frequency → recency → CLV) |
| MoM growth | LAG() / LEAD() window functions |
| Underperforming categories | CTE + AVG() OVER () window, filter below average |
| Cohort retention | Recursive date arithmetic + EXTRACT(MONTH FROM AGE()) |

---

*This report was generated from SQL analysis of the retail_analytics PostgreSQL database. All revenue figures are estimates based on synthetic sample data designed to simulate a real-world 50,000+ row retail dataset.*
