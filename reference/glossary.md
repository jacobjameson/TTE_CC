# Glossary & the rules we are nitpicky about

## Core terms
- **Target trial** — the hypothetical *pragmatic* randomized trial you would run to answer a causal
  question. A causal analysis of observational data is an attempt to emulate some target trial.
- **Time zero** — for each person, the instant when eligibility is met, the strategy is assigned, and
  follow-up starts. These must coincide.
- **Intention-to-treat (ITT) effect** — effect of *assignment* to a strategy, regardless of adherence.
- **Per-protocol effect** — effect of *adhering* to the assigned strategy; needs adjustment for
  post-baseline confounding/selection (g-methods) → "non-naïve" per-protocol analysis.
- **Incident (new) user** vs **prevalent user** — initiators at time zero vs people already on
  treatment. Prevalent-user contrasts are biased and clinically uninformative.
- **Washout** — a pre-baseline period with no treatment, required to define "new use."
- **Design bias** (immortal time, prevalent-user selection) vs **data bias** (confounding, measurement
  error). TTE removes the former, not the latter.
- **Sequential trial emulation** — emulate a new trial at each eligible time and pool; improves
  precision; needs ID-clustered/bootstrap inference.
- **Standardization / g-formula** — model the outcome given treatment+covariates, predict under each
  treatment for everyone, average.
- **IP weighting** — weight by inverse probability of the observed treatment (and of remaining
  uncensored) to create a pseudo-population without confounding/selection. Stabilized weights are
  preferred; truncate extreme weights (bias–variance tradeoff).
- **Cloning–censoring–weighting** — for strategies indistinguishable at time zero: clone each person
  into every compatible strategy, censor a clone when it deviates, IP-weight to undo that censoring.
- **Grace period** — a window during which not-yet-treated data are compatible with a "treat-by-X"
  strategy; clones aren't censored until its end.
- **Competing event** — makes the outcome impossible (e.g. death before the outcome). **Truncation
  event** — makes the outcome undefined.
- **Negative control** (outcome/treatment/population) — a falsification probe: should show no effect;
  if it does, residual bias is present.

## The "push back" checklist (what the Specify skills refuse to let slide)
1. **Prevalent-user / "ever-treated" / "current vs never" contrast** → reframe as initiators vs
   non-initiators at time zero.
2. **Non-pragmatic target trial** → no placebo, no blinding, no unreal strategies, no tight monitoring.
3. **Ill-defined treatment strategy** → must state the start rule and the continuation/discontinuation
   rule (and grace period if relevant).
4. **Misaligned time zero** → eligibility, assignment, and start of follow-up must be the same instant;
   beware the look-back and "different t0 per arm" designs.
5. **Vague estimand** → ITT vs per-protocol must be chosen explicitly.
6. **Unmapped protocol item** → every element needs a measured variable ("no more, no less").
7. **Silent censoring at a competing event** → forces an explicit competing-events estimand.
8. **"We proved causation / it's just an association"** → causal goal stated up front; causal language
   never in the Results section.
