-- Problem 08: Longest Consecutive-Day Active Streak Per User
--
-- Scenario
-- --------
-- A learning app's engagement team reports power-user metrics in the form of
-- "longest streak ever": for each learner, the longest run of consecutive
-- active days they have ever completed. The same shape appears in a
-- microblogging app's daily poster stats and in most daily-habit products. The metric
-- feeds retention deep-dives and is a direct proxy for the habit loop the
-- product is trying to build.
--
-- Prompt
-- ------
-- Given `daily_activity (user_id, active_date)` with one row per user per
-- active day, return each user's longest streak of consecutive active days
-- along with its start and end dates.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Longest-streak stats are a standard habit-formation
--                     metric and also show up wherever consecutive-run
--                     logic matters — uptime, subscription continuity,
--                     consecutive wins.
-- Skill demonstrated:  The "date minus row number" island key — the
--                      cleanest way to assign run ids over consecutive
--                      integers or dates without a LAG-and-running-sum.
-- Business impact:     Streak numbers frequently surface in user-facing
--                      UI (badges, leaderboards). A miscounted streak
--                      erodes trust quickly because users verify against
--                      their own memory.

-- Schema
-- CREATE TABLE daily_activity (
--     user_id      BIGINT,
--     active_date  DATE
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Within each user ordered by date, compute an island key equal to
--         active_date minus the row number. For strictly consecutive dates
--         the key is constant; a gap of even one day shifts the row number
--         relative to the date, producing a fresh island key.
-- Step 2: GROUP BY (user_id, island_key) to collapse each run into a row
--         with its length and start/end dates.
-- Step 3: Rank islands within user by length, keeping the longest (ties
--         broken by earliest start).
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
-- When to prefer this over LAG + running sum
-- ============================================================================
-- Gap-flagging with LAG + a running sum (see problem 02) also works, but
-- for *strictly consecutive integers or dates* the "date minus row number"
-- trick is one CTE shorter and avoids the sentinel NULL on the first row.
-- For variable-interval sessions (e.g., 30-minute timeouts) LAG is the
-- right tool; for fixed-interval runs, this one is.
--
-- Spark SQL: works identically; replace ::INT with CAST(... AS INT).
-- MySQL 8+ supports window functions.
