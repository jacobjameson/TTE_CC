###############################################################################
## Example 07 -- Cloning to compare sustained strategies indistinguishable at t0
## (mirrors Hands-on Session 7)
##
## Everyone gets a first dose at baseline. The strategies differ only in WHEN the
## second dose is taken (exactly week 3 vs exactly week 5) -- so they are
## indistinguishable at time zero. We CLONE each person into both arms, CENSOR a
## clone when its data deviate, and IP-WEIGHT to undo the censoring selection.
## We compare to a NAIVE per-protocol analysis (observed adherers only) and to the
## known Monte-Carlo per-protocol truth.
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R")); source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_tv.rda")); truth <- readRDS(file.path(root, "data", "toy_truth.rds"))
Ktv <- truth$tv$K
conf <- c("symp", "symp_lag1", "age", "baseline_risk")   # time-varying + baseline confounders

## --- NAIVE per-protocol: observed exactly-wk3 vs exactly-wk5 takers ----------
sdw <- tapply(seq_len(nrow(vac_toy_tv)), vac_toy_tv$id, function(ix) {
  tt <- vac_toy_tv$time[ix]; aa <- vac_toy_tv$treat[ix]
  w <- tt[tt >= 1 & aa == 1]; if (length(w)) min(w) else NA_integer_ })
vac_toy_tv$sdw <- sdw[as.character(vac_toy_tv$id)]
sub <- vac_toy_tv[!is.na(vac_toy_tv$sdw) & vac_toy_tv$sdw %in% c(3, 5), ]
sub$armn <- as.integer(sub$sdw == 5)
naive <- pooled_logistic_risk(sub, treat = "armn", time = "time", K = Ktv)
cat(sprintf("NAIVE per-protocol (adherers only)   RD=%.3f   <- confounded\n", naive$rd))

## --- CLONING + censoring + IP weighting -------------------------------------
both <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 3), arm1 = c(5, 5), K = Ktv)
est  <- pooled_logistic_risk(both[!is.na(both$hosp), ], treat = "arm", time = "time",
                             K = Ktv, weights = "w")
cat(sprintf("CLONING (2nd dose wk3 vs wk5)         RD=%.3f  risk(wk3)=%.3f risk(wk5)=%.3f\n",
            est$rd, est$risk0, est$risk1))
cat(sprintf("TRUTH (Monte-Carlo per-protocol)     RD=%.3f  risk(wk3)=%.3f risk(wk5)=%.3f\n",
            truth$tv$rd, truth$tv$risk_w3, truth$tv$risk_w5))

cat("\nNaive per-protocol is badly confounded (people who delay the 2nd dose are\n",
    "systematically different); cloning+IP-weighting corrects the direction and\n",
    "recovers the later-dose arm. Residual gap reflects the parametric hazard\n",
    "approximation and positivity for exact-timing adherers.\n", sep = "")

p <- tte_riskplot(est, labels = c("2nd dose at week 3", "2nd dose at week 5"))
ggplot2::ggsave(file.path(root, "examples", "07_cloning_risk_curves.png"), p, width = 7, height = 5, dpi = 150)
cat("Saved figure: examples/07_cloning_risk_curves.png\n")
