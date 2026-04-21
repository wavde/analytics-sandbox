-- Problem 11: Last-Touch Attribution Within a 7-Day Window
--
-- Scenario
-- --------
-- A digital-ads platform produces advertiser-facing attribution reports: each purchase
-- is credited to the channel of the user's most recent ad touch within the
-- last 7 days, and purchases with no qualifying touch are bucketed as
-- 'direct'. The same query shape runs on video-platform ad spend, on affiliate
-- networks, and on virtually every marketing-attribution dashboard.
--
-- Prompt
-- ------
-- Given `touches (user_id, touched_at, channel)` and `purchases (user_id,
-- purchased_at, revenue)`, credit each purchase to the channel of the
-- user's most recent touch in the 7 days before the purchase. Purchases
-- with no qualifying touch are attributed to 'direct'.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Last-touch attribution is the baseline report every
--                     paid-marketing team runs weekly, and the numbers
--                     feed channel-spend decisions directly.
-- Skill demonstrated:  An as-of join done correctly with LEFT JOIN +
--                      window ROW_NUMBER, plus a guarded default bucket
--                      for the no-touch case.
-- Business impact:     An INNER JOIN here silently drops "direct" revenue
--                      — often the largest bucket — and shifts spend
--                      decisions toward whichever paid channel happens to
--                      be nearest in time to a purchase.
--
-- See also: paid-media-playbook / case 02 (MTA comparison) walks through
-- what this SQL baseline systematically mis-measures, and what Markov
-- removal-effect recovers instead:
-- https://github.com/wavde/paid-media-playbook/tree/main/case-studies/02-mta-comparison

-- Schema
-- CREATE TABLE touches   (user_id BIGINT, touched_at   TIMESTAMP, channel   TEXT);
-- CREATE TABLE purchases (user_id BIGINT, purchased_at TIMESTAMP, revenue   NUMERIC);

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: LEFT JOIN each purchase to all touches from the same user that
--         fall in the 7-day window ending at the purchase.
-- Step 2: Within each purchase, rank candidate touches by recency
--         (ROW_NUMBER with ORDER BY touched_at DESC).
-- Step 3: Keep the most recent touch (rn = 1) OR the rn-is-NULL row for
--         purchases with no qualifying touch (the LEFT JOIN preserves
--         them).
-- Step 4: Aggregate revenue and count by channel, coalescing the NULL
--         channel to 'direct'.
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
-- 1. INNER JOIN loses direct-attributed purchases entirely — often the
--    biggest bucket, and the "pure" conversions advertisers most want to
--    see.
-- 2. Not partitioning by (user_id, purchased_at) yields one attributed row
--    per touch instead of per purchase, double-counting revenue.
-- 3. The `<=` + `>` bound avoids the off-by-one where a touch exactly 7
--    days before the purchase is arbitrarily included or excluded. Match
--    the boundary convention to what the marketing team actually reports.
--
-- Spark SQL: identical. Use INTERVAL 7 DAY (no plural, no quotes).
