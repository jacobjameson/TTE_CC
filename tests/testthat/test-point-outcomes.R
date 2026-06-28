## Validation that the toolkit handles NON-time-to-event outcomes too.

test_that("continuous outcome: mean difference recovers the titer effect (RCT)", {
  res <- point_effect(vac_toy_random, treat = "random", outcome = "titer",
                      type = "continuous", K = truth$K)
  # data-generating titer effect is +120 (minus a small age term, marginally ~120)
  expect_equal(res$md, 120, tolerance = 5)
})

test_that("continuous standardization ~ marginal in a randomized trial", {
  marg <- point_effect(vac_toy_random, treat = "random", outcome = "titer",
                       type = "continuous", K = truth$K)
  std  <- point_effect(vac_toy_random, treat = "random", outcome = "titer",
                       type = "continuous", K = truth$K,
                       covariates = c("age", "baseline_risk"))
  expect_equal(marg$md, std$md, tolerance = 1)   # randomization => adjustment changes little
})

test_that("single binary outcome (ever hospitalized) agrees with the survival engine (RCT)", {
  # No censoring/competing events in the RCT toy data, so cumulative-by-K equals KM risk.
  bin <- point_effect(vac_toy_random, treat = "random", outcome = "hosp",
                      type = "binary", reduce = "ever", K = truth$K)
  surv <- pooled_logistic_risk(vac_toy_random, treat = "random", K = truth$K)
  expect_equal(bin$rd, surv$rd, tolerance = 0.01)
  expect_equal(bin$risk1, surv$risk1, tolerance = 0.01)
  expect_equal(bin$risk0, surv$risk0, tolerance = 0.01)
})

test_that("point_effect binary returns coherent risks", {
  bin <- point_effect(vac_toy_random, treat = "random", outcome = "hosp",
                      type = "binary", reduce = "ever", K = truth$K)
  expect_true(bin$risk0 >= 0 && bin$risk0 <= 1 && bin$risk1 >= 0 && bin$risk1 <= 1)
  expect_equal(bin$rr, bin$risk1 / bin$risk0)
})
