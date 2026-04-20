# Analytics Sandbox

> FAANG-style SQL interview problems with solutions and commentary. A lower-polish reference — not every idea deserves its own repo.

> **Note:** This repo has no CI; SQL is for reference, not executed.

## Contents

### 🧮 [sql-interview-problems/](sql-interview-problems/) — 18 problems

FAANG-style SQL problems solved in standard Postgres (with Spark SQL notes).
Split into two tiers:

- **Core (01–10):** window-function fundamentals — sessionisation, funnels,
  retention curves, MoM growth, cohort tables. The patterns every senior
  analyst should be able to write from scratch.
- **Advanced (11–18):** last-touch attribution, two-step funnels with
  timing, current-streak, percentile tails, recursive hierarchies,
  co-purchase pairs, path analysis, event dedup.

Each file is self-contained — prompt, schema, solution, and a short note on
where the pattern generalises and where it breaks.

## License

MIT — see [LICENSE](LICENSE).
