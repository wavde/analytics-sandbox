-- Problem 10: Cohort retention table (Day-0 / Day-7 / Day-30)
--
-- Given a `users` table (signup cohort) and an `events` table (user activity),
-- produce a pivoted retention table showing, per signup-week cohort,
-- the % of users still active in Day-1-through-7, Day-8-through-14, etc.
--
-- This is the one chart every PM wants. The 7-day cohort-retention heatmap
-- was the original "North-star visualization" at Facebook, Airbnb, and
-- Spotify. Know the pattern.

-- Schema
-- CREATE TABLE users  (user_id BIGINT, signup_date DATE);
-- CREATE TABLE events (user_id BIGINT, event_time TIMESTAMP);

-- ============================================================================
-- Solution: bucket by "days since signup" then pivot
-- ============================================================================
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
-- Gotchas interviewers probe
-- ============================================================================
-- 1. Days-since-signup should use DATE DIFFERENCE (not time), or you'll
--    miscount events that happened hours-but-not-a-full-day later.
-- 2. Bucket edges: "w1" could mean days 1-7 OR days 1-6 depending on
--    convention. Be explicit.
-- 3. The cohort SIZE denominator is the number of users who SIGNED UP in
--    that cohort week, not the number who were active on Day 0. Mixing
--    these up produces > 100% retention in later buckets (which happens
--    in production dashboards more often than you'd think).
-- 4. At scale, pre-aggregate per (cohort_week, user_id, bucket) in a
--    materialized view; the pivot is cheap, the join is not.
--
-- Spark SQL: identical, use datediff() instead of DATE_DIFF().
