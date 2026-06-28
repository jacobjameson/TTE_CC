## Cloning-censoring-weighting recovers the per-protocol contrast where a NAIVE
## adherers-only comparison is badly confounded (here, even the wrong sign).

Ktv  <- truth$tv$K
conf <- c("symp", "symp_lag1", "age", "baseline_risk")

# observed second-dose week per person (first dose at time 0)
sdw <- tapply(seq_len(nrow(vac_toy_tv)), vac_toy_tv$id, function(ix) {
  tt <- vac_toy_tv$time[ix]; aa <- vac_toy_tv$treat[ix]
  w <- tt[tt >= 1 & aa == 1]; if (length(w)) min(w) else NA_integer_
})
vac_toy_tv$sdw <- sdw[as.character(vac_toy_tv$id)]

naive_rd <- {
  sub <- vac_toy_tv[!is.na(vac_toy_tv$sdw) & vac_toy_tv$sdw %in% c(3, 5), ]
  sub$armn <- as.integer(sub$sdw == 5)
  pooled_logistic_risk(sub, treat = "armn", time = "time", K = Ktv)$rd
}

clone_rd <- {
  both <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 3), arm1 = c(5, 5), K = Ktv)
  pooled_logistic_risk(both[!is.na(both$hosp), ], treat = "arm", time = "time",
                       K = Ktv, weights = "w")
}

test_that("cloning recovers the correct sign of the per-protocol effect", {
  expect_gt(clone_rd$rd, 0)              # truth: later 2nd dose -> higher risk (RD > 0)
})

test_that("cloning is much closer to truth than the naive per-protocol comparison", {
  expect_lt(abs(clone_rd$rd - truth$tv$rd), abs(naive_rd - truth$tv$rd))
  expect_lt(naive_rd, 0)                 # naive is confounded to the wrong sign here
})

test_that("the recovered wk5-arm risk is close to truth", {
  expect_equal(clone_rd$risk1, truth$tv$risk_w5, tolerance = 0.05)
})

test_that("clone_censor_weight censors deviators and returns finite weights", {
  both <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 3), arm1 = c(5, 5), K = Ktv)
  expect_setequal(unique(both$arm), c(0, 1))
  expect_true(any(is.na(both$hosp)))                 # some person-time censored (deviation)
  expect_true(all(is.finite(both$w)))
})

test_that("grace-period windows run and give a coherent estimate", {
  bg <- clone_censor_weight(vac_toy_tv, covariates = conf, arm0 = c(3, 4), arm1 = c(5, 6), K = Ktv)
  est <- pooled_logistic_risk(bg[!is.na(bg$hosp), ], treat = "arm", time = "time",
                              K = Ktv, weights = "w")
  expect_true(est$risk0 >= 0 && est$risk0 <= 1 && est$risk1 >= 0 && est$risk1 <= 1)
})
