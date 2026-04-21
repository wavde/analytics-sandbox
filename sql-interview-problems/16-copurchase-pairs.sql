-- Problem 16: Co-Purchase Product Pairs (Market Basket)
--
-- Scenario
-- --------
-- An e-commerce marketplace's "customers also bought" module needs a seed
-- signal: product pairs that frequently co-occur in the same order. The
-- SQL layer doesn't build the final recommender, but it produces the
-- co-purchase counts (and, via lift, the strength of association) that
-- feed downstream models and merchandising surfaces.
--
-- Prompt
-- ------
-- Given `order_items (order_id, product_id)`, return the top 10 unordered
-- product pairs by number of orders in which both appear. A pair (A, B)
-- is the same as (B, A).
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Co-purchase analysis is the first step of most
--                     market-basket and recommender pipelines, and a
--                     standard input to merchandising and bundling work.
-- Skill demonstrated:  Self-joining with a strict inequality to dedupe
--                      unordered pairs, and recognising when the join
--                      blows up at scale.
-- Business impact:     A double-counted pair inflates co-purchase signal
--                      and sends the wrong pairs to the recommender's
--                      top-K, which shows up directly in on-site
--                      merchandising quality.

-- Schema
-- CREATE TABLE order_items (order_id BIGINT, product_id BIGINT,
--                           PRIMARY KEY (order_id, product_id));

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Self-join order_items to itself on order_id.
-- Step 2: Require product_id_a < product_id_b so each unordered pair
--         appears exactly once (this also eliminates self-pairs).
-- Step 3: Count per (a, b) and take the top 10.
SELECT
    a.product_id AS product_a,
    b.product_id AS product_b,
    COUNT(*)     AS n_orders_together
FROM order_items a
JOIN order_items b
  ON a.order_id   = b.order_id
 AND a.product_id < b.product_id     -- strict < drops both (X, X) and (B, A)
GROUP BY a.product_id, b.product_id
ORDER BY n_orders_together DESC
LIMIT 10;

-- ============================================================================
-- Why `<` and not `<>`
-- ============================================================================
-- `a.product_id <> b.product_id` drops self-pairs (X with itself) but
-- still counts each real pair twice: once as (A, B) and once as (B, A).
-- Always use strict `<` (or `>`) for unordered-pair joins.
--
-- Self-join cost is O(avg_basket_size^2) rows per order. For a few items
-- per basket it's fine; for long baskets (thousands of SKUs per order,
-- as in some B2B flows) it is the expensive part of the pipeline and
-- approximate methods (MinHash, locality-sensitive hashing) or explicit
-- basket-size caps become necessary.
--
-- Extension: LIFT = P(A and B) / (P(A) * P(B)). Two popular items will
-- co-occur a lot just because both are popular; lift normalises for that.
--
--   WITH pair_counts AS (...above query without LIMIT...),
--        item_counts AS (SELECT product_id, COUNT(*) AS n FROM order_items GROUP BY 1),
--        total       AS (SELECT COUNT(DISTINCT order_id) AS n_orders FROM order_items)
--   SELECT p.*,
--          1.0 * p.n_orders_together * t.n_orders
--          / (a.n * b.n) AS lift
--   FROM pair_counts p
--   JOIN item_counts a ON a.product_id = p.product_a
--   JOIN item_counts b ON b.product_id = p.product_b
--   CROSS JOIN total t
--   ORDER BY lift DESC;
--
-- Lift > 1 means the pair appears together more often than chance.
