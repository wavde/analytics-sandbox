-- Problem 18: Event Deduplication Within a Time Window
--
-- Scenario
-- --------
-- A large consumer app's client event pipeline sits downstream of at-least-once delivery:
-- SDK retries, client-side debounce failures, and message-queue replays
-- all produce duplicate events a few seconds apart. Before the event
-- stream is trustworthy for metrics, a dedup layer collapses each burst
-- of (user, event_name) events within a short window into a single
-- logical event with a retained earliest timestamp and a raw-count
-- multiplier.
--
-- Prompt
-- ------
-- Given `events (user_id, event_name, event_at)`, collapse events from
-- the same (user, event_name) that occur within 5 seconds of each other
-- into a single logical event. Return one row per logical event with the
-- first and last raw timestamps and the count of raw events collapsed.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Every at-least-once event pipeline needs a dedup
--                     step. The numbers downstream (DAU, conversion,
--                     exposure counts) depend on it being correct.
-- Skill demonstrated:  Applying gaps-and-islands at sub-second precision,
--                      and recognising the semantic difference between
--                      "consecutive gap <= T" and "within T of the burst
--                      anchor".
-- Business impact:     Under-dedup inflates event counts (and every
--                      downstream metric built on them); over-dedup
--                      merges legitimately distinct events and
--                      under-reports engagement.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Partition by (user_id, event_name) ordered by time. Flag a row
--         as a new logical event when the gap from the previous row
--         exceeds 5 seconds (or when there is no previous row).
-- Step 2: Running-sum the flag within the partition to assign a logical
--         event id to each raw row.
-- Step 3: Aggregate per (user, event_name, logical_event_id) to produce
--         first / last timestamps and the collapsed raw-event count.
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
-- The query dedups on "consecutive gap <= 5s". Three events at t = 0s,
-- 4s, 8s all collapse into one logical event (chain of gaps each <= 5s),
-- even though the first and last are 8 seconds apart. Usually this is
-- what the business wants — the transitive closure captures bursty
-- retries. When the spec is "collapse events within 5s of the FIRST one"
-- a different pattern is needed: anchor each group to its start and
-- compare against the anchor, not against the previous row.
--
-- Anchor-based variant sketch:
--   A recursive CTE or an iterative approach — not expressible in a
--   single window pass, since SQL windows can't reference "the anchor"
--   (the most recent row where is_new_logical = 1). A practical
--   compromise: do the consecutive-gap pass first, then split any group
--   whose (last - first) span exceeds a secondary threshold.
--
-- Spark SQL: identical syntax. Use INTERVAL 5 SECOND (singular, no quotes).
