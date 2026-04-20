-- Problem 05: Median Without PERCENTILE_CONT
--
-- Compute the median of a salary column WITHOUT using PERCENTILE_CONT /
-- PERCENTILE_DISC / approx_percentile. Interviewers ask this to probe whether
-- you understand what a median actually is.

-- Schema
-- CREATE TABLE employees (
--     id      SERIAL PRIMARY KEY,
--     salary  NUMERIC
-- );

-- ============================================================================
-- Solution: ROW_NUMBER + COUNT, average the middle row(s)
-- ============================================================================
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
--             division, so we pick one row, and AVG returns its salary.
-- For even n: they are n/2 and n/2+1, so we pick both middle rows, and AVG
--             returns their average.
--
-- Works in both PostgreSQL and Spark SQL (division is integer by default
-- only in Spark when both operands are ints — cast `n` to int first).
--
-- Grouped median: add PARTITION BY dept to both window functions. This is
-- harder with percentile functions in some dialects, so the ROW_NUMBER trick
-- is often faster to write.
