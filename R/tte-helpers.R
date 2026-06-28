###############################################################################
## TTE_CC -- Course-faithful estimation helpers
##
## These functions distill the exact estimation recipe taught in the CAUSALab
## Target Trial Emulation hands-on sessions (R track). They are intentionally
## transparent and built from primitives -- pooled logistic discrete-time
## hazards -> survival via cumulative product -> risk -> risk difference/ratio --
## matching the course's pedagogy. See reference/fidelity.md for the mapping from
## each function to the specific hands-on session it is derived from.
##
## Dependencies (all used by the course itself): stats, survival, boot.
###############################################################################

#' Pooled logistic regression risk curves (the canonical engine)
#'
#' Fits a pooled logistic regression for the discrete-time hazard of a binary
#' per-interval outcome and converts it to cumulative-incidence (risk) curves
#' under treatment vs. no treatment, then the K-period risk difference and ratio.
#'
#' Mirrors Hands-on Sessions 1-2 (marginal) and Session 4 (standardization over
#' baseline covariates / g-formula) and Sessions 4-6 (IP-weighted, via `weights`).
#'
#' @param data    long / person-time data frame (one row per person-interval).
#' @param treat   name of the (time-fixed, baseline) treatment column (0/1).
#' @param outcome name of the binary outcome column (default "hosp").
#' @param time    name of the follow-up-time column (default "time", integer 0..K-1).
#' @param id      name of the person-id column (default "id").
#' @param K       horizon (number of intervals; risk reported at interval K-1).
#' @param covariates character vector of baseline covariate columns to adjust for
#'        by STANDARDIZATION (g-formula). If NULL (default), risks are marginal
#'        (appropriate for a randomized trial or an already-matched dataset).
#' @param weights optional name of an IP-weight column (for IPW analyses).
#' @param model_fun fitting function; `stats::glm` (default) or `speedglm::speedglm`.
#' @return list with `curve` (data.frame: time, risk0, risk1, rd, rr), the
#'   K-period scalars `risk0`,`risk1`,`rd`,`rr`, and the fitted `model`.
pooled_logistic_risk <- function(data, treat, outcome = "hosp", time = "time",
                                 id = "id", K = 24L, covariates = NULL,
                                 weights = NULL, model_fun = stats::glm) {
  stopifnot(treat %in% names(data), outcome %in% names(data), time %in% names(data))
  d <- as.data.frame(data)
  d[[".y"]] <- as.integer(d[[outcome]] == 1)
  d[[".a"]] <- d[[treat]]
  d[[".t"]] <- d[[time]]
  d[[".t2"]] <- d[[".t"]]^2

  # pooled logistic with quadratic time + treatment-by-time product terms
  rhs <- ".a + .t + .t2 + .a:.t + .a:.t2"
  if (!is.null(covariates)) rhs <- paste(rhs, "+", paste(covariates, collapse = " + "))
  form <- stats::as.formula(paste0(".y ~ ", rhs))

  if (is.null(weights)) {
    fit <- model_fun(form, family = stats::binomial("logit"), data = d)
  } else {
    d[[".w"]] <- d[[weights]]
    fit <- model_fun(form, family = stats::binomial("logit"), data = d, weights = d[[".w"]])
  }

  risk_curve <- function(a) {
    if (is.null(covariates)) {
      nd <- data.frame(.a = a, .t = 0:(K - 1), .t2 = (0:(K - 1))^2)
      h <- as.numeric(stats::predict(fit, nd, type = "response"))
      1 - cumprod(1 - h)                       # marginal risk at each interval end
    } else {
      base <- d[d[[".t"]] == 0, , drop = FALSE] # one row per person at baseline
      nb <- nrow(base)
      grid <- base[rep(seq_len(nb), each = K), covariates, drop = FALSE]
      grid$.a <- a
      grid$.t <- rep(0:(K - 1), times = nb)
      grid$.t2 <- grid$.t^2
      h <- as.numeric(stats::predict(fit, grid, type = "response"))
      hm <- matrix(h, nrow = K)                 # K x nb
      surv <- apply(1 - hm, 2, cumprod)         # per-person survival, K x nb
      1 - rowMeans(surv)                        # standardized risk at each interval
    }
  }

  risk0 <- risk_curve(0); risk1 <- risk_curve(1)
  curve <- data.frame(time = 1:K, risk0 = risk0, risk1 = risk1,
                      rd = risk1 - risk0, rr = risk1 / risk0)
  list(curve = curve,
       risk0 = risk0[K], risk1 = risk1[K],
       rd = risk1[K] - risk0[K], rr = risk1[K] / risk0[K],
       model = fit)
}

#' Nonparametric Kaplan-Meier risks (cross-check for the parametric engine)
#'
#' Mirrors Hands-on Session 1/2: survfit on counting-process long data with
#' log-log confidence intervals, reporting cumulative incidence (1 - survival).
#'
#' @inheritParams pooled_logistic_risk
#' @return list with `risk0`,`risk1` (+ 95% CIs) and `rd`,`rr` at horizon K, and `fit`.
km_risk <- function(data, treat, outcome = "hosp", time = "time", K = 24L) {
  stopifnot(requireNamespace("survival", quietly = TRUE))
  d <- as.data.frame(data)
  d[[".y"]] <- as.integer(d[[outcome]] == 1)
  d[[".a"]] <- d[[treat]]
  d[[".t"]] <- d[[time]]
  fit <- survival::survfit(
    survival::Surv(.t, .t + 1, .y) ~ .a, data = d, conf.type = "log-log")
  s <- summary(fit, times = K)
  risk0 <- 1 - s$surv[1]; risk1 <- 1 - s$surv[2]
  list(
    risk0 = risk0, risk0_lo = 1 - s$upper[1], risk0_hi = 1 - s$lower[1],
    risk1 = risk1, risk1_lo = 1 - s$upper[2], risk1_hi = 1 - s$lower[2],
    rd = risk1 - risk0, rr = risk1 / risk0, fit = fit)
}

#' ID-resample percentile bootstrap (the course's inference recipe)
#'
#' Resamples PERSONS (ids) with replacement, rebuilds the person-time data for
#' the resampled ids, runs `statistic()` on it, and returns percentile-based
#' confidence intervals. The whole analysis pipeline (matching / weighting /
#' modelling) must live inside `statistic` so it is re-run in every resample --
#' exactly as the course insists.
#'
#' @param data long person-time data frame.
#' @param statistic function(boot_data) -> named numeric vector of estimates.
#' @param R number of bootstrap resamples (course uses 2 "for illustration";
#'        use >= 500 in practice).
#' @param id name of the person-id column.
#' @param conf confidence level (default 0.95).
#' @param seed optional RNG seed.
#' @return data.frame: estimate, lower, upper (one row per returned statistic).
boot_tte <- function(data, statistic, R = 500L, id = "id", conf = 0.95, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  d <- as.data.frame(data)
  ids <- unique(d[[id]])
  point <- statistic(d)
  est <- matrix(NA_real_, nrow = R, ncol = length(point),
                dimnames = list(NULL, names(point)))
  for (b in seq_len(R)) {
    samp <- sample(ids, length(ids), replace = TRUE)
    # rebuild person-time for resampled ids (many-to-many: ids may repeat)
    idx <- lapply(samp, function(i) which(d[[id]] == i))
    bd <- d[unlist(idx), , drop = FALSE]
    bd[[".bootid"]] <- rep(seq_along(samp), lengths(idx))
    est[b, ] <- statistic(bd)
  }
  a <- (1 - conf) / 2
  data.frame(
    statistic = names(point),
    estimate = as.numeric(point),
    lower = apply(est, 2, stats::quantile, probs = a,     na.rm = TRUE),
    upper = apply(est, 2, stats::quantile, probs = 1 - a, na.rm = TRUE),
    row.names = NULL)
}

#' Convenience: continuous-outcome mean difference at end of follow-up (Session 1)
mean_diff <- function(data, treat, outcome = "titer", time = "time", K = 24L) {
  d <- as.data.frame(data)
  d <- d[d[[time]] == (K - 1), ]
  fit <- stats::glm(stats::as.formula(paste(outcome, "~", treat)),
                    family = stats::gaussian(), data = d)
  ci <- stats::confint.default(fit)[treat, ]
  c(md = unname(stats::coef(fit)[treat]), lower = ci[1], upper = ci[2])
}
