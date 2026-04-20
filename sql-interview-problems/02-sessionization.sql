-- Problem 02: Session Reconstruction
--
-- You have a `page_views` table with (user_id, viewed_at). A session is a
-- sequence of page views by the same user where no two consecutive views
-- are more than 30 minutes apart. Assign a session_id to each page view.
--
-- This is THE gaps-and-islands problem, and it comes up constantly in product
-- analytics interviews because sessionization is a real-world task.

-- Schema
-- CREATE TABLE page_views (
--     user_id     BIGINT,
--     viewed_at   TIMESTAMP
-- );

-- ============================================================================
-- Solution: detect "new session" boundary, then cumulative sum
-- ============================================================================
WITH flagged AS (
    SELECT
        user_id,
        viewed_at,
        -- Flag = 1 when the gap from previous view exceeds 30 minutes
        -- (or when there is no previous view at all).
        CASE
            WHEN LAG(viewed_at) OVER w IS NULL
              OR viewed_at - LAG(viewed_at) OVER w > INTERVAL '30 minutes'
            THEN 1
            ELSE 0
        END AS is_new_session
    FROM page_views
    WINDOW w AS (PARTITION BY user_id ORDER BY viewed_at)
)
SELECT
    user_id,
    viewed_at,
    -- Cumulative sum of the boundary flag = session index within the user
    SUM(is_new_session) OVER (
        PARTITION BY user_id ORDER BY viewed_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_num
FROM flagged
ORDER BY user_id, viewed_at;

-- ============================================================================
-- Why this pattern
-- ============================================================================
-- Gaps-and-islands generalizes: anywhere you need to group consecutive rows by
-- a condition (session timeout, consecutive wins, continuous subscription),
-- the two-step pattern is:
--   1. Mark the *starts* of groups with a 0/1 flag
--   2. Running sum the flag -> group id
--
-- Alternatives using SESSION/MATCH_RECOGNIZE exist in Snowflake/Oracle but are
-- not portable. The LAG + running sum version works everywhere, including
-- Spark SQL with identical syntax.
