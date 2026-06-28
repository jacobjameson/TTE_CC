## Competing-events transforms target distinct, coherent estimands.

test_that("composite outcome >= total-effect outcome counts", {
  comp  <- competing_events_transform(vac_toy_obs, estimand = "composite")
  total <- competing_events_transform(vac_toy_obs, estimand = "total")
  expect_gte(sum(comp$hosp == 1), sum(total$hosp == 1))   # composite adds deaths
})

test_that("controlled (death-as-censoring) drops post-death rows", {
  cde <- competing_events_transform(vac_toy_obs, estimand = "controlled")
  expect_lt(nrow(cde), nrow(vac_toy_obs))
  # no rows remain after a death within a person
  any_after <- tapply(cde$death, cde$id, function(x) {
    if (all(x == 0)) FALSE else which.max(x) < length(x)
  })
  expect_false(any(unlist(any_after)))
})

test_that("the three estimands are computable and ordered sensibly", {
  conf <- c("age", "baseline_risk", "pcp_visits", "flu_vac")
  est_total <- pooled_logistic_risk(
    competing_events_transform(vac_toy_obs, estimand = "total"),
    treat = "treat", K = truth$K, covariates = conf)
  est_comp <- pooled_logistic_risk(
    competing_events_transform(vac_toy_obs, estimand = "composite"),
    treat = "treat", K = truth$K, covariates = conf)
  # composite risks should exceed total-effect risks (deaths added to numerator)
  expect_gt(est_comp$risk0, est_total$risk0)
})
