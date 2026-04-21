-- Problem 03: Funnel Conversion
--
-- Scenario
-- --------
-- A social marketplace runs a four-step buying funnel: view_product →
-- add_to_cart → checkout → purchase. The marketplace growth team reports
-- daily conversion at each step for users who entered the funnel on a given
-- day, with each later step required to happen within 24 hours of the
-- initial view. The numbers drive A/B test readouts on checkout UI changes
-- and weekly ops reviews.
--
-- Prompt
-- ------
-- Given `events (user_id, event_name, event_time)`, for users whose first
-- `view_product` on `:target_date` anchors the funnel, compute the
-- counts and step-to-step conversion rates through
-- view_product → add_to_cart → checkout → purchase, with each step required
-- to occur strictly after the previous step and within 24 hours of the view.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Funnel conversion rates power checkout experiments,
--                     weekly business reviews, and growth-loop diagnostics
--                     across every consumer product.
-- Skill demonstrated:  Using conditional aggregation with ordering
--                      constraints to build a correct funnel in one pass,
--                      instead of cascading self-joins that over-count.
-- Business impact:     Ignoring the ordering constraint inflates
--                      conversion, hiding real regressions in an A/B test
--                      and pointing experimentation reviews at the wrong
--                      variant.

-- Schema
-- CREATE TABLE events (
--     user_id     BIGINT,
--     event_name  TEXT,
--     event_time  TIMESTAMP
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Find each user's first view on the target day — that anchors the
--         24-hour funnel window for that user.
-- Step 2: LEFT JOIN each user's subsequent events within 24 hours of the
--         anchor view and take MIN(event_time) per step. One row per user.
-- Step 3: At the outer level, count users who reached each step with the
--         ordering constraint (each step's timestamp must exceed the prior
--         step's) and turn those counts into step-to-step percentages.
WITH first_views AS (
    SELECT user_id, MIN(event_time) AS viewed_at
    FROM events
    WHERE event_name = 'view_product'
      AND event_time::date = :target_date
    GROUP BY user_id
),
per_user AS (
    SELECT
        fv.user_id,
        fv.viewed_at,
        MIN(CASE WHEN e.event_name = 'add_to_cart' THEN e.event_time END) AS carted_at,
        MIN(CASE WHEN e.event_name = 'checkout'    THEN e.event_time END) AS checkout_at,
        MIN(CASE WHEN e.event_name = 'purchase'    THEN e.event_time END) AS purchased_at
    FROM first_views fv
    LEFT JOIN events e
      ON e.user_id = fv.user_id
     AND e.event_time >= fv.viewed_at
     AND e.event_time <  fv.viewed_at + INTERVAL '24 hours'
    GROUP BY fv.user_id, fv.viewed_at
)
SELECT
    COUNT(*)                                                  AS n_viewed,
    COUNT(carted_at)      FILTER (WHERE carted_at    > viewed_at)     AS n_carted,
    COUNT(checkout_at)    FILTER (WHERE checkout_at  > carted_at)     AS n_checkout,
    COUNT(purchased_at)   FILTER (WHERE purchased_at > checkout_at)   AS n_purchased,

    ROUND(100.0 * COUNT(carted_at)    FILTER (WHERE carted_at    > viewed_at)   / NULLIF(COUNT(*), 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * COUNT(checkout_at)  FILTER (WHERE checkout_at  > carted_at)   / NULLIF(COUNT(carted_at) FILTER (WHERE carted_at > viewed_at), 0), 2) AS cart_to_checkout_pct,
    ROUND(100.0 * COUNT(purchased_at) FILTER (WHERE purchased_at > checkout_at) / NULLIF(COUNT(checkout_at) FILTER (WHERE checkout_at > carted_at), 0), 2) AS checkout_to_purchase_pct
FROM per_user;

-- ============================================================================
-- Notes
-- ============================================================================
-- * The ordering constraint ("must occur AFTER the previous step") is the
--   trap. Dropping it gives an inflated conversion rate because users who
--   add to cart BEFORE viewing the specific product still get counted.
-- * Spark SQL lacks FILTER (WHERE ...); rewrite as
--       SUM(CASE WHEN ... AND ... > ... THEN 1 ELSE 0 END)
-- * For production, pre-aggregate `events` into a `user_day_events` array
--   or pivoted per-user table — self-joining raw events at marketplace
--   scale is expensive and the anchor view is the natural partition key.
