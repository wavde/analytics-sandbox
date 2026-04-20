-- Problem 12: Two-Step Funnel With Ordered Timing
--
-- Events table has (user_id, event_name, event_at). For each user who viewed
-- a product, compute: did they add-to-cart within 24h of the view, AND did
-- they purchase within 24h of that add-to-cart?
--
-- Return per-user flags: viewed, added_in_24h, purchased_in_24h_of_add,
-- plus the funnel conversion rates at each step.
--
-- Why this is asked: real funnels have ORDERING and TIMING. A candidate who
-- only counts "did user do X and Y" without the time constraint has built a
-- lift chart, not a funnel, and will mis-report conversion.

-- Schema
-- CREATE TABLE events (user_id BIGINT, event_name TEXT, event_at TIMESTAMP);
-- event_name in ('view', 'add_to_cart', 'purchase')

-- ============================================================================
-- Solution: MIN timestamp per step, then chained interval checks
-- ============================================================================
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
-- The naive self-join (events e1 JOIN events e2 JOIN events e3 ON user/time
-- ordering) works but explodes if a user has many events per step — you get
-- the cartesian product, then DISTINCT, which is O(N^3) and wrong for
-- percent-conversion denominators. Taking MIN(event_at) per (user, step)
-- collapses each user to one row per funnel step before you combine.
--
-- The remaining subtlety is the step-chaining bug: candidates often gate
-- step 3 on "purchase within 24h of VIEW" instead of "within 24h of ADD".
-- That silently widens the funnel and inflates conversion. Always chain:
-- step K must be within window of step K-1, not step 1.
