-- Problem 03: Funnel Conversion
--
-- You have an `events` table with (user_id, event_name, event_time).
-- For users who performed "view_product" on a given day, compute the
-- conversion rate through the funnel:
--   view_product -> add_to_cart -> checkout -> purchase
-- where each step must occur AFTER the previous step (within 24 hours).

-- Schema
-- CREATE TABLE events (
--     user_id     BIGINT,
--     event_name  TEXT,
--     event_time  TIMESTAMP
-- );

-- ============================================================================
-- Solution: conditional aggregation with ordered existence checks
-- ============================================================================
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
-- * The ordering constraint ("must occur AFTER previous step") is the tricky
--   part. Forgetting it gives an inflated conversion rate because users who
--   add to cart BEFORE viewing the specific product still get counted.
-- * Spark SQL lacks FILTER (WHERE ...); rewrite as
--       SUM(CASE WHEN ... AND ... > ... THEN 1 ELSE 0 END)
-- * For production, pre-aggregate `events` into a `user_day_events` array or
--   use pivoted tables — self-joining raw events at scale is expensive.
