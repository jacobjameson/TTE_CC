# TTE_CC — Target Trial Emulation skills for Claude Code

**Make causal inference less casual.** TTE_CC is a set of [Claude Code](https://claude.com/claude-code)
skills — plus a small, vetted R helper library — for **target trial emulation (TTE)**: estimating the
causal effect of a treatment from observational data by first asking a well-defined causal question
(the protocol of a hypothetical randomized trial) and then emulating that trial with transparent
estimators.

The skills are deliberately **opinionated and interactive**. They interview you, and they push
back — on prevalent-user comparisons, non-pragmatic trials, ill-defined treatment strategies, and
misaligned time zero — because *a good answer starts with a good question.*

> [!NOTE]
> TTE_CC implements the published target-trial-emulation framework (Hernán & Robins and colleagues)
> and is built to be faithful to how it is taught by the Harvard CAUSALab. It is an independent
> project — not affiliated with or endorsed by Harvard or CAUSALab — and ships **no** third-party
> course materials or data; the included teaching dataset is entirely synthetic and original to this
> repository. See [Acknowledgements](#acknowledgements).

---

## The two-step philosophy

| Step | Question | What the skills do |
|------|----------|--------------------|
| **1. Ask** | What is the causal question? | Specify the **8-element target-trial protocol** (eligibility, treatment strategies, assignment, outcomes, follow-up, causal contrasts, identifying assumptions, analysis plan). |
| **2. Answer** | What is the effect? | Emulate the trial with observational data + appropriate causal-inference analytics, then *check* the emulation and *report* it honestly. |

> *"If we cannot translate our causal question into a target trial, then the question is not well-defined."*

---

## Skills

> **End-to-end coverage**: specifying & emulating target trials; matching / standardization / IP
> weighting; sequential (nested) trials; competing events & loss to follow-up; and sustained
> strategies via cloning–censoring–weighting with grace periods.

| Track | Skill | What it does |
|-------|-------|--------------|
| **A · Specify** | `target-trial` ⭐ | Interviews you through the 8 protocol elements; refuses sloppy specs. |
| | `time-zero` | Aligns eligibility = assignment = start of follow-up; catches immortal-time designs; single vs. sequential trials. |
| | `competing-events` | Forces an explicit estimand when death/competing events occur; flags the controlled-direct-effect trap. |
| **B · Emulate** | `emulate-randomization` | Elicits the confounder set; picks the adjustment method. |
| | `sustained-strategies` | Point vs sustained, static/dynamic, treatment-confounder feedback → g-methods, indistinguishable-at-t0 → cloning, grace periods. |
| **C · Analyze** | `tte-estimate` | Generates readable, transparent R — modes: `rct`, `matching`, `standardize`, `ipw` (+ IPCW), `sequential`, competing-events, `cloning` (+ grace). |
| **D · Check / Report** | `check-emulation` | Negative controls, balance, positivity — *"cannot verify, only falsify."* |
| | `tte-report` | Write-up scaffold; keeps causal language out of the Results section. |

*(Skill definitions live under `.claude/skills/`; they call the R engine in `R/` and the reference
library in `reference/`.)*

---

## The R engine (`R/`)

The "doing" track is built from primitives so the statistics stay legible — the canonical recipe is
**pooled logistic discrete-time hazard → survival via `cumprod(1 - h)` → risk → risk difference /
ratio**, with inference by **resampling persons (IDs)** for percentile bootstrap CIs.

```r
source("R/tte-helpers.R"); source("R/tte-plot.R")
load("data/vac_toy_random.rda")

# parametric pooled-logistic risk curves + 24-week RD/RR
fit <- pooled_logistic_risk(vac_toy_random, treat = "random", K = 24)
fit$rd; fit$rr

# nonparametric cross-check
km_risk(vac_toy_random, treat = "random", K = 24)

# standardization (g-formula) over baseline confounders, in observational data
load("data/vac_toy_obs.rda")
pooled_logistic_risk(vac_toy_obs, treat = "treat", K = 24,
                     covariates = c("age","baseline_risk","pcp_visits","flu_vac"))

# bootstrap (re-runs the whole pipeline per resample)
boot_tte(vac_toy_random,
         function(d) { r <- pooled_logistic_risk(d, "random", K = 24); c(rd = r$rd, rr = r$rr) },
         R = 500, seed = 4237)
```

Key functions: `pooled_logistic_risk()`, `km_risk()`, `point_effect()`, `match_cohort()`,
`seq_emulate()`, `ip_weights()`, `competing_events_transform()`, `clone_censor_weight()`,
`boot_tte()`, `tte_riskplot()`. Each helper's method and provenance is documented in
[`reference/fidelity.md`](reference/fidelity.md).

---

## Synthetic teaching data (`data/`)

TTE_CC ships its **own** fully-synthetic teaching data so every example runs out of the box — a
randomized trial (`vac_toy_random`), a confounded observational study (`vac_toy_obs`), and a
time-varying-dose cohort (`vac_toy_tv`) for sustained-strategy / cloning analyses — in
long/person-time weekly format, built from a **known data-generating mechanism**. Because the truth
is known (including a Monte-Carlo per-protocol truth for the dose-timing strategies), examples and
tests verify that the estimators recover it (and that a naïve analysis is visibly biased). The data
are invented for this repository and describe a fictional vaccine; they are not derived from any
real or external dataset.

```r
Rscript data/make_toy_data.R   # regenerate (seeded); writes csv + rda + toy_truth.rds
```

---

## Install the skills (Claude Code)

One line in your terminal — downloads the toolkit to `~/.tte_cc` and links the skills so Claude Code
can find them:

```bash
curl -fsSL https://raw.githubusercontent.com/jacobjameson/TTE_CC/main/install.sh | bash
```

Then in Claude Code: `/target-trial` (or `/time-zero`, `/emulate-randomization`, `/tte-estimate`).

Install into **the current project only** (instead of globally):

```bash
curl -fsSL https://raw.githubusercontent.com/jacobjameson/TTE_CC/main/install.sh | \
  TTE_CC_SKILLS_DEST="$PWD/.claude/skills" bash
```

Prefer to do it by hand? `git clone https://github.com/jacobjameson/TTE_CC ~/.tte_cc` and link
`~/.tte_cc/.claude/skills/*` into your `.claude/skills/`. The skills read the toolkit's `reference/`
and `R/` files from the install location (`$TTE_CC_HOME`, default `~/.tte_cc`).

## Run the R engine / examples

```bash
# R dependencies: survival, MatchIt, cobalt, boot, ggplot2, data.table (+ testthat to test)
Rscript -e 'install.packages(c("survival","MatchIt","cobalt","boot","ggplot2","data.table","testthat"))'

Rscript data/make_toy_data.R                 # build the toy datasets
Rscript examples/01_rct_effects.R            # randomized trial: KM + pooled logistic
Rscript examples/02_emulated_matching.R      # emulated trial: matching
Rscript examples/03_sequential.R             # sequential (nested) trials
Rscript examples/04_ipweighting.R            # IP weighting (treatment + censoring)
Rscript examples/05_competing_events.R       # competing-event estimands
Rscript examples/07_cloning.R                # cloning for sustained strategies
Rscript examples/08_grace_periods.R          # grace periods (cloning with a window)
Rscript -e 'testthat::test_dir("tests/testthat")'   # validate the engine (50 tests)
```

---

## Repository layout

```
.claude/skills/   the Claude Code skills (Specify · Emulate · Analyze · Check/Report)
R/                transparent estimation helpers + house plotting style
reference/        methodology notes: glossary, variable conventions, method map
data/             synthetic teaching datasets + reproducible generator + known truth
examples/         end-to-end worked analyses
tests/            recover-the-truth + internal-consistency tests
```

---

## Validation

- **Recover-the-truth**: on the toy data the engine recovers the known data-generating effect
  (true RD ≈ −0.17), and standardization recovers the truth where the naïve estimate is biased.
- **Internal consistency**: Kaplan–Meier agrees with the pooled-logistic engine.
- **Optional cross-check**: where third-party packages (e.g. `TrialEmulation`) cover the same
  estimand, they can be run as an independent sanity check — they are *not* a dependency.

---

## Acknowledgements

The methodology implemented here is the target-trial-emulation framework from *Causal Inference: What
If* (Hernán & Robins, 2020) and the broader literature. The toolkit is built to be faithful to how
target trial emulation is taught by the Harvard CAUSALab; it is an independent reimplementation for
educational and research use, **not affiliated with or endorsed by** Harvard or CAUSALab. All errors
are the author's. To cite this toolkit, see [`CITATION.cff`](CITATION.cff).

## License

[MIT](LICENSE) © 2026 Jacob Jameson
