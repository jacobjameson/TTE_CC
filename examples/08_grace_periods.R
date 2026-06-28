###############################################################################
## Example 08 -- Grace periods (cloning with a window for the action)
## (mirrors Hands-on Session 8)
##
## Real strategies rarely require an action on an exact day. Here the strategies
## allow a WINDOW for the second dose: "weeks 3-4" vs "weeks 5-6". During its grace
## window a clone is NOT censored for not-yet-acting; it is censored only if it acts
## too early or fails to act by the end of the window. Within-window timing is not
## penalized in the weights ("natural" scheme).
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R")); source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_tv.rda")); truth <- readRDS(file.path(root, "data", "toy_truth.rds"))
Ktv <- truth$tv$K
conf <- c("symp", "symp_lag1", "age", "baseline_risk")

## exact timing (Session 7) for comparison
exact <- {
  b <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 3), arm1 = c(5, 5), K = Ktv)
  pooled_logistic_risk(b[!is.na(b$hosp), ], treat = "arm", time = "time", K = Ktv, weights = "w")
}
## grace windows (Session 8): 2nd dose in weeks 3-4 vs 5-6
grace <- {
  b <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 4), arm1 = c(5, 6), K = Ktv)
  pooled_logistic_risk(b[!is.na(b$hosp), ], treat = "arm", time = "time", K = Ktv, weights = "w")
}

cat(sprintf("EXACT  (wk3 vs wk5)        RD=%.3f  risk0=%.3f risk1=%.3f\n",
            exact$rd, exact$risk0, exact$risk1))
cat(sprintf("GRACE  (wks 3-4 vs 5-6)    RD=%.3f  risk0=%.3f risk1=%.3f\n",
            grace$rd, grace$risk0, grace$risk1))
cat("\nA grace period makes the strategies easier to follow (more adherent clones,\n",
    "censored later), trading a slightly different estimand for far better positivity\n",
    "and precision. The contrast still compares earlier vs later completion of the\n",
    "second dose.\n", sep = "")

p <- tte_riskplot(grace, labels = c("2nd dose weeks 3-4", "2nd dose weeks 5-6"))
ggplot2::ggsave(file.path(root, "examples", "08_grace_risk_curves.png"), p, width = 7, height = 5, dpi = 150)
cat("Saved figure: examples/08_grace_risk_curves.png\n")
