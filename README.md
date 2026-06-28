# Preply Case Study - Analytics Engineer

A dbt project that estimates breakage revenue — the value of purchased lesson
hours that students never consume — and usage revenue (20% of used hours) for every 28-day payment cycle. Completed
cycles report *actual* breakage; cycles still open at the as-of date get a
*cohort-based prediction*. The single output is `mart_cycle_revenue`.

---

## How to run it

**Prerequisites**

- `dbt-core` and the adapter for your warehouse (developed against a single warehouse target; BigQuery/DuckDB/Snowflake all work)
- A `profiles.yml` entry matching the `profile:` in `dbt_project.yml`
- The three source CSVs in `seeds/` (`raw_students`, `raw_payments`, `raw_lessons`)

**Run it**

```bash
dbt deps          # install packages (dbt_utils etc.)
dbt seed          # load the three raw CSVs as tables
dbt build         # run + test every model in dependency order
```

`dbt build` runs models and their tests together. To build just one layer or one
lineage:

```bash
dbt build -s staging          # staging models only
dbt build -s +mart_cycle_revenue   # the mart and everything upstream of it
```

**Explore the lineage**

```bash
dbt docs generate && dbt docs serve
```

---

## Approach 

Breakage is defined per cycle as:

```
breakage = (hours_purchased - hours_used) * price_per_hour
```

For a **completed** cycle (its 28-day window has closed on or before the current date) we know exactly how many of the purchased hours were used.

For an **open** cycle the window hasn't closed and the student
may still book more hours. We have to forecast the final breakage. I chose an
**empirical cohort-rate** method over a parametric or ML model for three reasons:

1. **It's defensible to a finance/PayOps audience.** Every predicted dollar traces
   back to "students like this one historically left X% of hours unused." That
   explainability is highly valuable to non-technical stakeholders.
2. **It's robust on a small dataset.** With ~8,800 completed cycles a
   cohort average is stable, whereas a heavier model would overfit.
3. **It conditions on the things that actually move breakage** such as who the student
   is and where they are in their lifecycle.

Two deliberate guardrails:

- **Rates are learned from completed cycles only.** Open cycles look artificially
  high-breakage because they're unfinished; including them would bias the rates
  upward.
- **Predictions are floored by usage already observed.** A student who has booked
  all their hours mid-cycle has zero breakage regardless of the cohort average, so
  predicted breakage can never exceed hours not yet consumed.

---

## The data model

Layered seed → staging → intermediate → mart. Grain is stated for each model.

```
seeds                staging          intermediate                                  mart
-----                -------          ------------                                  ----
raw_payments  ─►  stg_payments  ─►  int_payment_cycles ─┐
raw_lessons   ─►  stg_lessons   ─►  int_lesson_cycle_mapping ─┤
raw_students  ─►  stg_students  ─────────────────────────────┴─► int_cycle_usage ─┬─► int_cycle_revenue_completed ─┐
                                                                                   │            │                   │
                                                                                   │            ▼                   ▼
                                                                                   │   int_cohort_breakage_rates    │
                                                                                   │            │                   │
                                                                                   └──────────► int_cycle_revenue_predicted ─► mart_cycle_revenue
```

**Staging** — one model per source, 1:1 with the seed. Light renaming/typing only.

**Intermediate**

- `int_payment_cycles` — one row per payment with the 28-day window it opens
  (`start_date`, `end_date`) and `lifetime_payment_number` (the payment's order in
  the student's lifetime). 
- `int_lesson_cycle_mapping` — each lesson attributed to the cycle whose window it
  falls inside, via a range join on student + booking timestamp.
- `int_cycle_usage` — one row per cycle with `hours_purchased`, `hours_used`,
  breakage, the open/closed flag, and cohort attributes joined in from the student.
- `int_cohort_breakage_rates` — average breakage and usage rate per cohort, learned from
  **completed cycles only**.
- `int_cycle_revenue_completed` — actual breakage and usage revenue for completed cycles.
- `int_cycle_revenue_predicted` — predicted breakage revenue for open cycles
  (cohort rate × purchased hours, floored by usage-so-far). 

**Mart**

- `mart_cycle_revenue` — completed actuals and open-cycle predictions, one
  row per cycle, with an `is_complete` flag so consumers can always
  separate measured from modelled.

A **cohort** is `persona` × tenure x price per hour so thin cells with
too few completed cycles don't produce noisy rates.

---

## Key assumptions & trade-offs

Things decided without enough information to be certain:

- **Cycles are exactly 28 days and back-to-back.** The dataset spaces each student's
  payments exactly 28 days apart, so windows don't overlap and every lesson maps to
  at most one cycle. Real payment timing (such as multiple subscriptions per student or overlaps) would break this and
  require overlap handling.
- **Cohort = persona × tenure x price bucket.** I assumed these three drive breakage most. Country,
  first subject, acquisition channel, and hours tier were left out to avoid
  fragmenting cohorts into cells too small to trust. 
- **A booked lesson equals a consumed hour.** `hours_booked` is treated as hours
  used. No-shows, cancellations, or partial attendance aren't modelled. 
- **Flat per-hour pricing within a cycle.** Breakage values unused hours at the
  cycle's `price_per_hour`. No discounts, refunds, or FX are applied.

---

## Caveats & limitations — read before using

For the PayOps team specifically:

- **Predicted breakage is an estimate, not recognised revenue.** The predictions callouts
  exist precisely so you can exclude the modelled portion from anything that
  needs measured-only numbers. Don't book predictions as actuals.
- **The number is only as good as the cohort match.** A student in a small or
  unusual cohort gets a coarser, less precise prediction. Treat the predicted layer as directional at the individual-cycle level;
  it's most reliable in aggregate.
- **All open cycles are currently treated the same regardless of how far through
  their window they are** (see next section) — so a cycle on day 2 and a cycle on
  day 26 get the same expected rate, which under/over-states individual cycles even
  where the aggregate is reasonable.
- **Synthetic data.** Relationships are cleaner than production. Expect real data to
  carry nulls, late-arriving lessons, refunds, and timing irregularities this model
  doesn't yet handle.

---

## What I'd do next

**Make the prediction time-aware.** Today every open cycle gets its
cohort's full-cycle breakage rate, treating a cycle that's two days old the same as
one that's nearly closed. I'd build a per-cohort **intra-cycle consumption curve** with cumulative share of hours typically used by day
*d* of the 28-day window, and predict each open cycle conditional on how many days
are left and how much it has already consumed. A
cycle far along with low usage would correctly read as high-breakage; a fresh cycle
would lean on the cohort baseline. This directly fixes the "all open cycles treated
equally" limitation above.

If there were more time after that:

- **A backtest harness** — hold out a slice of completed cycles, predict them as if
  open, and report error so the method is validated.
  This also lets me tune the cohort definition empirically.
- **Confidence bands** on predicted breakage, so PayOps sees a range rather than a false-
  precision point estimate.
- **Richer cohorts where the data supports it** — fold in hours tier or other data points once the
  curve approach reduces reliance on coarse averages.
- **As-of date variable** in dbt, so that anyone can rerun the predictions as of a certain date to assert historical auditability of our predictions as compared to reality. 
- **Saved queries and documentation in semantic files** to allow for agentic analysis of the dataset. 

---
 
## AI usage note
 
I used an AI assistant (Claude) as a co-programmer and editor throughout this
task, while keeping the modelling decisions, the logic, and the final review my own.
 
**Where it helped**
 
- Drafting documentation and dbt tests — the `schema.yml` files, column
  descriptions, and the `unique` / `not_null` / `relationships` / `accepted_values`
  tests across the staging and intermediate layers.
- Pressure-testing the model design. It pushed me toward flooring predictions by usage
  already observed.
- Practical how-to for the presentation and BI layer — the Looker vs Looker Studio
  distinction, planning the dashboard, and formatting/structuring this README.

**Where I rejected or corrected it**
 
- It occasionally produced documentation that was wrong or drifted from what a column
  actually contained. I rewrote those descriptions to match the real behaviour, but
  it had at least given me correct, consistent formatting to build on.
- It sometimes proposed more structure than the problem needed. I simplified naming
  and collapsed steps where a model wasn't needed.

**How I verified the output**
 
- Ran `dbt build` (`dbt run` + `dbt test`) so every model compiled and all tests
  passed before trusting any of it. 
- Read every generated description and test against the actual columns and sample
  rows rather than taking the text at face value.
- Hand-checked the core logic against the data, including the breakage formula, the open vs
  completed split, and a few cohort rates, to confirm the numbers were right.