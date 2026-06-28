---
name: check-emulation
description: >
  Use after estimating an observational target trial emulation to stress-test whether randomization
  was plausibly emulated — negative control outcomes/treatments/populations, covariate balance,
  positivity / weight diagnostics, and benchmarking against a randomized trial. Falsification, not
  verification.
---

# Check the emulation (falsify, don't verify)

You can never *prove* that confounding adjustment was sufficient — you can only look for evidence that
it was **not** (falsification). This skill runs that battery and reports honestly. Read the Lecture-5
material in `reference/course-map.md` (Checking the emulation). (Toolkit files at repo root or
`~/.tte_cc/`.)

## Run as many of these as the data allow
1. **Negative outcome control** — re-run the analysis with an outcome the treatment *cannot* affect
   but that shares the same confounding (e.g. an outcome before treatment could act, or an unrelated
   outcome with similar confounding structure). A non-null estimate signals residual confounding.
   Generate the same `tte-estimate` pipeline with the outcome swapped.
2. **Negative treatment / exposure control** — a "treatment" known to have no effect but with similar
   confounding (e.g. paternal vs maternal exposure). Non-null ⇒ residual bias.
3. **Negative population control** — a subgroup in which the treatment is known to be inert.
4. **Covariate balance** — after matching/weighting, check standardized mean differences with
   `cobalt::bal.tab()` / `cobalt::love.plot()` (rule of thumb: |SMD| < 0.1). For IP weights, check the
   *weighted* balance.
5. **Positivity / overlap** — examine the distribution of the propensity score (or of the IP weights)
   by arm; flag near-violations (extreme weights, non-overlapping support). Report the weight
   distribution (mean ≈ 1 for stabilized; inspect the max; note truncation).
6. **Benchmarking** — if a randomized trial exists for a related question, compare the emulated
   estimate to it (the emulation should land near the trial).

## Tools
- Balance: `cobalt::bal.tab(attr(matched, "match"), un = TRUE)`; for weights pass the weighted data /
  weights to `cobalt`.
- Weight diagnostics: `summary()` of the `w` column from `ip_weights()`; report mean, max, % truncated.
- Negative controls: reuse `tte-estimate` with the control outcome/treatment; interpret a clearly
  non-null estimate as a red flag.

## Output
Write **`emulation_checks.md`**: a checklist of which checks were run (and which couldn't be, and why),
the balance/positivity results, any negative-control estimates, and a candid bottom line — *what these
checks do and do not rule out*. Remember and state: passing every check does **not** prove no
unmeasured confounding; failing one is strong evidence of a problem.
