-- Problem 18: Event Deduplication Within a Time Window
--
-- Given `events` (user_id, event_name, event_at), collapse events from the
-- same (user, event_name) that happen within 5 seconds of each other into a
-- single "logical event". Return one row per logical event with the earliest
-- timestamp and a count of collapsed raw events.
--
-- Why this is asked: real event streams have double-fires from retries,
-- client-side debouncing failures, and at-least-once message queues. Every
-- production analyst writes a dedup layer at some point, and it's a perfect
-- gaps-and-islands-with-a-twist problem.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);

-- ============================================================================
-- Solution: session-style boundary flag, scoped to (user, event_name)
-- ============================================================================
WITH bounded AS (
    SELECT
        user_id,
        event_name,
        event_at,
        CASE
            WHEN LAG(event_at) OVER w IS NULL
              OR event_at - LAG(event_at) OVER w > INTERVAL '5 seconds'
            THEN 1
            ELSE 0
        END AS is_new_logical
    FROM events
    WINDOW w AS (PARTITION BY user_id, event_name ORDER BY event_at)
),
grouped AS (
    SELECT
        user_id,
        event_name,
        event_at,
        SUM(is_new_logical) OVER (
            PARTITION BY user_id, event_name
            ORDER BY event_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS logical_event_id
    FROM bounded
)
SELECT
    user_id,
    event_name,
    logical_event_id,
    MIN(event_at) AS first_event_at,
    MAX(event_at) AS last_event_at,
    COUNT(*)      AS n_raw_events_collapsed
FROM grouped
GROUP BY user_id, event_name, logical_event_id
ORDER BY user_id, event_name, first_event_at;

-- ============================================================================
-- Subtle bug: transitive windows
-- ============================================================================
-- The query dedups on "consecutive gap <= 5s". If you get three events at
-- t = 0s, 4s, 8s, they all collapse into one logical event (chain of gaps
-- each <= 5s), even though t=0 and t=8 are 8 seconds apart. Usually this is
-- what you want — the transitive closure captures "bursty" retries. But if
-- the spec is "collapse events within 5s of the FIRST one", you need a
-- different pattern: anchor each group to its start and compare against
-- that anchor, not against the previous row.
--
-- Anchor-based variant sketch:
--   Use a recursive CTE or an iterative approach; not expressible in a
--   single window pass because SQL windows can't reference "the anchor"
--   (the most recent row where is_new_logical = 1). In practice: do the
--   consecutive-gap pass first, then optionally split any group whose
--   (last - first) span exceeds a threshold.
--
-- Spark SQL: identical syntax. Use INTERVAL 5 SECOND (singular, no quotes).
