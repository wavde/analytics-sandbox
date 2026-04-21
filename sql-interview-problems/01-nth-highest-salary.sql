-- Problem 01: Nth Highest Salary
--
-- Scenario
-- --------
-- A compensation analytics team at a large tech company is auditing pay bands across a job
-- family. They need to pull, for any given band, the Nth highest distinct
-- salary — not the Nth highest employee, and not a duplicate-inflated rank.
-- When there is no Nth value (the band has fewer than N distinct salaries),
-- the report should return NULL rather than an empty row so downstream
-- dashboards render cleanly.
--
-- Prompt
-- ------
-- Given an `employees` table, return the Nth highest distinct salary.
-- If fewer than N distinct salaries exist, return NULL.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Compensation benchmarking, pay-equity audits, and band
--                     review tooling all rely on percentile-like lookups
--                     against distinct salaries, not raw rows.
-- Skill demonstrated:  Correct handling of duplicates and missing values in
--                      ranked lookups — the core signal that a candidate
--                      reaches past LIMIT/OFFSET when it matters.
-- Business impact:     A ranking that silently double-counts duplicate
--                      salaries, or returns no row instead of NULL, feeds
--                      bad numbers into comp committees and board decks.

-- Schema
-- CREATE TABLE employees (
--     id       SERIAL PRIMARY KEY,
--     name     TEXT,
--     salary   NUMERIC
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Rank distinct salaries descending with DENSE_RANK so ties share a
--         rank (two people on $200k are both "rank 1", the next salary is 2).
-- Step 2: Filter to the Nth rank.
-- Step 3: Wrap in MAX() so an empty result collapses to a single NULL row
--         rather than zero rows.
WITH ranked AS (
    SELECT
        salary,
        DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM employees
)
SELECT MAX(salary) AS nth_highest_salary   -- MAX(...) returns NULL if empty
FROM ranked
WHERE rnk = :n;                            -- bind :n at the application layer

-- ============================================================================
-- Why not LIMIT/OFFSET?
-- ============================================================================
-- Naive attempt:
--   SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET :n-1;
-- Problems:
--   1. Returns zero rows (not NULL) when N exceeds the number of distinct
--      salaries — the dashboard contract here wants a NULL.
--   2. Without DISTINCT, OFFSET skips rows, not ranks, so ties corrupt the
--      answer.
--
-- Wrapping in MAX() or COALESCE can patch the NULL behaviour, but the
-- DENSE_RANK form is both correct and easier to extend (e.g., "Nth highest
-- salary per department" is just an added PARTITION BY).
--
-- ============================================================================
-- Spark SQL note
-- ============================================================================
-- Identical query works in Spark SQL; just drop the :n parameter syntax
-- (Spark uses positional `?` or literal substitution depending on the client).
