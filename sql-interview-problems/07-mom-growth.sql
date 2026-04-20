-- Problem 07: Month-over-month revenue growth
--
-- Given an `orders` table, compute monthly revenue and the month-over-month
-- % growth, including the absolute and relative change. Handle the first
-- month gracefully (no prior month => NULL, not divide-by-zero).
--
-- Variants: WoW, YoY, trailing-12-month growth. Same pattern.

-- Schema
-- CREATE TABLE orders (
--     order_id    BIGINT,
--     ordered_at  TIMESTAMP,
--     revenue     NUMERIC
-- );

-- ============================================================================
-- Solution: aggregate by month, then LAG
-- ============================================================================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', ordered_at)::DATE AS month_start,
        SUM(revenue)                           AS monthly_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', ordered_at)
)
SELECT
    month_start,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY month_start)          AS prev_month_revenue,
    monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_start)
                                                              AS abs_change,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_start))
             /  NULLIF(LAG(monthly_revenue) OVER (ORDER BY month_start), 0),
        2
    )                                                         AS pct_growth
FROM monthly
ORDER BY month_start;

-- ============================================================================
-- Pitfalls to call out in interviews
-- ============================================================================
-- 1. NULLIF(prev, 0) prevents divide-by-zero in months right after a 0-revenue
--    month (rare but real for new products).
-- 2. A missing calendar month (no orders at all) will silently be absent from
--    the result. If you need every month represented, join against a
--    generated calendar spine (generate_series in Postgres, sequence in Spark).
-- 3. Timezone: DATE_TRUNC uses the session timezone. For a global business,
--    pick one canonical TZ (usually UTC) and cast ordered_at before truncating.
