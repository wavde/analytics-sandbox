-- Problem 08: Longest consecutive-day active streak per user
--
-- Given a `daily_activity` table (one row per user per active day), return
-- each user's longest streak of consecutive active days.
--
-- This is a classic gaps-and-islands extension. The elegant trick:
--
--     (date - ROW_NUMBER() OVER (PARTITION BY user ORDER BY date))
--     is constant WITHIN a consecutive-day run, and DIFFERENT across runs.
--
-- Why: if dates are consecutive (d, d+1, d+2, ...) and row numbers are
-- (1, 2, 3, ...), then (date - rn) is constant. A one-day gap shifts rn
-- but not date, breaking the constant.

-- Schema
-- CREATE TABLE daily_activity (
--     user_id      BIGINT,
--     active_date  DATE
-- );

-- ============================================================================
-- Solution: the "date minus row number" island key
-- ============================================================================
WITH runs AS (
    SELECT
        user_id,
        active_date,
        active_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY active_date))::INT
            AS island_key
    FROM daily_activity
),
streaks AS (
    SELECT
        user_id,
        island_key,
        COUNT(*) AS streak_length,
        MIN(active_date) AS streak_start,
        MAX(active_date) AS streak_end
    FROM runs
    GROUP BY user_id, island_key
),
longest AS (
    SELECT
        user_id,
        streak_length,
        streak_start,
        streak_end,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY streak_length DESC, streak_start
        ) AS rn
    FROM streaks
)
SELECT user_id, streak_length, streak_start, streak_end
FROM longest
WHERE rn = 1
ORDER BY streak_length DESC;

-- ============================================================================
-- Why this beats LAG + running sum here
-- ============================================================================
-- You can also flag gaps with LAG and running-sum them (see problem 02), but
-- for *strictly consecutive integers or dates*, the "date - row_number"
-- trick is one CTE shorter. For variable-interval sessions (e.g. 30-min
-- timeout), LAG is the right tool. Knowing which to reach for is the signal
-- interviewers are looking for.
--
-- Spark SQL: works identically. MySQL 8+ supports window functions.
