## Data must be in long / person-time format; check_person_time validates it and
## to_person_time converts wide survival data into it.

test_that("check_person_time passes on valid long data", {
  res <- check_person_time(vac_toy_random, id = "id", time = "time", outcome = "hosp")
  expect_true(res$ok)
  expect_length(res$issues, 0)
})

test_that("check_person_time flags duplicate person-intervals", {
  bad <- rbind(vac_toy_random[1, ], vac_toy_random[1, ])   # duplicate (id, time)
  expect_error(check_person_time(bad, outcome = "hosp"), "duplicate")
})

test_that("check_person_time flags a missing column", {
  expect_error(check_person_time(vac_toy_random[, !names(vac_toy_random) %in% "time"]),
               "missing required column")
})

test_that("wide -> long round-trip recovers the same effect", {
  # collapse the long RCT data to one row per person (wide), then expand back
  wide <- do.call(rbind, by(vac_toy_random, vac_toy_random$id, function(g) {
    data.frame(id = g$id[1], surv_time = max(g$time) + 1,
               event = max(g$hosp), random = g$random[1])
  }))
  long <- to_person_time(wide, id = "id", surv_time = "surv_time", event = "event",
                         K = 24, keep = "random")
  expect_true(check_person_time(long, outcome = "event")$ok)
  orig <- pooled_logistic_risk(vac_toy_random, treat = "random", K = 24)
  rt   <- pooled_logistic_risk(long, treat = "random", outcome = "event", K = 24)
  expect_equal(rt$rd, orig$rd, tolerance = 0.01)
})
