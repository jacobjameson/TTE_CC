# Methodology reference — the TTE recipe this toolkit follows

This is the condensed "bible" the skills read. It summarizes the target-trial-emulation framework as
taught in the CAUSALab TTE course (Sessions 1–8) and grounds every skill. It is a methodological
summary in our own words — no course materials are reproduced.

## The spine
Two-step algorithm:
1. **Ask a well-defined causal question** = specify the protocol of the **target trial** (the
   hypothetical *pragmatic* RCT you would run).
2. **Answer it** = conduct the trial, or **emulate it** with observational data + appropriate
   causal-inference analytics.

> If a causal question cannot be written as a target trial, it is not well-defined.

### The 8 protocol elements (always in this order)
1. Eligibility criteria
2. Treatment strategies
3. Assignment
4. Outcomes
5. Follow-up
6. Causal contrasts (intention-to-treat + per-protocol)
7. Identifying assumptions
8. Data analysis

Specify (Step 1) → Emulate (Step 2) maps each element to a **data mapping**; follow-up stays the same;
contrasts become *observational analogs*; assignment becomes *emulate randomization via confounding
adjustment*.

## Non-negotiable rules (what the skills enforce / push back on)
- **Pragmatism.** Observational data cannot emulate: a placebo arm (only "usual care"), blinded
  assignment, treatment strategies that don't exist in the real world, or tight monitoring that
  doesn't happen in practice.
- **Time-zero alignment.** For each person, eligibility met = treatment strategy assigned = outcome
  follow-up starts — the three must coincide. Misalignment ⇒ immortal-time / selection bias.
- **Incident users, not prevalent users.** "Current vs. never user" is a biased, clinically
  irrelevant contrast → reframe as initiators vs. non-initiators.
- **No more, no less data.** Every protocol item must map to a measured variable.
- **Order matters.** Specify → emulate → *then* statistics. No method rescues a bad question.
- **Eligibility at baseline only; enforce a washout.**
- **Design biases vs. data biases.** TTE removes *design* biases (immortal time, prevalent-user
  selection); it does **not** remove *data* biases (confounding, measurement error).

## The canonical estimation engine (every session)
1. Pooled logistic regression for the discrete-time hazard of the per-interval binary outcome:
   `outcome ~ A + time + time^2 + A:time + A:time^2` (quadratic time on the logit scale; treatment×time
   products let the effect vary over time and avoid a proportional-hazards assumption).
2. Predict hazards `h(t)` for `t = 0..K-1` under A=0 and A=1.
3. Survival `S(t) = cumprod(1 - h(t))`.
4. Risk `= 1 - S(t)`.
5. K-period **risk difference** = risk1 − risk0; **risk ratio** = risk1 / risk0.
6. **Bootstrap by resampling persons (IDs)**, percentile CIs; re-run the *entire* pipeline
   (matching/weighting/modelling) in each resample. (Course uses R=2 "for illustration"; use ≥500.)
- Nonparametric cross-check: Kaplan–Meier (`Surv(time, time+1, outcome)`, log-log CIs).
- Continuous outcome: mean difference at end of follow-up.

## Method progression (Sessions)
| S | Adds |
|---|------|
| 1 | RCT: KM + pooled-logistic risks; bootstrap; functional-form sensitivity |
| 2 | Observational emulation; **matching** (exact/coarsened) for time-fixed confounding; balance |
| 3 | **Sequential trials** (`seq.em` stacking; ID-clustered bootstrap); the 3 wrong time-zero designs |
| 4 | **Standardization (g-formula)** and **IP weighting** (stabilized, truncated); standardize over baseline period |
| 5 | Loss-to-follow-up **IPCW**; competing events (total / composite / controlled-direct-effect) |
| 6 | Time-varying confounding for sustained strategies; per-protocol; deviation censoring + time-varying IPW *(v2)* |
| 7 | **Cloning** when strategies are indistinguishable at time zero + censoring + IPW *(v2)* |
| 8 | **Grace periods** (natural vs. uniform weighting) *(v2)* |

## Checking the emulation (Lecture 5)
Cannot *verify* no-unmeasured-confounding — only *falsify*. Tools: **negative outcome / treatment /
population controls**, covariate balance, positivity / weight-distribution checks, and benchmarking to
a randomized trial when one exists.

## Competing events (Lecture 7) — pick ONE estimand
composite outcome · **total effect** · controlled direct effect (ill-defined; needs no-unmeasured-
common-causes) · separable direct effect · survivor-average causal effect. State the assumption each
requires. Loss to follow-up = a *joint intervention on treatment and censoring* → IPCW.

## When emulation is not reasonable (Lecture 6)
Unmeasured/intractable confounding → instrumental-variable approaches (3 conditions, not verifiable;
need a 4th assumption — homogeneity or monotonicity — for a point estimate). "Not a cure-all."

## Reporting (Lectures 4, 10)
Causal language belongs in Title/Intro/Methods/Discussion; **never in Results**. Always report losses
to follow-up by arm. Ask of any observational estimate: *"What is the target trial?"*
