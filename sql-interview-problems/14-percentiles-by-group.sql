-- Problem 14: Percentile Distribution By Group
--
-- Scenario
-- --------
-- A streaming service's SRE team tracks playback-start latency by
-- region and needs the tail of the distribution — P50, P90, P99 per
-- region — to monitor SLOs. Means hide the tail; the tail is the user
-- experience that drives churn complaints. Where a region has very few
-- samples in a reporting window, the P99 is effectively noise and should
-- be flagged as such.
--
-- Prompt
-- ------
-- For each category, compute P50, P90, and P99 of a numeric column.
-- Return category, p50, p90, p99, n_orders. Flag groups with fewer than
-- 20 observations as having unstable percentile estimates.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Tail metrics (latency P99, order-value P90) are the
--                     standard way to describe user experience and
--                     unit-economics risk — often more informative than
--                     means.
-- Skill demonstrated:  Fluency with PERCENTILE_CONT / PERCENTILE_DISC,
--                      and the statistical judgment to flag under-sampled
--                      groups rather than report noise as signal.
-- Business impact:     A P99 reported from 10 samples is essentially the
--                      max of 10 draws — reacting to it triggers false
--                      alarms and erodes the team's on-call credibility.

-- Schema
-- CREATE TABLE orders (order_id BIGINT, category TEXT, order_value NUMERIC);

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Group by category.
-- Step 2: Compute PERCENTILE_CONT at 0.50, 0.90, 0.99 within each group.
-- Step 3: Attach a sample-size reliability flag so downstream consumers
--         can visually or programmatically demote under-sampled rows.
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
-- CONT interpolates between adjacent values (returns any real number in
-- the observed range). DISC returns an actual observed value. Use CONT
-- for continuous metrics (revenue, latency). Use DISC when a made-up
-- intermediate would be nonsensical — for example, "median item count"
-- should be an integer.
--
-- Dialect notes:
-- * Postgres: exact syntax above.
-- * Spark SQL: use PERCENTILE (inverse distribution function) on arrays:
--     PERCENTILE(order_value, array(0.5, 0.9, 0.99))
-- * Snowflake / BigQuery: APPROX_PERCENTILE / APPROX_QUANTILES for
--   sublinear memory on huge tables. Document the switch — approximate
--   is not exact, and SRE alert thresholds should account for that.
--
-- Sample-size rule of thumb: roughly 100 * (1 - p) observations per group
-- are needed for a stable P_p estimate. At n = 20, P99 is 0.2 observations
-- in the tail — effectively the max of 20 draws. That's the reliability
-- flag's reason to exist.
