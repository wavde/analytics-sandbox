-- Problem 10: Cohort Retention Table (Day-0 / Week-1 / Week-2 / ...)
--
-- Scenario
-- --------
-- A travel-marketplace growth team runs a weekly-cohort retention heatmap: for each
-- signup week, the percentage of users still active in day 0, week 1,
-- week 2, weeks 3–4, weeks 5–8. The chart is the one every growth review
-- opens on, and it's the single view that best describes whether a product
-- change bent the retention curve.
--
-- Prompt
-- ------
-- Given `users (user_id, signup_date)` and `events (user_id, event_time)`,
-- produce a pivoted retention table where each row is a signup-week cohort
-- and each column is the percentage of users still active in a given
-- days-since-signup bucket.
--
-- Why this problem matters
-- ------------------------
-- Business relevance: Cohort retention heatmaps are a primary diagnostic
--                     for product changes, onboarding experiments, and
--                     channel-quality comparisons.
-- Skill demonstrated:  Careful cohort-denominator arithmetic, bucketing
--                      days-since-signup, and pivoting output with
--                      conditional aggregation.
-- Business impact:     A denominator swap (active-on-day-0 vs signed-up)
--                      produces retention numbers greater than 100% in
--                      later weeks — a visible error that shows up in
--                      shipped dashboards more often than it should.

-- Schema
-- CREATE TABLE users  (user_id BIGINT, signup_date DATE);
-- CREATE TABLE events (user_id BIGINT, event_time TIMESTAMP);

-- ============================================================================
-- Approach
-- ============================================================================
-- Step 1: Assign each user to a signup-week cohort.
-- Step 2: For each (user, event) compute days-since-signup and bucket into
--         d0 / w1 / w2 / w3_4 / w5_8.
-- Step 3: Count distinct users hitting each bucket per cohort.
-- Step 4: Divide by the cohort's signup count (NOT the day-0 active count)
--         and pivot the buckets into columns.
WITH cohort_users AS (
    SELECT
        user_id,
        DATE_TRUNC('week', signup_date)::DATE AS cohort_week
    FROM users
),
activity AS (
    SELECT
        c.cohort_week,
        c.user_id,
        DATE_DIFF('day', u.signup_date, e.event_time::DATE) AS days_since_signup
    FROM events e
    JOIN users u  ON u.user_id = e.user_id
    JOIN cohort_users c ON c.user_id = e.user_id
    WHERE e.event_time::DATE >= u.signup_date
),
bucketed AS (
    SELECT
        cohort_week,
        user_id,
        CASE
            WHEN days_since_signup = 0                       THEN 'd0'
            WHEN days_since_signup BETWEEN 1  AND 7          THEN 'w1'
            WHEN days_since_signup BETWEEN 8  AND 14         THEN 'w2'
            WHEN days_since_signup BETWEEN 15 AND 28         THEN 'w3_4'
            WHEN days_since_signup BETWEEN 29 AND 56         THEN 'w5_8'
        END AS bucket
    FROM activity
    WHERE days_since_signup BETWEEN 0 AND 56
),
cohort_size AS (
    SELECT cohort_week, COUNT(*) AS n_signed_up
    FROM cohort_users
    GROUP BY cohort_week
)
SELECT
    b.cohort_week,
    cs.n_signed_up,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN b.bucket = 'd0'    THEN b.user_id END)
               / cs.n_signed_up, 1) AS d0_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN b.bucket = 'w1'    THEN b.user_id END)
               / cs.n_signed_up, 1) AS w1_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN b.bucket = 'w2'    THEN b.user_id END)
               / cs.n_signed_up, 1) AS w2_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN b.bucket = 'w3_4'  THEN b.user_id END)
               / cs.n_signed_up, 1) AS w3_4_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN b.bucket = 'w5_8'  THEN b.user_id END)
               / cs.n_signed_up, 1) AS w5_8_pct
FROM bucketed b
JOIN cohort_size cs USING (cohort_week)
GROUP BY b.cohort_week, cs.n_signed_up
ORDER BY b.cohort_week;

-- ============================================================================
-- Gotchas
-- ============================================================================
-- 1. Days-since-signup should use DATE DIFFERENCE (not raw timestamp math),
--    or events that happen hours-but-not-a-full-day later get miscounted.
-- 2. Bucket edges: "w1" could mean days 1–7 or days 1–6 depending on
--    convention. Be explicit and write the convention down next to the chart.
-- 3. The cohort SIZE denominator is the number of users who SIGNED UP in
--    that cohort week, not the number active on Day 0. Mixing these up
--    produces > 100% retention in later buckets — a bug that ships to
--    production dashboards more often than anyone admits.
-- 4. At scale, pre-aggregate per (cohort_week, user_id, bucket) in a
--    materialised view; the pivot is cheap, the join is not.
--
-- Spark SQL: identical; use datediff() in place of DATE_DIFF().
