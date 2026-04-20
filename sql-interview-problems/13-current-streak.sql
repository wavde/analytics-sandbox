-- Problem 13: Current Active Streak Per User
--
-- Given a `daily_activity` table (user_id, activity_date), return each user's
-- CURRENT active streak — the number of consecutive days ending at their
-- most recent activity. A user with gaps resets the streak at the gap.
--
-- Return: user_id, current_streak_days, streak_start, streak_end.
--
-- Why this is asked: "longest streak" (problem 08) and "current streak" look
-- identical but require different logic. Current streak is the length of the
-- LAST island only, and the most recent active day must itself be recent
-- (otherwise the "current" streak is zero).

-- Schema
-- CREATE TABLE daily_activity (user_id BIGINT, activity_date DATE,
--                              PRIMARY KEY (user_id, activity_date));

-- ============================================================================
-- Solution: gaps-and-islands, take the LAST island per user
-- ============================================================================
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
-- product memos you usually want streaks that INCLUDE yesterday/today — i.e.,
-- streak_end >= CURRENT_DATE - INTERVAL '1 day'. Add that filter when you
-- promote this to a daily dashboard:
--
--     WHERE rn = 1 AND streak_end >= CURRENT_DATE - INTERVAL '1 day'
--
-- Otherwise someone who was on a 90-day streak three years ago ranks at the
-- top of your "power users" list forever.
--
-- Spark: replace ::int with CAST(... AS INT); otherwise identical.
