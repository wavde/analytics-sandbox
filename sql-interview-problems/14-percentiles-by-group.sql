-- Problem 14: Percentile Distribution By Group
--
-- For each product category, compute P50, P90, and P99 of order value. Return
-- category, p50, p90, p99, n_orders. Handle the case where some categories
-- have < 20 orders (percentile estimates unstable — flag them).
--
-- Why this is asked: every pricing / unit-economics analysis needs reliable
-- percentile tails. Candidates who use AVG for "typical order value" get
-- misled by long right tails. Candidates who use PERCENTILE_CONT blindly
-- without a sample-size guard report noise.

-- Schema
-- CREATE TABLE orders (order_id BIGINT, category TEXT, order_value NUMERIC);

-- ============================================================================
-- Solution: PERCENTILE_CONT within a GROUP, with a small-n flag
-- ============================================================================
SELECT
    category,
    COUNT(*)                                                      AS n_orders,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY order_value)     AS p50,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY order_value)     AS p90,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY order_value)     AS p99,
    CASE WHEN COUNT(*) < 20 THEN 'small_n_unstable' ELSE 'ok' END AS reliability
FROM orders
GROUP BY category
ORDER BY p90 DESC;

-- ============================================================================
-- PERCENTILE_CONT vs PERCENTILE_DISC
-- ============================================================================
-- CONT interpolates between adjacent values (returns any real number in the
-- observed range). DISC returns an actual observed value. Use CONT for
-- continuous metrics (revenue, latency). Use DISC when a made-up intermediate
-- would be nonsensical — e.g., "median item count" should be an integer.
--
-- Dialect notes:
-- * Postgres: exact syntax above.
-- * Spark SQL: use PERCENTILE (inverse distribution function) on arrays:
--     PERCENTILE(order_value, array(0.5, 0.9, 0.99))
-- * Snowflake / BigQuery: APPROX_PERCENTILE / APPROX_QUANTILES for sublinear
--   memory on huge tables. Document when you switch — approx is not exact.
--
-- Sampling rule of thumb: you need ~100 * (1 - p) observations per group
-- to get a stable P_p estimate. 99th percentile at n=20 is 0.2 observations
-- in the tail — effectively the max of 20 draws. That's the reason for the
-- reliability flag.
