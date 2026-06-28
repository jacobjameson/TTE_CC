---
name: tte-report
description: >
  Use to draft the write-up of a target trial emulation — the protocol table, a CONSORT-style
  participant-flow diagram, methods, and results — with disciplined causal language (causal terms in
  Title/Intro/Methods/Discussion, never in Results). Produces a manuscript/methods skeleton.
---

# Report the target trial emulation

You scaffold a faithful, honest write-up. The framing discipline (from Lecture 4 / Lecture 10 in
`reference/course-map.md`): state the causal goal explicitly — *"what is the target trial?"* — and keep
**causal language out of the Results section**. (Toolkit files at repo root or `~/.tte_cc/`.)

## Assemble from prior artifacts
Pull from `target_trial_protocol.md`, the `time-zero`/`emulate-randomization`/`competing-events`
decisions, the `tte-estimate` output (estimates + CIs + figure), and `emulation_checks.md`.

## Sections to produce
1. **Title / Abstract** — name the causal contrast (effect of *assignment to / adhering to* strategy 1
   vs 0). Causal language OK.
2. **Introduction** — the causal question and why it matters. Causal language OK.
3. **Methods** —
   - The **target trial protocol** table (Specify | Emulate), all 8 elements.
   - **Time zero** definition and how eligibility/assignment/follow-up were aligned; single vs
     sequential emulation.
   - **Emulating randomization**: confounders adjusted for; method (matching / standardization / IPW);
     positivity handling.
   - **Outcome & estimand**: outcome type; for competing events, the chosen estimand and its assumption.
   - **Statistical analysis**: the pooled-logistic risk / linear / logistic estimator; bootstrap CIs.
   Causal language OK.
4. **Results** — participant flow (a **CONSORT-style** diagram/table: eligible → assigned per arm →
   excluded → analyzed → events / deaths / losses to follow-up **by arm**), baseline characteristics,
   balance, and the effect estimates with 95% CIs. **No causal language here** — report associations/
   estimates as numbers, no interpretation.
5. **Discussion** — causal interpretation, arguments for and against it, residual-confounding and other
   limitations (cite the `check-emulation` findings), comparison to any benchmark trial. Causal
   language OK.

## Rules to enforce
- Causal terms ("effect", "reduces", "causes") belong everywhere **except Results**.
- Always report **losses to follow-up by arm** and how they were handled.
- Report the estimand precisely (ITT vs per-protocol; competing-events estimand).
- State the no-unmeasured-confounding assumption and that checks falsify but cannot verify it.

## Output
Write **`tte_report.md`** (or `.qmd`/`.Rmd` if the user wants executable) with the sections above
filled from the artifacts, a placeholder CONSORT flow the user can complete, and a results table
stub wired to the `tte-estimate` numbers.
