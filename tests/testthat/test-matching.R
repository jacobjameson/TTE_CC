## Matching emulates randomization: the matched-cohort estimate should recover the
## truth where the naive estimate is biased (observational toy data).

test_that("matching recovers the truth on confounded observational data", {
  conf <- c("age_cat", "sex", "race", "urban", "baseline_risk")
  naive <- pooled_logistic_risk(vac_toy_obs, treat = "treat", K = truth$K)
  matched <- match_cohort(vac_toy_obs, treat = "treat", covariates = conf)
  est <- pooled_logistic_risk(matched, treat = "treat", K = truth$K)  # marginal after matching
  # matching moves the estimate from the biased naive value toward the truth
  expect_lt(abs(est$rd - truth$obs$rd), abs(naive$rd - truth$obs$rd))
  expect_equal(est$rd, truth$obs$rd, tolerance = 0.04)
})

test_that("match_cohort returns balanced arms and a MatchIt object", {
  conf <- c("age_cat", "sex", "race", "urban", "baseline_risk")
  matched <- match_cohort(vac_toy_obs, treat = "treat", covariates = conf)
  base <- matched[matched$time == 0, ]
  expect_equal(sum(base$treat == 1), sum(base$treat == 0))  # 1:1
  expect_s3_class(attr(matched, "match"), "matchit")
})
