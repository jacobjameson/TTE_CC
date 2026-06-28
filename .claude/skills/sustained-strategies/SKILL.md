---
name: sustained-strategies
description: >
  Use when the treatment is sustained over time rather than a one-time decision at baseline — e.g.
  "initiate and continue therapy unless contraindicated", treatment with a duration, dose strategies,
  or strategies defined by WHEN/HOW LONG to treat. Decides static vs dynamic, whether time-varying
  confounding / treatment-confounder feedback requires g-methods, and whether the strategies are
  distinguishable at time zero (→ cloning) and need a grace period.
---

# Sustained treatment strategies

Most real clinical strategies are **sustained** ("start and keep treating unless X", "treat for D
years", "second dose within W weeks"), not point interventions at baseline. This skill sets up the
right estimand and routes to the right analysis. Read the Lecture-8/9 + Session-6/7/8 material in
`reference/course-map.md`. (Toolkit files at repo root or `~/.tte_cc/`.)

## 1. Point vs sustained
- **Point intervention** — treatment set once at baseline; only baseline confounding → use the
  ordinary `emulate-randomization` + `tte-estimate` path (matching/standardization/IPW).
- **Sustained strategy** — treatment is time-varying over follow-up; expect **time-varying
  confounding** → g-methods are generally required (see step 3).

## 2. Static vs dynamic
- **Static** — the same plan for everyone (e.g. "150 mg daily for 5 years").
- **Dynamic** — the plan depends on evolving patient state (e.g. "treat until a stroke", "initiate
  when CD4 < x"). Dynamic strategies are usually the clinically interesting ones; capture the decision
  rule precisely.

## 3. Treatment-confounder feedback ⇒ g-methods
Ask: is there a time-varying covariate that (a) predicts later treatment and the outcome, and (b) is
itself affected by earlier treatment? If yes, there is **treatment-confounder feedback**, and
conventional adjustment (stratify/regress on the covariate) is biased — you **must** use g-methods
(IP weighting of a marginal structural model, the g-formula, or g-estimation). Even without feedback,
time-varying confounding needs time-varying IP weights.

## 4. Distinguishable at time zero?
This determines whether you can assign arms from baseline data:
- **Distinguishable at time zero** (e.g. "initiate at baseline" vs "do not initiate") — assign at
  baseline; estimate the per-protocol effect with **time-varying IP weights + artificial censoring at
  deviation** (sequential emulation as needed). *(Session 6.)*
- **Indistinguishable at time zero** (e.g. "second dose by week 3" vs "by week 5"; "treat for 1 year"
  vs "2 years"; any duration/timing strategy where baseline data are compatible with several
  strategies) — you **cannot** assign from baseline without immortal-time bias. Use **cloning**:
  clone each person into every compatible strategy, **censor** a clone when its data deviate, and
  **IP-weight** to undo the censoring selection. *(Sessions 7–8.)* ⚠️ Under cloning, the ITT analog is
  not estimable — only the per-protocol effect.

## 5. Grace periods
If a strategy allows a window for an action ("initiate within 3 weeks of X"), that window is a **grace
period**: during it, not-yet-acting data are compatible with the strategy, so clones are not censored
until the window ends. Specify the window and how treatment is distributed within it
("natural"/as-observed vs "uniform"); the weights are built accordingly.

## Hand off to analysis (cloning mode)
For strategies indistinguishable at time zero (with or without a grace period), use the cloning helper
and the same risk engine:
```r
both <- clone_censor_weight(data, covariates = <time-varying + baseline confounders>,
                            arm0 = c(lo0, hi0), arm1 = c(lo1, hi1), K = K)  # lo==hi: exact; lo<hi: grace
est  <- pooled_logistic_risk(both[!is.na(both$hosp), ], treat = "arm", time = "time",
                             K = K, weights = "w")
```
Bootstrap at the person level; report the per-protocol effect. For distinguishable sustained strategies
(Session 6), use time-varying IP weights with deviation censoring instead (the `tte-estimate` IPW path,
extended over follow-up).

## Output
Append a **"Sustained strategy"** section to `target_trial_protocol.md`: static/dynamic; the precise
treatment rule(s); whether there is time-varying confounding / feedback (and therefore g-methods);
distinguishable-at-time-zero (and therefore cloning); any grace period and its within-window treatment
distribution; and that only the per-protocol effect is targeted under cloning. Then run the analysis
and recommend `check-emulation` and `tte-report`.
