-- Problem 01: Nth Highest Salary
--
-- Given an `employees` table, write a query that returns the Nth highest
-- distinct salary. If there is no Nth highest salary, return NULL.
--
-- This is the "warm-up" question at almost every FAANG analytics interview.
-- The trap is that most people reach for LIMIT/OFFSET and then get tripped up
-- by (a) duplicate salaries, (b) the NULL-when-missing requirement.

-- Schema
-- CREATE TABLE employees (
--     id       SERIAL PRIMARY KEY,
--     name     TEXT,
--     salary   NUMERIC
-- );

-- ============================================================================
-- Solution: DENSE_RANK handles duplicates correctly and returns NULL naturally
-- ============================================================================
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
--   1. Returns 0 rows (not NULL) when N > number of distinct salaries.
--      Interviewers explicitly ask for NULL.
--   2. OFFSET does not skip ties correctly if DISTINCT is removed.
--
-- Wrapping in MAX() or using COALESCE fixes the NULL requirement but the
-- DENSE_RANK version reads much more cleanly.

-- ============================================================================
-- Spark SQL note
-- ============================================================================
-- Identical query works in Spark SQL; just drop the :n parameter syntax
-- (Spark uses positional `?` or literal substitution depending on client).
