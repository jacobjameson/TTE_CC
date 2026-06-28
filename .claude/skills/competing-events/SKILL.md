---
name: competing-events
description: >
  Use when the outcome can be precluded by another event — e.g. death before the outcome of interest,
  or any "competing event" / "truncation event" — and you must choose and justify a causal estimand
  before analysis. Also use when loss to follow-up is present and you need to frame it as a joint
  intervention on treatment and censoring. Forces an explicit estimand and flags the common
  controlled-direct-effect trap.
---

# Competing events: choose the estimand (there is no single causal question)

When a **competing event** makes the outcome impossible (e.g. death before dementia), there is no
single "the effect" — different estimands answer different questions under different assumptions.
Your job is to make the choice explicit and honest. Read Lecture-7 / Session-5 material in
`reference/course-map.md` (Competing events). (Toolkit files at repo root or `~/.tte_cc/`.)

## First, classify the event
- **Competing event** — makes the outcome *impossible* (death before the outcome). 
- **Truncation event** — makes the outcome *undefined* (death before a score that would be measured).
Confirm which you have; the rest of this skill addresses competing events.

## Force a choice among the five estimands (state the assumption each needs)
Use `AskUserQuestion` to pick one (or a primary + secondary), and record why:
1. **Composite outcome** — risk of (outcome **or** competing event). Sidesteps the competing event but
   *changes the question*; the estimate can be driven by the competing event. Assumption: no
   unmeasured confounding of treatment and the composite.
2. **Total effect** ("eternally outcome-free") — effect on the outcome capturing *all* pathways,
   including through the competing event. A protective-looking estimate may just reflect lethality.
   Often the most interpretable "what happens to the outcome" question.
3. **Controlled direct effect** — effect "had no one experienced the competing event." **Usually not a
   meaningful estimand**: it invokes an impossible intervention (abolish all deaths) and requires the
   strong, unverifiable assumption of **no unmeasured common causes of the competing event and the
   outcome**. ⚠️ This is the *implicit* estimand whenever someone silently censors at the competing
   event — call that out.
4. **Separable direct effect** — needs a subject-matter decomposition of treatment into components
   acting on the outcome vs. on the competing event (mediation-style). Only if such a decomposition is
   scientifically credible.
5. **Survivor average causal effect** — effect among "always-survivors", an unidentifiable subgroup;
   needs a monotonicity assumption. Rarely of direct policy interest.

**Push back:** if the user is "just censoring at death," surface that this targets the controlled
direct effect and its unreasonable assumption; recommend the total effect or composite unless they can
defend the decomposition (separable) or the subgroup (survivor-average).

## Loss to follow-up (related but distinct)
Frame LTFU as a **joint intervention on treatment and censoring**: the target is the risk "had no one
been lost to follow-up." Correct it with **inverse-probability-of-censoring weights** (IPCW), not by
ignoring dropouts. At minimum, report losses to follow-up by arm.

## Hand off to analysis
Map the chosen estimand to the data transform, then run `tte-estimate` on the result:
- **total** → `competing_events_transform(data, estimand = "total", K = K)` (extends decedents to K,
  outcome-free), then `pooled_logistic_risk()`.
- **composite** → `competing_events_transform(..., estimand = "composite")`.
- **controlled** → `competing_events_transform(..., estimand = "controlled")` (death as censoring) —
  only with the no-unmeasured-common-causes caveat stated.
- **LTFU** → add `censor = "<censor col>"` in `ip_weights()` (IPCW).

## Output
Append a **"Competing events"** section to `target_trial_protocol.md`: the event classification, the
chosen estimand + the assumption it requires, the data transform used, and the LTFU/IPCW plan. State
plainly which questions the analysis does and does not answer.
