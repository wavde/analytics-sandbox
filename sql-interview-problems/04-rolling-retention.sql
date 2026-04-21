-- Problem 04: Rolling 7-Day Retention
--
-- Scenario
-- --------
-- Spotify's subscription team tracks new-subscriber retention: of users who
-- first appeared on day D, what fraction came back on day D+7? The D7
-- retention curve is one of the inputs to the LTV model and is reviewed
-- weekly alongside churn and reactivation.
--
-- Prompt
-- ------
-- Given `user_activity (user_id, active_date)`, compute D7 retention by
-- cohort day — of users first seen on day D, what fraction were active on
-- exactly day D+7?
--
-- Why this problem matters
-- ------------------------
-- Business relevance: D7 retention by cohort feeds LTV modelling, acquisition
--                     payback calculations, and the weekly subscription
--                     growth review.
-- Skill demonstrated:  Correct cohort-denominator arithmetic and left joins
--                      that preserve zero-retention cohorts rather than
--                      dropping them.
-- Business impact:     A silently dropped cohort or an off-by-one day makes
--                      acquisition channels look more or less efficient than
--                      they are, skewing paid-marketing spend decisions.

-- Schema
-- CREATE TABLE user_activity (
--     user_id      BIGINT,
--     active_date  DATE
-- );

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Derive each user's cohort date (first active day).
-- Step 2: LEFT JOIN the activity table on exactly cohort_date + 7 so cohorts
--         with zero D7 activity still appear with retained_d7 = 0.
-- Step 3: Divide retained users by cohort size, guarding the denominator
--         with NULLIF.
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
-- Common follow-ups
-- ============================================================================
-- 1. Rolling-7 retention (active on any of D+1..D+7):
--      change the JOIN to: a.active_date BETWEEN c.cohort_date + 1 AND c.cohort_date + 7
--
-- 2. Right-censoring when D+7 is in the future:
--      exclude cohorts where cohort_date + 7 > CURRENT_DATE.
--
-- 3. Full retention curve (D1, D7, D14, D30):
--      pivot by cohort_date and LEFT JOIN user_activity once per offset, or
--      use a single JOIN with EXTRACT(day FROM a.active_date - c.cohort_date)
--      and conditional aggregation. At scale the single-join form with a
--      pre-aggregated daily activity table is usually cheaper than multiple
--      self-joins.
