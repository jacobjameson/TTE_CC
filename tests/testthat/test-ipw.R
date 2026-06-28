## IP weighting emulates randomization (treatment) and corrects informative LTFU (censoring).

conf <- c("age", "baseline_risk", "pcp_visits", "flu_vac")

test_that("IPTW recovers the truth on confounded observational data", {
  naive <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = truth$K)
  w  <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = truth$K)
  est <- pooled_logistic_risk(w, treat = "treat", K = truth$K, weights = "w")
  expect_lt(abs(est$rd - truth$obs$rd), abs(naive$rd - truth$obs$rd))
  expect_equal(est$rd, truth$obs$rd, tolerance = 0.04)
})

test_that("stabilized weights are well-behaved (mean ~ 1)", {
  w <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = truth$K,
                  truncate = NULL)
  expect_equal(mean(w$sw_a), 1, tolerance = 0.1)
  expect_true(all(w$sw_a > 0))
})

test_that("adding censoring weights produces finite combined weights", {
  w <- ip_weights(vac_toy_obs, treat = "treat", covariates = conf, K = truth$K,
                  censor = "censor")
  expect_true(all(is.finite(w$w)))
  expect_true("sw_c" %in% names(w))
  est <- pooled_logistic_risk(w[w$censor == 0 & w$death == 0, ],
                              treat = "treat", K = truth$K, weights = "w")
  expect_true(is.finite(est$rd))
})
