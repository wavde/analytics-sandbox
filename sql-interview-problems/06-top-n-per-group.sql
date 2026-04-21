-- Problem 06: Top N Products Per Category By Revenue
--
-- Scenario
-- --------
-- Netflix's home-row ranker needs a per-country "top titles" feed: the
-- three highest-grossing (or most-watched) titles per country, feeding the
-- "Top 10 in <country>" row on the home screen. The query shape is the
-- same wherever a product surfaces leaderboards by segment — top sellers
-- per store on Amazon, top posts per community on Reddit, top artists per
-- market on Spotify.
--
-- Prompt
-- ------
-- Given a `sales` table, return the top three products by total revenue
-- within each category, with the rank within the category.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Per-segment leaderboards drive ranking features,
--                     merchandising slots, and partner reports across
--                     virtually every consumer product.
-- Skill demonstrated:  Partitioned window ranking, and picking the right
--                      ranking function for the business semantics of ties.
-- Business impact:     Ranking ties handled incorrectly either hide legit
--                      top performers or surface arbitrary ones, which is
--                      especially sensitive when the leaderboard is
--                      partner-visible (e.g., best-seller badges).

-- Schema
-- CREATE TABLE sales (
--     sale_id     BIGINT,
--     category    TEXT,
--     product_id  BIGINT,
--     revenue     NUMERIC
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Aggregate revenue per (category, product_id).
-- Step 2: Rank within each category using DENSE_RANK so ties share a rank
--         and the top-3 cutoff includes all tied products.
-- Step 3: Filter to rank <= 3 and order the output for readability.
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
-- A common mistake:
--     SELECT DISTINCT category, product_id, total_revenue
--     FROM product_totals ORDER BY ... LIMIT 3;
-- That returns 3 rows TOTAL, not 3 per category. Window functions are the
-- clean way to express "top N within a partition."
--
-- Spark SQL: identical syntax. Snowflake and BigQuery support QUALIFY which
-- removes the outer CTE:
--     ... QUALIFY DENSE_RANK() OVER (...) <= 3
