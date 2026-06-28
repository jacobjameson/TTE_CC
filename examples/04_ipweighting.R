###############################################################################
## Example 04 -- IP weighting for time-fixed confounding (+ loss to follow-up)
## (mirrors Hands-on Sessions 4-5)
##
## Emulate randomization with STABILIZED inverse-probability-of-treatment weights,
## and (optionally) correct informative loss to follow-up with inverse-probability-
## of-censoring weights. Then estimate risks with the weighted pooled-logistic
## engine and standardize. Bootstrap re-runs the whole weighting pipeline.
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R")); source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_obs.rda"))
truth <- readRDS(file.path(root, "data", "toy_truth.rds"))
K <- 24L
conf <- c("age", "baseline_risk", "pcp_visits", "flu_vac")

## naive (confounded) baseline
naive <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = K)
cat(sprintf("NAIVE       RD=%.3f  RR=%.2f\n", naive$rd, naive$rr))

## --- IPTW only (treatment weights) -----------------------------------------
w1  <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = K)
est1 <- pooled_logistic_risk(w1[w1$censor == 0 & w1$death == 0, ],
                             treat = "treat", K = K, weights = "w")
cat(sprintf("IPTW        RD=%.3f  RR=%.2f   (truth RD=%.3f)\n", est1$rd, est1$rr, truth$obs$rd))

## --- IPTW + IPCW (also correct informative loss to follow-up) ---------------
w2  <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = K,
                  censor = "censor")
est2 <- pooled_logistic_risk(w2[w2$censor == 0 & w2$death == 0, ],
                             treat = "treat", K = K, weights = "w")
cat(sprintf("IPTW+IPCW   RD=%.3f  RR=%.2f\n", est2$rd, est2$rr))
cat(sprintf("weight summary: mean=%.2f  max=%.1f (truncated at 99th pct)\n",
            mean(w2$w), max(w2$w)))

## --- bootstrap CIs (re-run weighting each resample) -------------------------
stat <- function(dd) {
  w <- ip_weights(dd, treat = "treat", covariates = conf, K = K, censor = "censor")
  r <- pooled_logistic_risk(w[w$censor == 0 & w$death == 0, ],
                            treat = "treat", K = K, weights = "w")
  c(rd = r$rd, rr = r$rr)
}
print(boot_tte(vac_toy_obs, stat, R = 100L, seed = 4237), digits = 3)

p <- tte_riskplot(est2, labels = c("No vaccine", "VACX vaccine"))
ggplot2::ggsave(file.path(root, "examples", "04_ipw_risk_curves.png"), p, width = 7, height = 5, dpi = 150)
cat("Saved figure: examples/04_ipw_risk_curves.png\n")
