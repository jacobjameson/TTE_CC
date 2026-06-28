###############################################################################
## Example 03 -- Emulating a sequence of nested target trials
## (mirrors Hands-on Session 3)
##
## When people are eligible at multiple times, we emulate a new trial at each
## eligible time and pool them. A person can contribute to several trials (and to
## different arms), so inference must resample at the PERSON level. This example
## demonstrates the stacking mechanics with seq_emulate() on a small staggered
## cohort, then estimates the pooled effect.
###############################################################################

root <- if (dir.exists("R")) "." else ".."
source(file.path(root, "R", "tte-helpers.R"))
set.seed(20260628)

## --- build a small staggered cohort -----------------------------------------
## Each person becomes eligible at a random calendar week and remains eligible
## (and a potential "new user") for a few weeks; treatment at a trial's baseline
## is confounded by a covariate L; the outcome hazard depends on treatment + L.
N <- 1500L; E <- 5L; K <- 8L
L  <- rbinom(N, 1, 0.5)                       # a baseline confounder
e0 <- sample(0:(E - 1), N, replace = TRUE)    # eligibility-onset calendar week
rows <- list()
for (i in 1:N) {
  elig_weeks <- e0[i]:(E - 1)                 # eligible from onset to end of accrual
  # treated at baseline of the trial they enter (first eligible week), confounded by L
  treat_b <- rbinom(1, 1, plogis(-0.3 + 1.0 * L[i]))
  h <- plogis(-2.2 - 0.9 * treat_b + 0.8 * L[i])   # weekly hospitalization hazard
  evt <- NA_integer_
  for (k in 0:(K - 1)) if (is.na(evt) && rbinom(1, 1, h) == 1) evt <- k
  last <- min(c(evt, K - 1), na.rm = TRUE)
  cal <- e0[i] + (0:last)
  rows[[i]] <- data.frame(
    id = i, cal_time = cal, L = L[i], treat_b = treat_b,
    elig = as.integer(cal %in% elig_weeks),
    hosp = as.integer(!is.na(evt) & (e0[i] + 0:last) == (e0[i] + evt)))
}
cohort <- do.call(rbind, rows)

## --- stack the sequential trials --------------------------------------------
stacked <- seq_emulate(cohort, elig = "elig", time = "cal_time", id = "id", K = K)
cat(sprintf("Cohort: %d people -> %d trials, %d person-trials (avg %.2f trials/person)\n",
            length(unique(cohort$id)), length(unique(stacked$trial)),
            length(unique(stacked$id_new)),
            length(unique(stacked$id_new)) / length(unique(cohort$id))))

## --- estimate the pooled effect on the stacked data -------------------------
## follow-up time within a trial is `fu`; standardize over baseline period (`period`).
est <- pooled_logistic_risk(stacked, treat = "treat_b", time = "fu", K = K,
                            covariates = c("L", "period"))
cat(sprintf("Pooled (standardized) %d-wk RD=%.3f  RR=%.2f\n", K, est$rd, est$rr))

## --- inference: bootstrap at the PERSON level (ids may recur across trials) --
stat <- function(dd) {
  s <- seq_emulate(dd, elig = "elig", time = "cal_time", id = "id", K = K)
  r <- pooled_logistic_risk(s, treat = "treat_b", time = "fu", K = K,
                            covariates = c("L", "period"))
  c(rd = r$rd, rr = r$rr)
}
print(boot_tte(cohort, stat, R = 100L, id = "id", seed = 4237), digits = 3)
cat("\nNote: sequential emulation improves PRECISION (more person-trials); the\n",
    "bootstrap resamples persons, not person-trials, to respect within-person correlation.\n", sep="")
