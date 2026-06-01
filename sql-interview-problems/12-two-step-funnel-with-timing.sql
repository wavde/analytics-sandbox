-- Problem 12: Two-Step Funnel With Ordered Timing
--
-- Scenario
-- --------
-- A global marketplace for short-term rentals measures search-to-book conversion within a 24-hour window: a
-- guest who searches, then clicks a listing within 24 hours, then books
-- within 24 hours of that click. The chained timing matters — a booking
-- that happens 10 days after a search is not attributable to that search
-- session, and counting it inflates the funnel.
--
-- Prompt
-- ------
-- Given `events (user_id, event_name, event_at)` with events in
-- {'view', 'add_to_cart', 'purchase'}, for each user who viewed compute:
-- did they add within 24h of the view, and did they purchase within 24h
-- of that add? Return the step counts and step-to-step conversion rates.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Time-bounded funnels are how product and growth
--                     teams actually measure conversion. Unbounded "ever
--                     did X then Y" funnels overstate conversion and mask
--                     regressions.
-- Skill demonstrated:  Correctly chaining step timing (step K within
--                      window of step K-1, not step 1) and avoiding the
--                      cartesian self-join explosion.
-- Business impact:     An inflated funnel number hides regressions in
--                      A/B tests and routes investment toward experiments
--                      that didn't actually move the metric.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);
-- event_name in ('view', 'add_to_cart', 'purchase')

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Per user, choose the first view as the funnel anchor.
-- Step 2: For that anchor, choose the earliest valid add_to_cart after the
--         view and within 24h.
-- Step 3: For that add, choose the earliest valid purchase after the add
--         and within the next 24h.
-- Step 4: Aggregate to viewer counts and step-to-step percentages.
WITH first_views AS (
    SELECT
        user_id,
        MIN(event_at) AS viewed_at
    FROM events
    WHERE event_name = 'view'
    GROUP BY user_id
),
first_adds AS (
    SELECT
        v.user_id,
        v.viewed_at,
        MIN(e.event_at) AS added_at
    FROM first_views v
    LEFT JOIN events e
      ON e.user_id = v.user_id
     AND e.event_name = 'add_to_cart'
     AND e.event_at > v.viewed_at
     AND e.event_at <= v.viewed_at + INTERVAL '24 hours'
    GROUP BY v.user_id, v.viewed_at
),
first_purchases AS (
    SELECT
        a.user_id,
        a.viewed_at,
        a.added_at,
        MIN(e.event_at) AS purchased_at
    FROM first_adds a
    LEFT JOIN events e
      ON e.user_id = a.user_id
     AND e.event_name = 'purchase'
     AND e.event_at > a.added_at
     AND e.event_at <= a.added_at + INTERVAL '24 hours'
    GROUP BY a.user_id, a.viewed_at, a.added_at
)
SELECT
    COUNT(*)                                                   AS n_viewers,
    COUNT(*) FILTER (WHERE added_at IS NOT NULL)               AS n_added,
    COUNT(*) FILTER (WHERE purchased_at IS NOT NULL)           AS n_purchased,
    ROUND(100.0 * COUNT(*) FILTER (WHERE added_at IS NOT NULL) / COUNT(*), 2)
        AS view_to_cart_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE purchased_at IS NOT NULL)
              / NULLIF(COUNT(*) FILTER (WHERE added_at IS NOT NULL), 0), 2)
        AS cart_to_purchase_pct
FROM first_purchases;

-- ============================================================================
-- Why chained MIN timestamps
-- ============================================================================
-- A three-way self-join across events with user/time ordering constraints
-- works, but explodes when a user has many events per step — the
-- intermediate cartesian product followed by DISTINCT is O(N^3) and
-- produces wrong denominators for percent-conversion. The safer pattern is
-- to collapse one step at a time: pick the first valid add after the chosen
-- view, then the first valid purchase after that chosen add.
--
-- Taking independent MIN(event_at) values for each event type is wrong:
-- an earlier invalid add or purchase can precede the selected prior step.
-- Step K should always be measured against step K-1.
