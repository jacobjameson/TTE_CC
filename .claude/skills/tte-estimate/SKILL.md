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
(Toolkit files — `reference/`, `R/` — live at the repo root, or `$TTE_CC_HOME` / `~/.tte_cc/` when
installed via `install.sh`; set `tte_root` in generated scripts to that location.)

## Step 0 — ALWAYS check the data format first (do not skip)
TTE requires **long / person-time** data: one row per person per follow-up interval, integer `time`
starting at 0, one row per (id, time), binary per-interval outcome. Read `reference/data-format.md`,
then **validate before any modelling**:
```r
check_person_time(data, id = "id", time = "time", outcome = "hosp")   # errors on fatal problems
```
If the data are **wide** (one row per person with a survival time + event), convert first:
```r
long <- to_person_time(wide, id = "id", surv_time = "surv_time", event = "event",
                       K = K, keep = <baseline covariates>)
```
For other shapes (one row per visit/claim), reshape to one row per person-interval at the time scale
where covariates/treatment/outcomes change, then re-run `check_person_time()`. Never run the engine on
data that hasn't passed this check. (A single outcome measured once per person is the exception — use
`point_effect()`.)

## Inputs to confirm before writing code
1. **Data**: path + confirmed long/person-time (Step 0) with `id`, a time variable, treatment,
   outcome, covariates.
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
- **IP weighting** (`mode = ipw`): `ip_weights()` builds stabilized treatment weights (and IPCW for
  informative loss to follow-up via `censor =`), truncates, and adds a `w` column; then estimate with
  `pooled_logistic_risk(..., weights = "w")` on uncensored (and, per the estimand, non-competing) rows.
  ```r
  w <- ip_weights(d, "A", covariates = conf, K = K, censor = "censor")
  pooled_logistic_risk(w[w$censor == 0 & w$death == 0, ], "A", K = K, weights = "w")
  ```
- **Sequential emulation** (`mode = sequential`): when `time-zero` says people are eligible at
  multiple times, `seq_emulate(d, elig = "elig", time = "cal_time", K = K)` stacks one trial per
  eligible start (adds `trial`, `fu`, `period`, `id_new`); estimate with `time = "fu"` and standardize
  over `period`; bootstrap at the **person** level (`boot_tte(..., id = "id")`).
- **Competing events**: transform first with `competing_events_transform(d, estimand = ...)` (see the
  `competing-events` skill), then estimate as above.
- **Cloning** (`mode = cloning`): for sustained strategies indistinguishable at time zero (see the
  `sustained-strategies` skill), `clone_censor_weight()` clones into the two arms, censors deviators,
  and builds the IP-of-censoring weights (exact timing: `lo == hi`; grace period: `lo < hi`); estimate
  with `treat = "arm"`. Only the per-protocol effect is estimable under cloning.
  ```r
  both <- clone_censor_weight(d, covariates = conf, arm0 = c(lo0, hi0), arm1 = c(lo1, hi1), K = K)
  pooled_logistic_risk(both[!is.na(both$hosp), ], treat = "arm", time = "time", K = K, weights = "w")
  ```

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

## Scope note
Supported modes: **rct**, **matching**, **standardize**, **ipw** (with IPCW), **sequential**,
**competing-events** transforms, and **cloning** (exact-timing and grace-period sustained strategies),
for time-to-event / continuous / binary outcomes. For distinguishable sustained strategies (Session 6)
the time-varying-IPW-with-deviation-censoring path can be assembled from `ip_weights()` extended over
follow-up; if a request needs a bespoke construction beyond the helpers, generate readable code from
the course recipe in `reference/course-map.md` rather than guessing.
