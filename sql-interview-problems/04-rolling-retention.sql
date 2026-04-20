-- Problem 04: Rolling 7-Day Retention
--
-- Given a `user_activity` table with (user_id, active_date), compute D7
-- retention for each cohort day — i.e. of users first seen on day D,
-- what fraction were active on day D+7?

-- Schema
-- CREATE TABLE user_activity (
--     user_id      BIGINT,
--     active_date  DATE
-- );

-- ============================================================================
-- Solution
-- ============================================================================
WITH cohorts AS (
    SELECT user_id, MIN(active_date) AS cohort_date
    FROM user_activity
    GROUP BY user_id
),
retained AS (
    SELECT
        c.cohort_date,
        COUNT(DISTINCT c.user_id) AS cohort_size,
        COUNT(DISTINCT CASE WHEN a.active_date = c.cohort_date + INTERVAL '7 days'
                            THEN c.user_id END) AS retained_d7
    FROM cohorts c
    LEFT JOIN user_activity a
      ON a.user_id = c.user_id
     AND a.active_date = c.cohort_date + INTERVAL '7 days'
    GROUP BY c.cohort_date
)
SELECT
    cohort_date,
    cohort_size,
    retained_d7,
    ROUND(100.0 * retained_d7 / NULLIF(cohort_size, 0), 2) AS d7_retention_pct
FROM retained
ORDER BY cohort_date;

-- ============================================================================
-- Follow-ups interviewers like to ask
-- ============================================================================
-- 1. "What if we want rolling-7 retention" (active in any of D+1..D+7)?
--    -> change the CASE to: a.active_date BETWEEN c.cohort_date + 1 AND c.cohort_date + 7
--
-- 2. "What if D7 falls in the future (right-censoring)?"
--    -> exclude cohorts where cohort_date + 7 > CURRENT_DATE
--
-- 3. "How do you build a retention curve (D1, D7, D14, D30)?"
--    -> pivot by cohort_date and LEFT JOIN user_activity once per offset, or
--       use a single JOIN with EXTRACT(day FROM a.active_date - c.cohort_date)
--       and conditional aggregation.
