# Fidelity map — helper functions → course sessions

Each TTE_CC helper is distilled from a specific hands-on session's R recipe. This file documents the
correspondence so the implementation can be audited against the course. (No course code is copied;
these are independent reimplementations of the same statistical procedure.)

| Helper (`R/tte-helpers.R`) | Course source | What it reproduces |
|---|---|---|
| `pooled_logistic_risk()` (marginal) | Session 1, 2 | Pooled logistic `hosp ~ A + time + time² + A:time + A:time²`; hazards → `cumprod(1−h)` → risk → RD/RR at K. |
| `pooled_logistic_risk(covariates=)` | Session 4 | **Standardization / g-formula**: predict each baseline person under A=0/1 across follow-up, average survival, 1 − mean(S). |
| `pooled_logistic_risk(weights=)` | Sessions 4–6 | IP-weighted pooled logistic (weights = stabilized IPTW × IPCW, truncated). |
| `km_risk()` | Session 1, 2 | `survfit(Surv(time, time+1, hosp) ~ A, conf.type="log-log")`; cumulative incidence = 1 − survival; risks at K. |
| `boot_tte()` | Sessions 1–5 | Percentile bootstrap by **resampling persons (ids)**; the full pipeline is re-run inside `statistic`. |
| `point_effect()` | Session 1 (+ generalization) | Single non-time-to-event outcome: continuous → mean difference; binary → risk diff/ratio. Marginal, standardization (`covariates=`), or IPW (`weights=`) via g-computation. |
| `match_cohort()` | Session 2 | 1:1 exact/coarsened matching (`MatchIt`) on baseline rows; returns long data for matched ids (+ MatchIt object). Estimate marginally afterward; bootstrap re-runs matching. |
| `mean_diff()` | Session 1 | Continuous secondary outcome (titer) mean difference + 95% CI at end of follow-up (thin convenience wrapper). |
| `tte_riskplot()` | Sessions 1–8 figures | House-style cumulative-incidence curves (palette `#E7B800` / `#2E9FDF`). |

## Planned for v2 (Sessions 3–8 machinery)
| Helper (planned) | Source | Reproduces |
|---|---|---|
| `seq_emulate()` | Session 3–4 | `seq.em` stacking: per-trial baseline, re-based `time`, `id_new`, `period`; ID-clustered bootstrap. |
| `ip_weights()` | Sessions 4–7 | Nonstabilized/stabilized IPTW + IPCW; cumulative products; truncation. |
| `clone_censor_weight()` | Sessions 7–8 | Cloning into strategies, deviation censoring, IP-of-censoring weights, grace periods (natural vs uniform). |
| `competing_events_transform()` | Session 5 | Total-effect / composite / controlled-direct-effect data transforms. |

## Key constants the course uses
- Horizon `K = 24` weeks; risks reported at interval `K-1` (end = week 24).
- Bootstrap `R = 2` in class "for illustration" — use ≥ 500–1000 in practice.
- Weight truncation at the 99th percentile (also explores 95th / 99.9th).
