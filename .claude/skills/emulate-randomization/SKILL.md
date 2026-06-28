---
name: emulate-randomization
description: >
  Use when deciding how to adjust for confounding in a target trial emulation — eliciting the set of
  baseline confounders, choosing an adjustment method (matching, standardization/g-formula, or IP
  weighting), and judging whether emulating randomization is even reasonable (vs. unmeasured /
  intractable confounding that may call for instrumental-variable approaches).
---

# Emulate randomization (adjust for confounding)

In an emulated trial, "assignment" is not random — you recreate it by adjusting for confounders.
This skill elicits the confounder set, picks an adjustment method, and stress-tests feasibility.
Read `reference/course-map.md` and `reference/glossary.md` first. Key framing: adjustment can never
be *verified* to be sufficient — only *falsified* (route to `check-emulation`).

## 1. Elicit confounders with subject-matter reasoning
A confounder is a pre-treatment common cause of treatment and outcome (identified by knowledge, not
statistics — confounders and non-confounders can look identical in data). Ask:
- *Why do some people get the treatment and others don't?* (indications, access, severity, calendar
  time, healthcare utilization, prior preventive behavior…)
- *What independently predicts the outcome?*
The intersection (pre-treatment) is your confounder set. Prompt specifically for usual suspects:
age, sex, calendar time, comorbidity/severity, healthcare utilization, prior use of related drugs/
preventive services. **Do not** include post-baseline variables (mediators/colliders) as baseline
confounders. List which confounders are **measured** vs **unmeasured/poorly measured**.

## 2. Choose an adjustment method
All of these target the same estimand if confounders are sufficient; pick by setting:
- **Matching** (exact / coarsened-exact) — intuitive, good with a modest set of categorical/coarsened
  confounders; yields a balanced matched cohort. (Used in `tte-estimate` mode `matching`.)
- **Standardization / g-formula** — model the outcome given treatment + confounders, predict under
  each treatment for everyone, average. Efficient; needs a correct outcome model.
- **IP weighting** — model treatment given confounders; weight to a pseudo-population. Use stabilized
  weights; truncate extremes. Natural for time-varying treatments/censoring (M3).
Recommend based on # confounders, continuous vs categorical, sample size, and whether time-varying
confounding/censoring is present. Use `AskUserQuestion` to record the choice.

## 3. Is emulating randomization reasonable at all?
Push back if not:
- **Unmeasured confounding** — key confounders absent (e.g. smoking/health-consciousness for
  screening-vs-mortality). The estimate will be biased; say so plainly.
- **Intractable confounding** — treatment is near-universally indicated by a prognostic factor
  (little overlap / positivity violation).
If confounding can't be credibly emulated, name it, and note that **instrumental-variable** methods
(L6) trade the no-unmeasured-confounding assumption for others (3 IV conditions + a 4th assumption;
not verifiable; often wide bounds) — flag for a future IV skill rather than forcing a biased adjusted
analysis. Always recommend a **positivity check** (overlap of the treated/untreated covariate or
propensity distributions).

## Output
Append an **"Emulating randomization"** section to `target_trial_protocol.md`: the confounder set
(measured vs unmeasured), the chosen adjustment method + rationale, positivity/overlap plan, and a
candid statement of residual-confounding risk. Hand the confounder list and method to `tte-estimate`,
and recommend `check-emulation` (negative controls, balance) afterward.
