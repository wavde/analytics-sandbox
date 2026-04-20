-- Problem 15: Recursive Manager Hierarchy
--
-- Given `employees` (employee_id, manager_id, name), for each employee return
-- the chain of managers above them and the total hierarchy depth (0 = CEO).
--
-- Why this is asked: recursive CTEs are the one SQL feature most analysts
-- haven't written end-to-end. They come up not just for org charts but for
-- category trees, comment threads, spend roll-ups, and graph traversal.

-- Schema
-- CREATE TABLE employees (
--     employee_id BIGINT PRIMARY KEY,
--     manager_id  BIGINT,           -- NULL for the CEO
--     name        TEXT
-- );

-- ============================================================================
-- Solution: recursive CTE walking UP from each employee to the root
-- ============================================================================
WITH RECURSIVE manager_chain AS (
    -- Base case: each employee is at level 0 pointing at themselves
    SELECT
        employee_id       AS start_employee_id,
        employee_id,
        manager_id,
        name,
        0                 AS depth,
        name              AS chain
    FROM employees

    UNION ALL

    -- Recursive step: join current row's manager onto employees to go up
    SELECT
        mc.start_employee_id,
        e.employee_id,
        e.manager_id,
        e.name,
        mc.depth + 1,
        mc.chain || ' -> ' || e.name
    FROM manager_chain mc
    JOIN employees e ON e.employee_id = mc.manager_id
)
SELECT
    start_employee_id,
    MAX(depth)                              AS depth_from_ceo,
    MAX(chain) FILTER (WHERE manager_id IS NULL) AS full_chain_to_ceo
FROM manager_chain
GROUP BY start_employee_id
ORDER BY depth_from_ceo DESC, start_employee_id;

-- ============================================================================
-- Direction & termination
-- ============================================================================
-- Walking UP (employee -> manager) always terminates at NULL manager_id (CEO).
-- Walking DOWN (manager -> reports) terminates when no one reports to the
-- current node. Pick the direction based on what you're asked:
--
--   * "Chain of managers above me"      -> walk UP.
--   * "All reports (direct + indirect)" -> walk DOWN.
--   * "Total spend rolled up by org"    -> walk DOWN, aggregate per level.
--
-- Cycle defence: if the data is dirty (rare but happens during org changes),
-- cycles cause infinite recursion. Add a depth guard: WHERE depth < 20, or
-- carry a visited-set via array_append + NOT(... = ANY(visited)).
--
-- Spark SQL does NOT support recursive CTEs. On Spark, either iterate in the
-- application layer, flatten via N self-joins up to a max depth, or use
-- GraphFrames. In most interviews Postgres / Snowflake / BigQuery syntax is
-- accepted; say so upfront.
