---
name: time-zero
description: >
  Use when defining or auditing "time zero" (start of follow-up) in a target trial emulation —
  when an analysis needs to align eligibility, treatment assignment, and start of follow-up, when
  there is risk of immortal-time or prevalent-user selection bias, when individuals are eligible at
  multiple times, or to decide between a single emulated trial and sequential (nested) trials.
---

# Get time zero right (the low-hanging fruit)

Incorrect time-zero specification — not unmeasured confounding — is the most common, most fixable
cause of failed observational analyses. Your job: make eligibility, treatment assignment, and start
of follow-up **coincide** for every person, and choose how to handle people eligible at multiple
times. Read `reference/glossary.md` and `reference/course-map.md` first.

## The core rule
> For each person, **time zero** is the single instant when (1) eligibility criteria are met,
> (2) the treatment strategy is assigned, and (3) outcome follow-up begins. These three must be the
> same instant. Eligibility is assessed using only information available *at or before* time zero.

## Audit the proposed design against the three classic errors
Ask how the user currently defines, for each arm: when eligibility is checked, when treatment status
is set, and when the clock starts. Then check:

- **Error 1 — different time zero per arm.** e.g. treated arm starts at treatment date, untreated arm
  starts at first eligibility. ⇒ **immortal time bias** (the treated must survive to treatment).
  Fix: a common, well-defined time zero for both arms.
- **Error 2 — assignment by future ("ever treated").** Classifying someone as "treated" if they are
  treated *anytime* during follow-up. ⇒ immortal time / selection bias. Fix: assign by status *at*
  time zero (initiators), or use cloning if strategies are indistinguishable at time zero (v2).
- **Error 3 — look-back selection.** Picking the treated group by treatment received *before* a fixed
  calendar time zero, where pre-baseline treatment can affect eligibility. ⇒ selection bias
  (the postmenopausal-hormone-therapy error). Fix: assess eligibility and assign at the same instant,
  no look-ahead.

Name the bias explicitly when you spot it, and propose the corrected design.

## Multiple eligible times
If a person can meet eligibility at many times (common in EHR/claims), there is no single natural
time zero. Two valid choices — help the user pick:
- **Random eligible time** — simple; pick one eligible time per person at random.
- **Every eligible time → sequential (nested) trials** — emulate a new trial starting at each
  eligible time and pool. More statistically efficient (narrower CIs), at the cost of within-person
  correlation that must be handled by **ID-clustered / bootstrap inference**.
Recommend sequential emulation when estimates are otherwise imprecise (few initiators/events).
Decide the trial cadence from the data's measurement schedule (e.g. weekly/monthly).

Use `AskUserQuestion` to record: single vs sequential; if sequential, the cadence and number of trials.

## Output
Append a **"Time zero"** section to `target_trial_protocol.md` (or write `time_zero_decision.md`):
the chosen time-zero definition (one instant, both arms), confirmation that eligibility/assignment/
follow-up coincide, any classic error found + its fix, and the single-vs-sequential decision (with
cadence). Flag for `tte-estimate` whether sequential emulation (`seq_emulate`, M3) is required.
