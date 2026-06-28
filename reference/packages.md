# R environment

- **R ≥ 4.0** (developed on 4.5; the course supports ≥ 3.4).

## Used by v1 (the spine)
| Package | Used for |
|---|---|
| `survival` | Kaplan–Meier (`survfit`, `Surv`) |
| `MatchIt` | exact / coarsened-exact matching (Sessions 2–3) |
| `cobalt` | covariate-balance diagnostics (`love.plot`) |
| `boot` | bootstrap utilities (the engine also ships its own `boot_tte`) |
| `ggplot2` | risk-curve figures |
| `data.table` | fast person-time manipulation, sequential-trial stacking |
| `testthat` | test suite |

## Also used across the full course (v2 / optional)
`splitstackshape` (`expandRows`), `speedglm` (fast pooled-logistic on large stacked data),
`Hmisc` (`rcspline.eval`), `tableone`, `survminer`, `dplyr`.

## Optional interop (NOT a dependency)
`TrialEmulation`, `SEQTaRget` — third-party CRAN packages implementing sequential trial emulation and
clone-censor-weight. They are **not** required and are not on the canonical path; they may be used as
an independent cross-check (see `tests/`).

## Install
```r
install.packages(c("survival","MatchIt","cobalt","boot","ggplot2","data.table","testthat"))
# full course set:
install.packages(c("splitstackshape","speedglm","Hmisc","tableone","survminer","dplyr"))
```
