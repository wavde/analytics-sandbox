-- Problem 05: Median Without PERCENTILE_CONT
--
-- Scenario
-- --------
-- Uber Eats surfaces "typical order value" in merchant-facing reporting.
-- The typical value is the median of order values, not the mean — long
-- right tails from large group orders make the mean misleading. The
-- reporting runtime is a SQL engine whose percentile function is either
-- unavailable or unreliable on the data volumes involved, so the median
-- has to be computed from first principles.
--
-- Prompt
-- ------
-- Compute the median of a numeric column without using PERCENTILE_CONT,
-- PERCENTILE_DISC, or an approx_percentile function.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Median-of-distribution reporting (order value, ride
--                     fare, session length) is a recurring need for any
--                     engine or dialect where percentile functions are
--                     missing, slow, or non-deterministic.
-- Skill demonstrated:  Knowing what a median actually is — the middle
--                      ordered value for odd n, the average of the two
--                      middle values for even n — and expressing that
--                      directly with ROW_NUMBER and COUNT.
-- Business impact:     Reporting the mean in place of the median on
--                      heavy-tailed distributions consistently overstates
--                      "typical" values in merchant dashboards, which
--                      shows up as trust issues when operators compare
--                      the dashboard to what they see in the field.

-- Schema
-- CREATE TABLE employees (
--     id      SERIAL PRIMARY KEY,
--     salary  NUMERIC
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Attach to every row its ordered position (ROW_NUMBER) and the
--         total row count (COUNT(*) OVER ()).
-- Step 2: Pick the middle row(s): (n+1)/2 and (n+2)/2 under integer
--         division collapse to the single middle row when n is odd, and to
--         the two middle rows when n is even.
-- Step 3: Average those one or two selected rows.
WITH ranked AS (
    SELECT
        salary,
        ROW_NUMBER() OVER (ORDER BY salary) AS rn,
        COUNT(*)     OVER ()                AS n
    FROM employees
)
SELECT AVG(salary) AS median_salary
FROM ranked
WHERE
    -- Odd n: the middle row. Even n: average of the two middle rows.
    rn IN ((n + 1) / 2, (n + 2) / 2);

-- ============================================================================
-- Why this works
-- ============================================================================
-- For odd n:  (n+1)/2 and (n+2)/2 are both equal to (n+1)/2 after integer
--             division, so one row is selected and AVG returns its value.
-- For even n: the two expressions evaluate to n/2 and n/2+1, selecting both
--             middle rows; AVG returns their mean.
--
-- Works in PostgreSQL and Spark SQL. In Spark, integer division only holds
-- when both operands are integers — cast `n` to int explicitly.
--
-- Grouped median: add PARTITION BY dept to both window functions. This is
-- harder to express with percentile functions in some dialects, and the
-- ROW_NUMBER trick has predictable memory cost — one sort per partition,
-- no hidden accumulator behaviour.
