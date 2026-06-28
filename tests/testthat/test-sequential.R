## seq_emulate() stacking: re-basing, multi-trial membership, horizon truncation.

# Hand-built staggered example: person 1 eligible at cal_time 0 and 1 (two trials);
# person 2 eligible only at cal_time 1. Follow K = 3.
mk <- function() {
  data.frame(
    id   = c(1,1,1,1, 2,2,2),
    cal_time = c(0,1,2,3, 1,2,3),
    elig = c(1,1,0,0, 1,0,0),
    hosp = c(0,0,0,1, 0,0,0),
    treat_b = c(1,1,1,1, 0,0,0)
  )
}

test_that("seq_emulate stacks one trial per eligible start time", {
  s <- seq_emulate(mk(), elig = "elig", time = "cal_time", id = "id", K = 3L)
  expect_setequal(unique(s$trial), c(0, 1))
})

test_that("a person eligible at multiple times appears in multiple trials", {
  s <- seq_emulate(mk(), elig = "elig", time = "cal_time", id = "id", K = 3L)
  trials_for_1 <- unique(s$trial[s$id == 1])
  expect_setequal(trials_for_1, c(0, 1))          # person 1 in both trials
  expect_setequal(unique(s$id_new[s$id == 1]), c("1-0", "1-1"))
})

test_that("follow-up time is re-based to each trial and truncated at K", {
  s <- seq_emulate(mk(), elig = "elig", time = "cal_time", id = "id", K = 3L)
  expect_true(all(s$fu >= 0 & s$fu <= 2))         # K = 3 -> fu in 0..2
  # trial starting at cal_time 1 for person 1: cal_time 1,2,3 -> fu 0,1,2
  sub <- s[s$id == 1 & s$trial == 1, ]
  expect_equal(sub$fu, c(0, 1, 2))
})
