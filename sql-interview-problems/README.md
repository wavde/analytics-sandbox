# SQL Interview Problems

FAANG-style SQL problems — the kind that show up in analytics interviews at Google, Netflix, Meta, Airbnb, Uber, and Stripe.

Each problem file is self-contained:
1. The prompt
2. The schema
3. The solution (PostgreSQL syntax by default)
4. A short note on the approach and any Spark SQL / dialect differences

## Problems

### Core (window-function fundamentals)

| # | Problem | Concepts |
|---|---------|----------|
| 01 | [Nth highest salary](01-nth-highest-salary.sql) | Window functions, `DENSE_RANK` |
| 02 | [Session reconstruction](02-sessionization.sql) | Gaps-and-islands, `LAG`, window sums |
| 03 | [Funnel conversion](03-funnel-conversion.sql) | Conditional aggregation, self-joins |
| 04 | [Rolling 7-day retention](04-rolling-retention.sql) | Date arithmetic, `LEFT JOIN` with window |
| 05 | [Median without percentile_cont](05-median-from-scratch.sql) | Window functions, `NTILE` tricks |
| 06 | [Top N per group](06-top-n-per-group.sql) | Partitioned window ranking, `DENSE_RANK` vs `ROW_NUMBER` |
| 07 | [Month-over-month growth](07-mom-growth.sql) | `LAG`, `NULLIF`, calendar-spine pitfalls |
| 08 | [Longest active streak](08-longest-streak.sql) | Gaps-and-islands (`date - row_number` trick) |
| 09 | [30-day rolling MAU](09-rolling-30d-mau.sql) | Distinct-count-over-window, HLL approximation tradeoff |
| 10 | [Cohort retention table](10-cohort-retention.sql) | Cohort bucketing, conditional aggregation, pivoted output |

### Advanced (patterns that come up in senior rounds)

| # | Problem | Concepts |
|---|---------|----------|
| 11 | [Last-touch attribution](11-last-touch-attribution.sql) | As-of join, `LEFT JOIN` + window `ROW_NUMBER`, default bucket |
| 12 | [Two-step funnel with timing](12-two-step-funnel-with-timing.sql) | `MIN` per step, chained interval checks, ordering bugs |
| 13 | [Current active streak](13-current-streak.sql) | Gaps-and-islands, take the last island only |
| 14 | [Percentile distribution by group](14-percentiles-by-group.sql) | `PERCENTILE_CONT` vs `DISC`, small-n reliability flag |
| 15 | [Recursive manager hierarchy](15-recursive-hierarchy.sql) | Recursive CTE, cycle defence, up-vs-down traversal |
| 16 | [Co-purchase product pairs](16-copurchase-pairs.sql) | Self-join with `<`, anti-double-count, lift extension |
| 17 | [Top 3-step user paths](17-path-analysis.sql) | `LAG(..., k)`, users vs occurrences distinction |
| 18 | [Event deduplication](18-event-dedup.sql) | Burst-collapse gaps-and-islands, transitive-window subtlety |

Problem files are ~2-3KB each and readable top-to-bottom — prompt, solution, then a "why / pitfalls" section explaining where the pattern generalises and where it breaks.

