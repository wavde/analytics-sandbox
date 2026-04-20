# SQL Interview Problems

FAANG-style SQL problems — the kind that show up in analytics interviews at Google, Netflix, Meta, Airbnb, Uber, and Stripe.

Each problem file is self-contained:
1. The prompt
2. The schema
3. The solution (PostgreSQL syntax by default)
4. A short note on the approach and any Spark SQL / dialect differences

## Problems

| # | Problem | Concepts |
|---|---------|----------|
| 01 | [Nth highest salary](01-nth-highest-salary.sql) | Window functions, `DENSE_RANK` |
| 02 | [Session reconstruction](02-sessionization.sql) | Gaps-and-islands, `LAG`, window sums |
| 03 | [Funnel conversion](03-funnel-conversion.sql) | Conditional aggregation, self-joins |
| 04 | [Rolling 7-day retention](04-rolling-retention.sql) | Date arithmetic, `LEFT JOIN` with window |
| 05 | [Median without percentile_cont](05-median-from-scratch.sql) | Window functions, `NTILE` tricks |
