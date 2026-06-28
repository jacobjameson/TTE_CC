# Target trial protocol — <short study title>

_Causal question:_ <one sentence: effect of [strategies] on [outcome] over [horizon] in [population]>

| Protocol element | Specify (the target trial) | Emulate (with the data) |
|---|---|---|
| **Eligibility criteria** | <criteria, assessed at baseline; washout> | <data mapping: which variables / codes> |
| **Treatment strategies** | <strategy 0; strategy 1 — start + continuation/stop rules> | <how strategies are identified in data> |
| **Assignment** | Randomized at baseline | Emulated via adjustment for: <baseline confounders> |
| **Outcome(s)** | <outcome; type: time-to-event / continuous / binary; ascertainment> | <variable(s); ascertainment in data> |
| **Follow-up** | Starts at <time zero>; ends at <event / death / LTFU / admin end> | Same |
| **Causal contrast** | <ITT and/or per-protocol> | Observational analog: <…> |
| **Identifying assumptions** | <exchangeability given confounders; positivity; consistency> | Same |
| **Analysis plan** | <estimator: pooled-logistic risk / linear / logistic; adjustment method> | Same |

## Design decisions & accepted compromises
- <e.g. usual-care comparator instead of placebo (pragmatism); sequential trials for precision; …>

## Data gaps / confounders to measure
- <unmapped protocol items; confounders that are unmeasured or poorly measured>

## Top validity threats
1. <…>
2. <…>
3. <…>

_Next:_ `time-zero` → `emulate-randomization` → `tte-estimate`.
