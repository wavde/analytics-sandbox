# Analytics Sandbox

> A reference collection of analytics SQL problems with worked solutions, business framing, and notes on where each pattern breaks at scale.

Intended audience: practitioners brushing up on window-function patterns, candidates preparing for data science or analytics engineering interviews at large consumer tech companies, and interviewers assembling a question bank.

> **Note:** this repo has no CI. The SQL is reference material, not executed against a live schema.

## Contents

### [sql-interview-problems/](sql-interview-problems/): 18 problems

SQL problems written primarily for PostgreSQL, with Spark SQL and other dialect notes called out where the portable syntax differs. Recursive CTE examples, especially problem 15, are PostgreSQL-only unless a file explicitly describes a Spark alternative. Each problem is framed with a concrete production scenario (streaming sessionisation, payments merchant revenue, travel-marketplace cohort retention, event dedup) so the query is not abstract; it is the query a real team would run.

Two tiers:

- **Core (01–10):** window-function fundamentals. Sessionisation, funnels, retention curves, month-over-month growth, cohort tables. The patterns common to most first-round analytics SQL screens.
- **Advanced (11–18):** last-touch attribution, two-step funnels with timing, current streaks, percentile tails, recursive hierarchies, co-purchase pairs, path analysis, event deduplication. Patterns that show up past the warm-up round.

Each file is self-contained: scenario, prompt, schema, approach, solution, notes on pitfalls, and dialect differences.

## Out of scope

No ETL or pipeline code, no warehouse modelling, no answers to system-design interview questions. Each file is a short SQL reference, not a mini-project.

## License

MIT. See [LICENSE](LICENSE).
