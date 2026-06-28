---
name: tte-estimate
description: >
  Use to generate and run the R analysis for a (specified) target trial emulation — estimating the
  causal effect after the protocol, time zero, and confounders are set. Dispatches by OUTCOME TYPE
  (time-to-event, continuous, binary) and ADJUSTMENT METHOD (none/RCT, matching, standardization,
  IP weighting) and writes a readable, course-faithful R script that calls the TTE_CC helpers.
---

# Estimate the effect (the analysis)

You generate **readable, course-faithful R** — never a black box — that estimates the target trial's
causal contrast. Build on the protocol from `target-trial`, the alignment decision from `time-zero`,
and the confounders/method from `emulate-randomization`. Read `reference/fidelity.md` and
`reference/course-map.md` for the exact recipes, and `reference/variables.md` for data conventions.

## Inputs to confirm before writing code
1. **Data**: path + that it is long/person-time (one row per person-interval) with `id`, a time
   variable, treatment, outcome, covariates. If not long, help reshape (or, for a single outcome
   measured once, that's fine — see below).
2. **Outcome type** (drives the engine):
   | Type | Helper | Estimand |
   |---|---|---|
   | time-to-event | `pooled_logistic_risk()` | risk difference/ratio over follow-up |
   | continuous (once) | `point_effect(type="continuous")` | mean difference |
   | binary (once / ever-by-K) | `point_effect(type="binary")` | risk difference/ratio |
3. **Adjustment method**: none (RCT/already-matched) · matching · standardization · IP weighting.
4. **Horizon K**, treatment column, confounder set, and whether sequential emulation is needed
   (from `time-zero`; the `seq_emulate` helper is M3 — if required, say so and stop short).

## Dispatch → which helper + how
- **RCT / no confounding** (`mode = rct`): call the engine directly, marginal.
  ```r
  pooled_logistic_risk(d, treat = "A", K = K)                 # time-to-event
  point_effect(d, "A", "Y", type = "continuous", K = K)       # continuous
  point_effect(d, "A", "Y", type = "binary", reduce = "ever", K = K)  # binary
  ```
- **Matching** (`mode = matching`): `match_cohort()` then estimate MARGINALLY on the matched cohort;
  check balance with `cobalt`; bootstrap must RE-RUN matching inside the statistic.
  ```r
  m <- match_cohort(d, "A", covariates = conf)
  cobalt::bal.tab(attr(m, "match"), un = TRUE)
  est <- pooled_logistic_risk(m, "A", K = K)
  ```
- **Standardization / g-formula** (`mode = standardize`): pass `covariates =` to the engine (it
  predicts under each treatment for everyone and averages).
  ```r
  pooled_logistic_risk(d, "A", K = K, covariates = conf)
  point_effect(d, "A", "Y", type = "continuous", covariates = conf)
  ```
- **IP weighting** (`mode = ipw`): build stabilized treatment (and, if needed, censoring) weights,
  truncate, pass `weights =`. (The reusable `ip_weights()` helper is M3; for a point/baseline
  treatment you may fit the weight model inline. If time-varying treatment/censoring is required,
  say it's M3 and stop short.)

## Inference (always)
Wrap the chosen estimator in `boot_tte(data, statistic, R, seed)` — **resampling persons (ids)** —
and put the *entire* pipeline (matching/weighting/modelling) inside `statistic` so it is re-run per
resample. Default `R = 500` (state that >= 500–1000 is needed; small R is for quick checks only).
For sequential-emulation data, resample at the person level (ID-clustered).

## Always produce
1. A self-contained **`analysis_<name>.R`** in the user's working directory that sources the TTE_CC
   helpers (set a `tte_root` path at the top), loads their data, and runs: descriptive check →
   adjustment → estimate → bootstrap CIs → a `tte_riskplot()` figure (for risk outcomes).
   Comment each block and cite the mirrored session.
2. A short **results summary** (point estimate + 95% CI for RD/RR or MD) and a one-line interpretation
   in target-trial language (effect of *assignment to* / *adhering to* strategy 1 vs 0).
3. If the data are observational, recommend running `check-emulation` next (negative controls,
   balance, positivity) and remind that estimates are valid only under no-unmeasured-confounding.

## M2 scope note
`tte-estimate` ships modes **rct** and **matching** first (plus standardization via the engine's
`covariates=`). Sequential emulation, time-varying IP weighting, competing-events transforms, and
cloning/grace are M3+ — when a request needs them, generate as much as is supported and clearly flag
the remaining step as not-yet-implemented rather than improvising fragile code.
