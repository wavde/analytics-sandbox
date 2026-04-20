-- Problem 09: 30-day rolling unique active users
--
-- You have an `events` table with (user_id, event_time). Produce a time
-- series of "trailing-30-day unique active users" (MAU-like) at *daily*
-- resolution.
--
-- This is deceptively hard: COUNT(DISTINCT user_id) OVER (30-day window)
-- is NOT supported in standard SQL (most engines refuse distinct in
-- a window frame). You need a different pattern.

-- Schema
-- CREATE TABLE events (
--     user_id     BIGINT,
--     event_time  TIMESTAMP
-- );

-- ============================================================================
-- Solution A: self-join per report-day (exact, expensive)
-- ============================================================================
-- O(N x 30) scan. Works at small/medium scale.
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
-- Solution B: additive counting (for billion-row data)
-- ============================================================================
-- Trick: for each user's activity, expand to the 30-day "contribution"
-- window during which THAT user is counted. Then a sum counts unique-user-days
-- per report date; to get unique users, you need to join on *first* appearance
-- within each trailing window. The clean scalable answer uses HyperLogLog
-- (APPROX_COUNT_DISTINCT in BigQuery/Spark) over a windowed frame --
-- approximate but cheap and monotone:
--
--   SELECT report_date,
--          APPROX_COUNT_DISTINCT(user_id) OVER (
--              ORDER BY report_date
--              RANGE BETWEEN INTERVAL 29 DAY PRECEDING AND CURRENT ROW
--          ) AS rolling_30d_mau_est
--   FROM daily_user_events;
--
-- BigQuery has APPROX_COUNT_DISTINCT natively. Spark 3.2+ supports it.
-- DuckDB supports approx_count_distinct but only as an aggregate (not a window).

-- ============================================================================
-- What interviewers are testing
-- ============================================================================
-- 1. Do you know COUNT(DISTINCT ...) OVER is not allowed in portable SQL?
-- 2. Can you articulate the scalability tradeoff (Sol A exact vs Sol B HLL)?
-- 3. Do you default to the exact answer and only reach for approximation
--    when the data requires it?
