-- Problem 15: Recursive Manager Hierarchy
--
-- Scenario
-- --------
-- A large tech company's people-analytics team rolls up org data along the reporting
-- hierarchy: for each employee, the chain of managers up to the CEO and
-- the hierarchy depth. The same query shape powers spend roll-ups by org,
-- category-tree walks on a large product catalog, and comment-thread
-- traversals anywhere threaded content exists.
--
-- Prompt
-- ------
-- Given `employees (employee_id, manager_id, name)` with NULL manager_id
-- at the root, for each employee return the chain of managers above them
-- and the total depth from the root.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Org roll-ups, category trees, and any parent-child
--                     graph in a relational warehouse rely on recursive
--                     CTEs or an equivalent iterative pattern.
-- Skill demonstrated:  Writing a recursive CTE end-to-end with a correct
--                      termination condition and cycle defence.
-- Business impact:     A recursive query that loops on dirty data (a
--                      cycle introduced during an org change) takes a
--                      warehouse job down and blocks downstream comp or
--                      spend reporting.

-- Schema
-- CREATE TABLE employees (
--     employee_id BIGINT PRIMARY KEY,
--     manager_id  BIGINT,           -- NULL for the CEO
--     name        TEXT
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Base case — each employee sits at their own level 0, pointing
--         at themselves, with the chain seeded as just their name.
-- Step 2: Recursive step — join the current row's manager_id back into
--         employees to add the next person above in the chain, bumping
--         depth and appending to the chain string.
-- Step 3: Carry a visited-id path and stop recursion if dirty data would
--         revisit an employee already in the chain.
-- Step 4: After recursion, per starting employee take the maximum depth
--         and the chain that terminates at the root (manager_id IS NULL).
WITH RECURSIVE manager_chain AS (
    -- Base case: each employee is at level 0 pointing at themselves
    SELECT
        employee_id       AS start_employee_id,
        employee_id,
        manager_id,
        name,
        0                 AS depth,
        name              AS chain,
        ARRAY[employee_id] AS visited_ids
    FROM employees

    UNION ALL

    -- Recursive step: join current row's manager onto employees to go up
    SELECT
        mc.start_employee_id,
        e.employee_id,
        e.manager_id,
        e.name,
        mc.depth + 1,
        mc.chain || ' -> ' || e.name,
        mc.visited_ids || e.employee_id
    FROM manager_chain mc
    JOIN employees e ON e.employee_id = mc.manager_id
    WHERE NOT e.employee_id = ANY(mc.visited_ids)
)
SELECT
    start_employee_id,
    MAX(depth)                                   AS depth_from_ceo,
    MAX(chain) FILTER (WHERE manager_id IS NULL) AS full_chain_to_ceo
FROM manager_chain
GROUP BY start_employee_id
ORDER BY depth_from_ceo DESC, start_employee_id;

-- ============================================================================
-- Direction & termination
-- ============================================================================
-- Walking UP (employee -> manager) terminates at NULL manager_id (root).
-- Walking DOWN (manager -> reports) terminates when no one reports to the
-- current node. Pick the direction based on what the question asks:
--
--   * "Chain of managers above me"      -> walk UP.
--   * "All reports (direct + indirect)" -> walk DOWN.
--   * "Total spend rolled up by org"    -> walk DOWN, aggregate per level.
--
-- Cycle defence: dirty data (rare but seen during mid-flight org changes)
-- causes infinite recursion unless the query carries a visited set. The
-- visited_ids array above stops before revisiting an employee already in
-- the current path; rows trapped in a cycle will have NULL full_chain_to_ceo.
--
-- Dialect support: this version is PostgreSQL-specific because it uses a
-- recursive CTE plus arrays. Spark SQL does NOT support recursive CTEs; on
-- Spark, either iterate in the application layer, flatten via N self-joins
-- up to a max depth, or use GraphFrames.
