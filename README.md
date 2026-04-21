# Analytics Sandbox

> A reference collection of FAANG-scale analytics SQL problems, with worked
> solutions, business framing, and notes on where each pattern breaks at scale.
> Useful for anyone preparing for — or designing — data science and analytics
> engineering interviews at large consumer tech companies.

> **Note:** This repo has no CI. The SQL is reference material; it is not
> executed against a live schema.

## Contents

### 🧮 [sql-interview-problems/](sql-interview-problems/) — 18 problems

FAANG-style SQL problems written in standard PostgreSQL, with Spark SQL and
other dialect notes where the portable syntax differs. Each problem is framed
with a concrete production scenario (streaming-service sessionisation,
payments-platform merchant revenue, travel-marketplace cohort retention,
social-platform event dedup, etc.) so the query isn't
abstract — it's the thing a real team would actually run.

Split into two tiers:

- **Core (01–10):** window-function fundamentals — sessionisation, funnels,
  retention curves, month-over-month growth, cohort tables. The patterns that
  show up in most first-round analytics SQL screens.
- **Advanced (11–18):** last-touch attribution, two-step funnels with timing,
  current streaks, percentile tails, recursive hierarchies, co-purchase pairs,
  path analysis, event deduplication. The patterns that show up when the
  interview moves past warm-ups.

Each file is self-contained: scenario, prompt, schema, approach, solution, and
notes on pitfalls, tradeoffs, and dialect differences.

## License

MIT — see [LICENSE](LICENSE).
