-- Problem 17: Top 3-Step User Paths Through The Product
--
-- Scenario
-- --------
-- Netflix's churn-analysis team studies what users actually do in the
-- days before they cancel: which three-event sequences show up most often
-- on the pre-churn path? Path analysis powers the "what journeys end in
-- churn, conversion, upgrade?" questions that product reviews routinely
-- ask and that dedicated path-analytics tools answer at much higher cost.
--
-- Prompt
-- ------
-- Given `events (user_id, event_name, event_at)`, find the 10 most common
-- ordered 3-step event sequences per user. Order within a user is by
-- event_at. Use the raw sequence (every event counts in order), not the
-- first-occurrence-only variant.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Path analysis in SQL is the cheapest way to answer
--                     "what are users doing before X?" questions without
--                     standing up a specialised product-analytics tool.
-- Skill demonstrated:  Composing LAG(..., k) over an ordered window to
--                      materialise multi-step sequences, and reporting
--                      both distinct-users and occurrence counts so the
--                      number matches the stakeholder's question.
-- Business impact:     Confusing "users who walked this path" with "times
--                      this path was walked" is a top source of
--                      dashboard-reading errors in product analytics —
--                      the same path can have high occurrence and low
--                      user count when a few power users loop through it.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Order each user's events by time and attach a position index.
-- Step 2: Use LAG(event_name, 2) and LAG(event_name, 1) within the user
--         window to materialise (step_1, step_2, step_3) on every row.
-- Step 3: Drop rows missing prior steps (first two positions per user),
--         then GROUP BY the triple and count distinct users and total
--         occurrences.
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
-- The query reports BOTH n_users (distinct users who ever walked this
-- path) and n_path_occurrences (total times the path was walked across
-- anyone). A path can have high occurrence but low distinct users,
-- meaning a small set of power users trigger the same loop repeatedly.
-- Report both, or pick the one the stakeholder cares about.
--
-- Variants:
-- * First-touch path: rank within (user, event_name) and keep rank = 1
--   before the LAG step, so each user contributes each event at most once.
-- * Time-bounded path: add
--     event_at - LAG(event_at, 1) OVER w <= INTERVAL '1 hour'
--   to the triples CTE to only count tightly sequential paths.
-- * N-step paths: generalise with LAG(event_name, k) for k = n-1, ..., 1.
--
-- Performance: the triples CTE has the same row count as events. The
-- GROUP BY materialises only distinct 3-tuples. For large event tables,
-- push a ROW_NUMBER filter (keep pos <= K_max) or sessionise first so
-- paths do not bridge logically distinct sessions.
