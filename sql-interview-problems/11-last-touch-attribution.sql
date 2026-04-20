-- Problem 11: Last-Touch Attribution Within a 7-Day Window
--
-- You have a `touches` table (user_id, touched_at, channel) and a `purchases`
-- table (user_id, purchased_at, revenue). Credit each purchase to the channel
-- of the user's MOST RECENT touch that happened in the 7 days before the
-- purchase. If there was no touch in the 7-day window, attribute to 'direct'.
--
-- Return: channel, attributed_revenue, attributed_purchases.
--
-- Why this is asked: every marketing analytics team runs this query weekly.
-- It combines an asof-join with a guarded default, which trips up candidates
-- who reach for a plain JOIN and lose the direct-attributed rows.

-- Schema
-- CREATE TABLE touches   (user_id BIGINT, touched_at   TIMESTAMP, channel   TEXT);
-- CREATE TABLE purchases (user_id BIGINT, purchased_at TIMESTAMP, revenue   NUMERIC);

-- ============================================================================
-- Solution: LEFT JOIN + correlated "most recent touch in window" via window fns
-- ============================================================================
WITH candidate_touches AS (
    SELECT
        p.user_id,
        p.purchased_at,
        p.revenue,
        t.channel,
        t.touched_at,
        ROW_NUMBER() OVER (
            PARTITION BY p.user_id, p.purchased_at
            ORDER BY t.touched_at DESC
        ) AS rn
    FROM purchases p
    LEFT JOIN touches t
      ON t.user_id = p.user_id
     AND t.touched_at <= p.purchased_at
     AND t.touched_at >  p.purchased_at - INTERVAL '7 days'
)
SELECT
    COALESCE(channel, 'direct')       AS channel,
    SUM(revenue)                      AS attributed_revenue,
    COUNT(*)                          AS attributed_purchases
FROM candidate_touches
WHERE rn = 1 OR rn IS NULL   -- NULL = no touch in window; keep one row per purchase
GROUP BY 1
ORDER BY attributed_revenue DESC;

-- ============================================================================
-- Pitfalls
-- ============================================================================
-- 1. Inner JOIN loses direct-attributed purchases entirely — the ones you
--    most want to see, because they're "pure" conversions.
-- 2. Not partitioning by (user_id, purchased_at) gives one attributed row per
--    touch, not per purchase — double-counts revenue.
-- 3. The `<=` + `>` bound avoids the off-by-one where a touch exactly 7 days
--    before is either included or excluded at random. Match the window to
--    whatever the marketing team actually reports.
--
-- Spark SQL: identical. Use INTERVAL 7 DAY (no plural, no quotes).
