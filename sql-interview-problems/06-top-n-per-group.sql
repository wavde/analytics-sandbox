-- Problem 06: Top N products per category by revenue
--
-- You have a `sales` table. For each product category, return the top 3
-- products by total revenue, with their rank within the category.
--
-- This "top N per group" pattern is the single most common analytics SQL
-- question in interviews. Variations: top N active users per country,
-- top-grossing titles per region, best sellers per store.

-- Schema
-- CREATE TABLE sales (
--     sale_id     BIGINT,
--     category    TEXT,
--     product_id  BIGINT,
--     revenue     NUMERIC
-- );

-- ============================================================================
-- Solution: window-ranked CTE
-- ============================================================================
WITH product_totals AS (
    SELECT
        category,
        product_id,
        SUM(revenue) AS total_revenue
    FROM sales
    GROUP BY category, product_id
),
ranked AS (
    SELECT
        category,
        product_id,
        total_revenue,
        -- DENSE_RANK ties -> can return > 3 rows when there are ties
        -- ROW_NUMBER always returns exactly 3 (arbitrary tiebreak)
        -- RANK ties -> gaps in rank numbers
        -- Business usually wants DENSE_RANK here.
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC
        ) AS rank_in_category
    FROM product_totals
)
SELECT
    category,
    product_id,
    total_revenue,
    rank_in_category
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category, product_id;

-- ============================================================================
-- Pitfall: SELECT DISTINCT + LIMIT doesn't work per-group
-- ============================================================================
-- A surprising number of candidates try:
--     SELECT DISTINCT category, product_id, total_revenue
--     FROM product_totals ORDER BY ... LIMIT 3;
-- This gives you 3 rows TOTAL, not 3 per category. Window functions are
-- the only clean way to express "top N within a partition."
--
-- Spark SQL: identical syntax. Snowflake: supports QUALIFY which simplifies:
--     ... QUALIFY DENSE_RANK() OVER (...) <= 3
