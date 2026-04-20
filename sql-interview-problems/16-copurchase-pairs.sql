-- Problem 16: Co-Purchase Product Pairs (Market Basket)
--
-- Given `order_items` (order_id, product_id), find the top 10 product pairs
-- that most frequently appear together in the same order. A "pair" is
-- unordered: (A, B) is the same as (B, A).
--
-- Return: product_a, product_b, n_orders_together.
--
-- Why this is asked: it's the first step of almost every recommender system
-- ("customers who bought X also bought Y"), and it forces candidates to think
-- carefully about self-joins with anti-duplication.

-- Schema
-- CREATE TABLE order_items (order_id BIGINT, product_id BIGINT,
--                           PRIMARY KEY (order_id, product_id));

-- ============================================================================
-- Solution: self-join with product_a < product_b to avoid double-counting
-- ============================================================================
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
-- Why the `<` and not `<>` or `!=`
-- ============================================================================
-- `a.product_id <> b.product_id` is the "obvious" fix to drop self-pairs
-- (X with itself), but it still counts the pair TWICE: once as (A, B) and
-- once as (B, A). Always use strict `<` (or `>`) for unordered-pair joins.
--
-- This gives you an O(avg_basket_size^2) blow-up per order. For a handful of
-- items it's fine; for long baskets (thousands of SKUs) you'd switch to
-- approximate methods (MinHash / locality-sensitive hashing).
--
-- Extension: compute LIFT = P(A and B) / (P(A) * P(B)). A pair can be "sold
-- together a lot" just because both items are popular on their own; lift
-- normalises for that.
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
