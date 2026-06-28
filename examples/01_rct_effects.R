###############################################################################
## Example 01 -- Estimating effects in a randomized trial
## (mirrors Hands-on Session 1)
##
## Goal: estimate the intention-to-treat effect of VACX vs. no vaccine on the
## 24-week risk of hospitalization, using the synthetic randomized dataset.
## We use both the nonparametric Kaplan-Meier estimator and the parametric
## pooled-logistic engine, then bootstrap for confidence intervals.
###############################################################################

## --- setup ----------------------------------------------------------------
## Run from the repo root:  Rscript examples/01_rct_effects.R
root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R"))
source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_random.rda"))   # vac_toy_random
K <- 24L

## --- 1. nonparametric: Kaplan-Meier ---------------------------------------
km <- km_risk(vac_toy_random, treat = "random", K = K)
cat(sprintf("KM   24-wk risk:  vaccine=%.3f  none=%.3f  RD=%.3f  RR=%.2f\n",
            km$risk1, km$risk0, km$rd, km$rr))

## --- 2. parametric: pooled logistic regression ----------------------------
pl <- pooled_logistic_risk(vac_toy_random, treat = "random", K = K)
cat(sprintf("PLR  24-wk risk:  vaccine=%.3f  none=%.3f  RD=%.3f  RR=%.2f\n",
            pl$risk1, pl$risk0, pl$rd, pl$rr))

## --- 3. continuous secondary outcome: antibody titer at 24 weeks ----------
md <- mean_diff(vac_toy_random, treat = "random", outcome = "titer", K = K)
cat(sprintf("Titer mean difference (vaccine - none): %.1f  (95%% CI %.1f, %.1f)\n",
            md["md"], md["lower.2.5 %"], md["upper.97.5 %"]))

## --- 4. bootstrap 95% CIs for the parametric risk difference / ratio -------
##     (R = 200 here; use >= 500-1000 for real analyses)
stat <- function(dd) {
  r <- pooled_logistic_risk(dd, treat = "random", K = K)
  c(risk0 = r$risk0, risk1 = r$risk1, rd = r$rd, rr = r$rr)
}
ci <- boot_tte(vac_toy_random, stat, R = 200L, seed = 4237)
print(ci, digits = 3)

## --- 5. publication-style cumulative-incidence figure ---------------------
p <- tte_riskplot(pl, labels = c("No vaccine", "VACX vaccine"))
ggplot2::ggsave(file.path(root, "examples", "01_rct_risk_curves.png"),
                p, width = 7, height = 5, dpi = 150)
cat("Saved figure: examples/01_rct_risk_curves.png\n")
