-- Problem 17: Top 3-Step User Paths Through the Funnel
--
-- Given `events` (user_id, event_name, event_at), find the 10 most common
-- ordered sequences of 3 events per user. Events within the same user should
-- be ordered by timestamp. Only use each user's FIRST occurrence of each
-- event if you want a clean first-path; for this problem, use the raw
-- sequence (every event counted in order).
--
-- Return: step_1, step_2, step_3, n_users.
--
-- Why this is asked: "path analysis" powers every product-team answer to
-- "what are users actually doing before they churn / convert / upgrade?"
-- Doing it in SQL (rather than a specialised tool) requires composing LAG
-- with window ordering — a key test of whether a candidate can write
-- interview-grade window-function code.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);

-- ============================================================================
-- Solution: LAG twice, then group by the (step1, step2, step3) tuple
-- ============================================================================
WITH ordered AS (
    SELECT
        user_id,
        event_name,
        event_at,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_at) AS pos
    FROM events
),
triples AS (
    SELECT
        user_id,
        LAG(event_name, 2) OVER w AS step_1,
        LAG(event_name, 1) OVER w AS step_2,
        event_name                AS step_3
    FROM ordered
    WINDOW w AS (PARTITION BY user_id ORDER BY pos)
)
SELECT
    step_1,
    step_2,
    step_3,
    COUNT(DISTINCT user_id) AS n_users,
    COUNT(*)                AS n_path_occurrences
FROM triples
WHERE step_1 IS NOT NULL AND step_2 IS NOT NULL   -- drop the two initial rows
GROUP BY step_1, step_2, step_3
ORDER BY n_users DESC
LIMIT 10;

-- ============================================================================
-- Users vs occurrences
-- ============================================================================
-- The query reports BOTH n_users (distinct users who ever walked this path)
-- and n_path_occurrences (total times anyone walked it). A path can have
-- high occurrence but low distinct users — meaning a few power users trigger
-- the same loop many times. Report both, or pick the one your stakeholder
-- cares about. Confusing "users" with "events" is one of the top
-- dashboard-reading errors in product analytics.
--
-- Variants:
-- * First-touch path: rank events within (user, event_name) and keep rank=1
--   before the LAG step, so each user contributes each event at most once.
-- * Time-bounded path: add `event_at - LAG(event_at, 1) OVER w <= INTERVAL '1 hour'`
--   to the triples CTE filter to only count tightly sequential paths.
-- * N-step paths: generalise with LAG(event_name, k) for k = n-1, ..., 1.
--
-- Performance: triples CTE is N rows (same as events table). The GROUP BY
-- materialises only the distinct 3-tuples. For large event tables, push the
-- ROW_NUMBER filter (keep pos <= K_max) or sessionise first.
