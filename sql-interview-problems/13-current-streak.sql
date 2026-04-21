-- Problem 13: Current Active Streak Per User
--
-- Scenario
-- --------
-- Messaging-app streaks and a learning app's current-streak counter both
-- need the same number: for each user, the length of the run of
-- consecutive active days ending at their most recent activity. Unlike
-- "longest streak ever", a streak resets the moment a day is missed, and
-- only the final island matters.
--
-- Prompt
-- ------
-- Given `daily_activity (user_id, activity_date)`, return each user's
-- current active streak — the number of consecutive days ending at their
-- most recent activity — along with its start and end dates.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Current streak powers user-facing habit features
--                     (streak badges, "don't break your streak" prompts),
--                     which in turn drive DAU retention.
-- Skill demonstrated:  Applying gaps-and-islands and then selecting only
--                      the most recent island per user — distinguishing
--                      "longest ever" from "currently active" semantics.
-- Business impact:     A stale-streak bug keeps long-ago power users at
--                      the top of "active streak" leaderboards forever,
--                      which both misleads internal reporting and
--                      embarrasses the product team when it ships to UI.

-- Schema
-- CREATE TABLE daily_activity (user_id BIGINT, activity_date DATE,
--                              PRIMARY KEY (user_id, activity_date));

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Compute the "date minus row number" island key per user (same
--         trick as problem 08) — consecutive dates share a key, gaps
--         break it.
-- Step 2: Aggregate to one row per (user, island) with length and
--         start/end dates.
-- Step 3: Within each user, keep only the island with the most recent end
--         date — that is the current (or most-recently-ended) streak.
WITH islands AS (
    SELECT
        user_id,
        activity_date,
        activity_date
          - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date))::int
          AS island_key
    FROM daily_activity
),
island_ranges AS (
    SELECT
        user_id,
        island_key,
        MIN(activity_date) AS streak_start,
        MAX(activity_date) AS streak_end,
        COUNT(*)           AS streak_days
    FROM islands
    GROUP BY user_id, island_key
),
latest_island AS (
    SELECT
        user_id,
        streak_start,
        streak_end,
        streak_days,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY streak_end DESC) AS rn
    FROM island_ranges
)
SELECT
    user_id,
    streak_days  AS current_streak_days,
    streak_start,
    streak_end
FROM latest_island
WHERE rn = 1
ORDER BY current_streak_days DESC;

-- ============================================================================
-- The "is it still current?" question
-- ============================================================================
-- The query above returns the last streak regardless of how stale. In real
-- product reporting the streak usually must include yesterday or today —
-- i.e., streak_end >= CURRENT_DATE - INTERVAL '1 day'. Add that filter
-- when promoting this to a daily dashboard:
--
--     WHERE rn = 1 AND streak_end >= CURRENT_DATE - INTERVAL '1 day'
--
-- Without it, a user whose last 90-day streak ended three years ago will
-- rank at the top of a "current power users" list forever.
--
-- Spark: replace ::int with CAST(... AS INT); otherwise identical.
