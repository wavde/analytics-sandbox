-- Problem 09: 30-Day Rolling Unique Active Users
--
-- Scenario
-- --------
-- A consumer platform's core growth pipeline publishes daily MAU: for each report day,
-- the count of distinct users who performed at least one qualifying event
-- in the trailing 30 days. The metric is one of the company's top-line
-- numbers, produced at daily resolution across billions of events and
-- reviewed by leadership and the growth org.
--
-- Prompt
-- ------
-- Given `events (user_id, event_time)`, produce a time series at daily
-- resolution of the count of distinct users active in the trailing 30 days.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Trailing-30-day MAU is the canonical engagement
--                     metric for most consumer platforms and one of the
--                     few numbers reported publicly.
-- Skill demonstrated:  Awareness that COUNT(DISTINCT) over a window frame
--                      is not portable SQL, and fluency with the exact vs
--                      approximate tradeoff at scale.
-- Business impact:     A MAU number that is silently approximate (or
--                      silently exact but wildly expensive) drives cost
--                      and trust problems in equal measure — approximate
--                      where stakeholders expect exact, or an overnight
--                      pipeline that misses SLA.

-- Schema
-- CREATE TABLE events (
--     user_id     BIGINT,
--     event_time  TIMESTAMP
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Reduce events to (user_id, active_date) — one row per active user
--         per day.
-- Step 2: For every report day in the data, join every (user, active_date)
--         that falls in the trailing 30-day window.
-- Step 3: Count distinct users per report day.
-- Step 4: For very large data, switch to an approximate distinct count
--         (HyperLogLog) — see solution B.

-- ============================================================================
-- Solution A: self-join per report-day (exact, expensive)
-- ============================================================================
-- O(N x 30) scan. Works at small and medium scale.
WITH user_days AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('day', event_time)::DATE AS active_date
    FROM events
),
report_days AS (
    SELECT DISTINCT active_date AS report_date FROM user_days
)
SELECT
    r.report_date,
    COUNT(DISTINCT ud.user_id) AS rolling_30d_active_users
FROM report_days r
LEFT JOIN user_days ud
  ON ud.active_date BETWEEN r.report_date - INTERVAL '29 days' AND r.report_date
GROUP BY r.report_date
ORDER BY r.report_date;

-- ============================================================================
-- Solution B: approximate distinct count (for billion-row data)
-- ============================================================================
-- COUNT(DISTINCT ...) OVER (range frame) is not standard SQL. The scalable
-- substitute is HyperLogLog via APPROX_COUNT_DISTINCT over a windowed frame
-- — approximate, cheap, and monotone:
--
--   SELECT report_date,
--          APPROX_COUNT_DISTINCT(user_id) OVER (
--              ORDER BY report_date
--              RANGE BETWEEN INTERVAL 29 DAY PRECEDING AND CURRENT ROW
--          ) AS rolling_30d_mau_est
--   FROM daily_user_events;
--
-- BigQuery has APPROX_COUNT_DISTINCT natively. Spark 3.2+ supports it.
-- DuckDB supports approx_count_distinct but only as a plain aggregate, not
-- as a window function.

-- ============================================================================
-- Tradeoff checklist
-- ============================================================================
-- 1. COUNT(DISTINCT ...) OVER is not allowed in portable SQL — don't rely
--    on it even if a single engine accepts it.
-- 2. Solution A is exact but quadratic-ish in the size of the active-user
--    table. At billion-event scale it's a pipeline cost problem.
-- 3. Solution B trades ~1-2% error for sublinear memory. Document the
--    switch — approximate is not exact, and some consumers (finance,
--    external reporting) will refuse it.
