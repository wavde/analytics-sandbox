-- Problem 02: Session Reconstruction
--
-- Scenario
-- --------
-- Netflix's playback platform emits a stream of heartbeat events while a
-- title is being watched. The consumer-insights team needs to reconstruct
-- viewing sessions from that stream: a session is a run of heartbeats from
-- the same profile with no gap longer than 30 minutes. Session boundaries
-- feed downstream metrics like average session length, sessions per active
-- day, and bounce-before-first-minute rates.
--
-- Prompt
-- ------
-- Given `page_views (user_id, viewed_at)`, assign a session index to each
-- row such that a new session starts whenever two consecutive events from
-- the same user are more than 30 minutes apart.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Sessionisation is the foundation of engagement
--                     reporting for any playback, browsing, or messaging
--                     product. Most top-line retention metrics are defined
--                     on top of it.
-- Skill demonstrated:  Fluency with the gaps-and-islands pattern —
--                      identifying group boundaries with LAG and converting
--                      them into group ids with a running sum.
-- Business impact:     Miscalibrated session timeouts silently shift every
--                      engagement KPI. A 30-minute boundary defined
--                      inconsistently across pipelines is a common cause
--                      of DAU/session-count discrepancies between teams.

-- Schema
-- CREATE TABLE page_views (
--     user_id     BIGINT,
--     viewed_at   TIMESTAMP
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: For each user, look at the previous event's timestamp with LAG.
-- Step 2: Flag a row as "new session" (1) when there is no previous event,
--         or when the gap exceeds 30 minutes; otherwise 0.
-- Step 3: Running-sum that flag within the user — the cumulative total is
--         the session index.
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
-- Gaps-and-islands generalises: anywhere you need to group consecutive rows
-- by a condition (session timeout, consecutive wins, continuous
-- subscription), the two-step pattern is:
--   1. Mark the *starts* of groups with a 0/1 flag.
--   2. Running-sum the flag to get a group id.
--
-- Alternatives using SESSION / MATCH_RECOGNIZE exist in Snowflake and
-- Oracle but are not portable. The LAG + running sum version works
-- everywhere, including Spark SQL with identical syntax. In production
-- pipelines with billions of events, partition pruning on user_id and a
-- sort-merge plan on viewed_at keep this cheap; watch for skew on power
-- users with outsized event counts.
