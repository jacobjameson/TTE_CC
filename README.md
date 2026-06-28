# TTE_CC — Target Trial Emulation skills for Claude Code

**Make causal inference less casual.** TTE_CC is a set of [Claude Code](https://claude.com/claude-code)
skills — plus a small, vetted R helper library — that walk a researcher through **target trial
emulation (TTE)** the way it is taught at the Harvard CAUSALab TTE course: first ask a well-defined
causal question by specifying the protocol of a target trial, then emulate that trial with
observational data using transparent, course-faithful estimators.

The skills are deliberately **opinionated and interactive**. They interview you, and they push
back — on prevalent-user comparisons, non-pragmatic trials, ill-defined treatment strategies, and
misaligned time zero — because in this framework *a good answer starts with a good question.*

> [!IMPORTANT]
> **Independent project — not affiliated with or endorsed by Harvard, the Harvard T.H. Chan School
> of Public Health, or CAUSALab.** TTE_CC operationalizes the *publicly published*
> target-trial-emulation methodology (Hernán & Robins and colleagues). It contains **no course
> materials, slides, or datasets** from the CAUSALab course. The teaching dataset shipped here is
> entirely synthetic and original to this repository. See [Acknowledgements](#acknowledgements).

---

## The two-step philosophy

| Step | Question | What the skills do |
|------|----------|--------------------|
| **1. Ask** | What is the causal question? | Specify the **8-element target-trial protocol** (eligibility, treatment strategies, assignment, outcomes, follow-up, causal contrasts, identifying assumptions, analysis plan). |
| **2. Answer** | What is the effect? | Emulate the trial with observational data + appropriate causal-inference analytics, then *check* the emulation and *report* it honestly. |

> *"If we cannot translate our causal question into a target trial, then the question is not well-defined."*

---

## Skills

> **v1 (this release) covers the spine: course Sessions 1–5.** Cloning, grace periods, and the
> `sustained-strategies` skill (Sessions 6–8) are planned for v2.

| Track | Skill | What it does |
|-------|-------|--------------|
| **A · Specify** | `target-trial` ⭐ | Interviews you through the 8 protocol elements; refuses sloppy specs. |
| | `time-zero` | Aligns eligibility = assignment = start of follow-up; catches immortal-time designs; single vs. sequential trials. |
| | `competing-events` | Forces an explicit estimand when death/competing events occur; flags the controlled-direct-effect trap. |
| **B · Emulate** | `emulate-randomization` | Elicits the confounder set; picks the adjustment method. |
| **C · Analyze** | `tte-estimate` | Generates readable, course-faithful R (modes: `rct`, `matching`, `sequential-emulation`, `ip-weighting`). |
| **D · Check / Report** | `check-emulation` | Negative controls, balance, positivity — *"cannot verify, only falsify."* |
| | `tte-report` | Write-up scaffold; keeps causal language out of the Results section. |

*(Skill definitions live under `.claude/skills/`. v1 ships the R engine + reference library + the
specification skills first; analyze/check/report skills are wired to the helpers below.)*

---

## The R engine (`R/`)

The "doing" track is built from primitives, mirroring the course's pedagogy — the canonical recipe is
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

Key functions: `pooled_logistic_risk()`, `km_risk()`, `boot_tte()`, `mean_diff()`, `tte_riskplot()`.
Every helper is mapped back to the exact hands-on session it derives from in
[`reference/fidelity.md`](reference/fidelity.md).

---

## Synthetic teaching data (`data/`)

Because the course's datasets cannot be redistributed, TTE_CC ships its **own** fully-synthetic,
VAC-like teaching data — a randomized trial (`vac_toy_random`) and a confounded observational study
(`vac_toy_obs`) — in long/person-time weekly format over a 24-week horizon, built from a **known
data-generating mechanism**. Because the truth is known, examples and tests verify that the
estimators recover it (and that a naïve observational analysis is visibly biased).

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
# R deps used by v1: survival, MatchIt, cobalt, boot, ggplot2, data.table (+ testthat to test)
Rscript -e 'install.packages(c("survival","MatchIt","cobalt","boot","ggplot2","data.table","testthat"))'

Rscript data/make_toy_data.R                 # build the toy datasets
Rscript examples/01_rct_effects.R            # worked example (Session 1, RCT)
Rscript examples/02_emulated_matching.R      # worked example (Session 2, matching)
Rscript -e 'testthat::test_dir("tests/testthat")'   # validate the engine
```

---

## Repository layout

```
.claude/skills/   the Claude Code skills (Specify · Emulate · Analyze · Check/Report)
R/                course-faithful estimation helpers + house plotting style
reference/        the methodology bible: course map, glossary, variable conventions, fidelity map
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

The methodology operationalized here was developed and taught by the **Harvard CAUSALab Target Trial
Emulation course** (instructors **Barbra A. Dickerman, Joy Shi, and Miguel A. Hernán**) and is
grounded in *Causal Inference: What If* (Hernán & Robins, 2020) and the target-trial-emulation
literature. This toolkit is an independent reimplementation for educational and research use and is
**not affiliated with or endorsed by** the course or its instructors. All errors are the author's.

If you build on the course materials directly, please credit the course; to cite this toolkit see
[`CITATION.cff`](CITATION.cff).

## License

[MIT](LICENSE) © 2026 Jacob Jameson
