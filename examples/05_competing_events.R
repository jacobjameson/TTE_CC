###############################################################################
## Example 05 -- Competing events (death) and the choice of estimand
## (mirrors Hands-on Session 5 / Lecture 7)
##
## With death as a competing event for hospitalization, there is no single causal
## question. We estimate three estimands on the same data and show they differ
## *because the questions differ* -- using IPTW for confounding throughout.
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R")); source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_obs.rda"))
K <- 24L
conf <- c("age", "baseline_risk", "pcp_visits", "flu_vac")

# IP-weighted (treatment) data, restricted to uncensored person-time
w <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = K)
w <- w[w$censor == 0, ]

estimand_rd <- function(transform) {
  d <- competing_events_transform(w, estimand = transform, K = K)
  r <- pooled_logistic_risk(d, treat = "treat", K = K, weights = "w")
  c(risk0 = r$risk0, risk1 = r$risk1, rd = r$rd, rr = r$rr)
}

cat("Effect of VACX on hospitalization, three competing-event estimands (IPTW):\n\n")
for (e in c("total", "composite", "controlled")) {
  v <- estimand_rd(e)
  cat(sprintf("  %-11s  risk1=%.3f  risk0=%.3f  RD=%.3f  RR=%.2f\n",
              e, v["risk1"], v["risk0"], v["rd"], v["rr"]))
}
cat("\nThese differ because they answer different questions:\n",
    "- total: effect on hospitalization, deaths kept as eternally outcome-free\n",
    "- composite: effect on (hospitalization OR death)\n",
    "- controlled: 'had no one died' -- ill-defined; assumes no unmeasured common\n",
    "  causes of death and hospitalization (report with that caveat).\n", sep = "")
