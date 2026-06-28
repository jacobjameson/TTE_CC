## Validation of the core estimation engine against the KNOWN data-generating truth.

test_that("pooled logistic recovers the true RCT effect", {
  res <- pooled_logistic_risk(vac_toy_random, treat = "random", K = truth$K)
  expect_equal(res$rd, truth$rct$rd, tolerance = 0.02)
  expect_equal(res$rr, truth$rct$rr, tolerance = 0.08)
  expect_equal(res$risk1, truth$rct$risk1, tolerance = 0.02)
  expect_equal(res$risk0, truth$rct$risk0, tolerance = 0.02)
})

test_that("Kaplan-Meier agrees with the pooled-logistic engine (RCT)", {
  km <- km_risk(vac_toy_random, treat = "random", K = truth$K)
  pl <- pooled_logistic_risk(vac_toy_random, treat = "random", K = truth$K)
  expect_equal(km$rd, pl$rd, tolerance = 0.01)
  expect_equal(km$risk1, pl$risk1, tolerance = 0.01)
  expect_equal(km$risk0, pl$risk0, tolerance = 0.01)
})

test_that("naive observational analysis is biased but standardization recovers truth", {
  naive <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = truth$K)
  conf  <- c("age", "baseline_risk", "pcp_visits", "flu_vac")
  std   <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = truth$K,
                                covariates = conf)
  # confounding pulls the naive RD toward the null (sicker people get treated)
  expect_gt(naive$rd, truth$obs$rd)                 # naive less protective than truth
  # standardization moves the estimate back toward the truth
  expect_lt(abs(std$rd - truth$obs$rd), abs(naive$rd - truth$obs$rd))
  expect_equal(std$rd, truth$obs$rd, tolerance = 0.03)
})

test_that("boot_tte returns a CI bracketing the point estimate", {
  stat <- function(dd) {
    r <- pooled_logistic_risk(dd, treat = "random", K = truth$K)
    c(rd = r$rd, rr = r$rr)
  }
  ci <- boot_tte(vac_toy_random, stat, R = 25L, seed = 1)
  expect_true(all(ci$lower <= ci$estimate & ci$estimate <= ci$upper))
  expect_true("rd" %in% ci$statistic && "rr" %in% ci$statistic)
})

test_that("risk curves are monotone non-decreasing and within [0,1]", {
  res <- pooled_logistic_risk(vac_toy_random, treat = "random", K = truth$K)
  expect_true(all(diff(res$curve$risk1) >= -1e-9))
  expect_true(all(diff(res$curve$risk0) >= -1e-9))
  expect_true(all(res$curve$risk0 >= 0 & res$curve$risk0 <= 1))
})
