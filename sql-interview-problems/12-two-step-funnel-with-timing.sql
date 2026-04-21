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
-- Step 1: Per user, take MIN(event_at) for each step — collapses a user's
--         many events per step down to one anchor timestamp per step.
-- Step 2: Flag step 2 as reached if the user's add_to_cart is within 24h
--         of their view; flag step 3 as reached if the user's purchase is
--         within 24h of the add (NOT of the view).
-- Step 3: Aggregate to viewer counts and step-to-step percentages.
WITH first_steps AS (
    SELECT
        user_id,
        MIN(CASE WHEN event_name = 'view'        THEN event_at END) AS viewed_at,
        MIN(CASE WHEN event_name = 'add_to_cart' THEN event_at END) AS added_at,
        MIN(CASE WHEN event_name = 'purchase'    THEN event_at END) AS purchased_at
    FROM events
    GROUP BY user_id
),
flagged AS (
    SELECT
        user_id,
        viewed_at IS NOT NULL AS viewed,
        (added_at IS NOT NULL AND viewed_at IS NOT NULL
         AND added_at BETWEEN viewed_at AND viewed_at + INTERVAL '24 hours')
            AS added_in_24h,
        (purchased_at IS NOT NULL AND added_at IS NOT NULL
         AND purchased_at BETWEEN added_at AND added_at + INTERVAL '24 hours')
            AS purchased_in_24h_of_add
    FROM first_steps
    WHERE viewed_at IS NOT NULL
)
SELECT
    COUNT(*)                                               AS n_viewers,
    SUM(added_in_24h::int)                                 AS n_added,
    SUM((added_in_24h AND purchased_in_24h_of_add)::int)   AS n_purchased,
    ROUND(100.0 * SUM(added_in_24h::int) / COUNT(*), 2)    AS view_to_cart_pct,
    ROUND(100.0 * SUM((added_in_24h AND purchased_in_24h_of_add)::int)
              / NULLIF(SUM(added_in_24h::int), 0), 2)      AS cart_to_purchase_pct
FROM flagged;

-- ============================================================================
-- Why the MIN-timestamp pattern
-- ============================================================================
-- A three-way self-join across events with user/time ordering constraints
-- works, but explodes when a user has many events per step — the
-- intermediate cartesian product followed by DISTINCT is O(N^3) and
-- produces wrong denominators for percent-conversion. Collapsing each
-- user to one row per funnel step via MIN(event_at) makes the rest of the
-- logic linear in users.
--
-- The remaining subtlety is the step-chaining bug: gating step 3 on
-- "purchase within 24h of VIEW" instead of "within 24h of ADD" silently
-- widens the funnel. Step K should always be measured against step K-1.
