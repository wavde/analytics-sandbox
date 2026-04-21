-- Problem 07: Month-Over-Month Revenue Growth
--
-- Scenario
-- --------
-- Stripe's finance team prepares a monthly merchant-revenue update for
-- investors: total processed volume by month, the absolute change vs the
-- prior month, and the percentage growth. The output feeds board charts
-- and the narrative in the quarterly letter, so the numbers need to match
-- cleanly even in months with unusual edge cases (new-merchant onboarding
-- months, zero-revenue months after a region launch).
--
-- Prompt
-- ------
-- Given an `orders` table, compute monthly revenue and the month-over-month
-- absolute change and percentage growth. Return NULL (not an error, not
-- zero) for the first month, when no prior month exists.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: MoM / WoW / YoY growth is the spine of every business
--                     review, investor update, and trend chart. The same
--                     pattern applies across revenue, users, and usage.
-- Skill demonstrated:  LAG over a time-ordered aggregate, defensive
--                      division against zero-revenue months, and awareness
--                      of missing-month calendar spines.
-- Business impact:     A divide-by-zero or dropped month in a growth table
--                      shows up directly in executive and external-facing
--                      materials — the kind of error that forces a public
--                      correction.

-- Schema
-- CREATE TABLE orders (
--     order_id    BIGINT,
--     ordered_at  TIMESTAMP,
--     revenue     NUMERIC
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Aggregate revenue to month granularity with DATE_TRUNC.
-- Step 2: Use LAG over month order to grab the previous month's revenue.
-- Step 3: Compute absolute change and percent growth, wrapping the divisor
--         in NULLIF to return NULL instead of erroring when the previous
--         month is zero or missing.
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
-- Pitfalls worth calling out
-- ============================================================================
-- 1. NULLIF(prev, 0) prevents a divide-by-zero in months right after a
--    zero-revenue month. Rare, but real for new regions or new products.
-- 2. A month with no orders at all will silently be absent from the result.
--    When every month must appear (filled with zero), join against a
--    generated calendar spine — generate_series in Postgres, sequence() in
--    Spark, an explicit dim_date in a warehouse.
-- 3. Timezone: DATE_TRUNC uses the session timezone. For a global business,
--    standardise on one canonical TZ (usually UTC) and cast ordered_at
--    before truncating — otherwise cross-year boundaries drift by a day.
