###############################################################################
## Example 02 -- Estimating effects in an EMULATED target trial via matching
## (mirrors Hands-on Session 2)
##
## Goal: estimate the effect of VACX vs. no vaccine on the 24-week risk of
## hospitalization using the *observational* dataset, where treatment is
## confounded. We emulate randomization by 1:1 exact/coarsened matching on
## baseline confounders, check covariate balance, then estimate risks on the
## matched cohort (marginally). Bootstrap RE-RUNS matching in every resample.
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R"))
source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_obs.rda"))      # vac_toy_obs
truth <- readRDS(file.path(root, "data", "toy_truth.rds"))
K <- 24L
conf <- c("age_cat", "sex", "race", "urban", "baseline_risk")

## --- 0. the naive (confounded) analysis, for contrast -----------------------
naive <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = K)
cat(sprintf("NAIVE (confounded) 24-wk RD=%.3f  RR=%.2f\n", naive$rd, naive$rr))

## --- 1. match to emulate randomization --------------------------------------
matched <- match_cohort(vac_toy_obs, treat = "treat", covariates = conf)

## --- 2. check covariate balance (cobalt): table + love plot -----------------
if (requireNamespace("cobalt", quietly = TRUE)) {
  print(cobalt::bal.tab(attr(matched, "match"), un = TRUE))
  lp <- cobalt::love.plot(attr(matched, "match"), stats = "mean.diffs", abs = TRUE,
                          thresholds = c(m = .1), var.order = "unadjusted",
                          drop.distance = TRUE,
                          sample.names = c("Before matching", "After matching"),
                          colors = c("#E7B800", "#2E9FDF"),
                          title = "Covariate balance: before vs. after matching")
  ggplot2::ggsave(file.path(root, "examples", "02_loveplot.png"), lp, width = 7.5, height = 5, dpi = 150)
}

## --- 3. estimate risks on the matched cohort (marginal) ---------------------
est <- pooled_logistic_risk(matched, treat = "treat", K = K)
cat(sprintf("MATCHED 24-wk risk: vaccine=%.3f none=%.3f RD=%.3f RR=%.2f  (truth RD=%.3f)\n",
            est$risk1, est$risk0, est$rd, est$rr, truth$obs$rd))

## --- 4. bootstrap: RE-RUN matching inside each resample ---------------------
stat <- function(dd) {
  m <- match_cohort(dd, treat = "treat", covariates = conf)
  r <- pooled_logistic_risk(m, treat = "treat", K = K)
  c(rd = r$rd, rr = r$rr)
}
ci <- boot_tte(vac_toy_obs, stat, R = 200L, seed = 4237)
print(ci, digits = 3)

## --- 5. figure --------------------------------------------------------------
p <- tte_riskplot(est, labels = c("No vaccine", "VACX vaccine"))
ggplot2::ggsave(file.path(root, "examples", "02_matched_risk_curves.png"),
                p, width = 7, height = 5, dpi = 150)
cat("Saved figure: examples/02_matched_risk_curves.png\n")
