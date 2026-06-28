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
    # weighted logistic emits a harmless "non-integer #successes" note; muffle it
    fit <- withCallingHandlers(
      model_fun(form, family = stats::binomial("logit"), data = d, weights = d[[".w"]]),
      warning = function(w) if (grepl("non-integer", conditionMessage(w))) invokeRestart("muffleWarning"))
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

#' Match a cohort on baseline covariates to emulate randomization (Session 2)
#'
#' Performs 1:1 matching (exact / coarsened-exact by default) on baseline rows and
#' returns the long person-time data restricted to matched individuals. After
#' matching, the matched cohort is approximately exchangeable, so downstream risk
#' estimation can be run MARGINALLY (no further covariate adjustment).
#'
#' @param data long person-time data frame.
#' @param treat baseline treatment column (0/1).
#' @param covariates character vector of baseline covariates to match on.
#' @param id,time column names. @param baseline_time the time index of baseline (default 0).
#' @param method MatchIt method (default "nearest"); `exact` defaults to all covariates.
#' @return long data frame restricted to matched ids (plus attribute "match" = MatchIt object).
match_cohort <- function(data, treat, covariates, id = "id", time = "time",
                         baseline_time = 0L, method = "nearest", exact = covariates) {
  stopifnot(requireNamespace("MatchIt", quietly = TRUE))
  d <- as.data.frame(data)
  base <- d[d[[time]] == baseline_time, , drop = FALSE]
  form <- stats::as.formula(paste(treat, "~", paste(covariates, collapse = " + ")))
  m <- MatchIt::matchit(form, data = base, method = method,
                        exact = stats::reformulate(exact))
  matched_ids <- MatchIt::match.data(m)[[id]]
  out <- d[d[[id]] %in% matched_ids, , drop = FALSE]
  attr(out, "match") <- m
  out
}

#' Emulate a sequence of nested target trials (Session 3 `seq.em`)
#'
#' When individuals are eligible at multiple times, emulate a new trial starting at
#' each eligible time and stack them. Each person may contribute to several trials
#' (and to different arms), so downstream inference must resample at the PERSON level
#' (the bootstrap in `boot_tte` already does this; use the original `id`).
#'
#' For each trial start t0 (a value of `time` at which someone is eligible), the
#' trial includes everyone eligible at t0, followed for K intervals; follow-up time
#' is re-based to the trial (`fu` = time - t0), and a per-trial id (`id_new`) is made.
#'
#' @param data long person-time data frame.
#' @param elig name of the eligibility indicator (1 = eligible at that row's time).
#' @param time calendar-time column (default "cal_time"). @param id person id.
#' @param K horizon (intervals followed within each trial).
#' @param starts trial start times (default: all `time` values with any eligible person).
#' @return stacked long data with added columns `trial`, `fu`, `fu2`, `period`,
#'   `periodsqr`, `id_new`, and a baseline treatment carried forward if `treat_b` exists.
seq_emulate <- function(data, elig, time = "cal_time", id = "id", K = 24L, starts = NULL) {
  d <- as.data.frame(data)
  if (is.null(starts)) starts <- sort(unique(d[[time]][d[[elig]] == 1]))
  parts <- lapply(starts, function(t0) {
    elig_ids <- unique(d[[id]][d[[elig]] == 1 & d[[time]] == t0])
    if (!length(elig_ids)) return(NULL)
    tr <- d[d[[id]] %in% elig_ids & d[[time]] >= t0 & d[[time]] <= t0 + K - 1, , drop = FALSE]
    tr$trial <- t0
    tr$fu <- tr[[time]] - t0
    tr$fu2 <- tr$fu^2
    tr$period <- t0
    tr$periodsqr <- t0^2
    tr$id_new <- paste0(tr[[id]], "-", t0)
    tr
  })
  out <- do.call(rbind, parts[!vapply(parts, is.null, logical(1))])
  rownames(out) <- NULL
  out
}

#' Inverse-probability weights for treatment and censoring (Sessions 4–5)
#'
#' Builds STABILIZED IP weights to emulate randomization for a baseline (point)
#' treatment and, optionally, to correct for informative loss to follow-up
#' (censoring). Returns the input data with weight columns added. Use the result
#' with `pooled_logistic_risk(..., weights = "w")`.
#'
#'   treatment weight (time-fixed): sw_a = P(A=a) / P(A=a | L)               [Session 4]
#'   censoring weight (time-varying): sw_c = ∏ P(C=0|A,t) / P(C=0|A,L,t)     [Session 5]
#'   combined w = sw_a * sw_c, truncated at the `truncate` quantile.
#'
#' @param data long person-time data frame, ordered-able by id, time.
#' @param treat baseline treatment column (0/1, time-fixed within id).
#' @param covariates baseline confounders for the treatment model.
#' @param id,time column names. @param K horizon.
#' @param censor optional name of the censoring (loss-to-follow-up) indicator (1 = censored).
#' @param censor_covariates confounders for the censoring model (defaults to `covariates`).
#' @param stabilize use stabilized weights (default TRUE).
#' @param truncate upper quantile at which to truncate the final weight (default 0.99; NULL = none).
#' @return data with columns `sw_a` (and `sw_c`, `w`); `w` is the (truncated) analysis weight.
ip_weights <- function(data, treat, covariates, id = "id", time = "time", K = 24L,
                       censor = NULL, censor_covariates = NULL,
                       stabilize = TRUE, truncate = 0.99) {
  d <- as.data.frame(data)
  d <- d[order(d[[id]], d[[time]]), , drop = FALSE]

  ## --- treatment weight (time-fixed: one value per person) ---
  base <- d[!duplicated(d[[id]]), , drop = FALSE]          # baseline row per id
  ft <- stats::glm(stats::reformulate(covariates, response = treat),
                   family = stats::binomial("logit"), data = base)
  pd <- stats::predict(ft, base, type = "response")        # P(A=1 | L)
  pn <- if (stabilize) mean(base[[treat]]) else 0.5        # P(A=1) (numerator)
  a <- base[[treat]]
  sw_a_id <- ifelse(a == 1, pn / pd, (1 - pn) / (1 - pd))
  names(sw_a_id) <- base[[id]]
  d$sw_a <- sw_a_id[as.character(d[[id]])]

  ## --- censoring weight (time-varying cumulative product) ---
  if (!is.null(censor)) {
    cc <- if (is.null(censor_covariates)) covariates else censor_covariates
    d$.unc <- as.integer(d[[censor]] == 0)
    d$.t <- d[[time]]; d$.t2 <- d$.t^2
    den_terms <- c(treat, cc, ".t", ".t2")
    num_terms <- c(treat, ".t", ".t2")
    fd <- stats::glm(stats::reformulate(den_terms, response = ".unc"),
                     family = stats::binomial("logit"), data = d)
    d$.pd <- stats::predict(fd, d, type = "response")      # P(C=0 | A, L, t)
    if (stabilize) {
      fn <- stats::glm(stats::reformulate(num_terms, response = ".unc"),
                       family = stats::binomial("logit"), data = d)
      d$.pn <- stats::predict(fn, d, type = "response")
    } else d$.pn <- 1
    # cumulative products within person
    d$sw_c <- ave_cumprod(d$.pn, d[[id]]) / ave_cumprod(d$.pd, d[[id]])
    d$w <- d$sw_a * d$sw_c
    d$.unc <- d$.t <- d$.t2 <- d$.pd <- d$.pn <- NULL
  } else {
    d$w <- d$sw_a
  }

  if (!is.null(truncate)) {
    thr <- stats::quantile(d$w, truncate, na.rm = TRUE)
    d$w <- pmin(d$w, thr)
  }
  d
}

## internal: grouped cumulative product preserving row order
ave_cumprod <- function(x, g) stats::ave(x, g, FUN = cumprod)

#' Transform data to target a competing-events estimand (Session 5 / Lecture 7)
#'
#' Given a competing event (e.g. death), returns the long data shaped for one of
#' three estimands, ready for `pooled_logistic_risk()`:
#'   - "total"     : TOTAL effect ("eternally outcome-free"). Extend each decedent's
#'                   follow-up to the horizon with outcome 0, so the competing event
#'                   keeps them in the risk set as outcome-free thereafter.
#'   - "composite" : composite outcome = event OR competing event.
#'   - "controlled": CONTROLLED DIRECT effect — treat the competing event as
#'                   censoring (drop rows at/after it). NB: ill-defined estimand;
#'                   requires no unmeasured common causes of competing event & outcome.
#'
#' @param data long person-time data.
#' @param outcome binary outcome column (default "hosp").
#' @param competing competing-event indicator column (default "death").
#' @param estimand one of "total","composite","controlled".
#' @param id,time column names. @param K horizon (default max(time)+1).
#' @return transformed long data frame (outcome redefined / rows added or dropped).
competing_events_transform <- function(data, outcome = "hosp", competing = "death",
                                       estimand = c("total", "composite", "controlled"),
                                       id = "id", time = "time", K = NULL) {
  estimand <- match.arg(estimand)
  d <- as.data.frame(data); d <- d[order(d[[id]], d[[time]]), , drop = FALSE]
  if (is.null(K)) K <- max(d[[time]]) + 1L

  if (estimand == "composite") {
    d[[outcome]] <- as.integer(d[[outcome]] == 1 | d[[competing]] == 1)
    return(d)
  }
  if (estimand == "controlled") {
    # censor at the competing event: keep rows strictly before it
    keep <- stats::ave(d[[competing]], d[[id]], FUN = cumsum) == 0
    return(d[keep, , drop = FALSE])
  }
  ## total effect: extend each decedent (who died before K-1, outcome-free) to K-1
  dec <- d[d[[competing]] == 1, , drop = FALSE]
  add <- lapply(seq_len(nrow(dec)), function(i) {
    r <- dec[i, , drop = FALSE]
    dt <- r[[time]]
    if (dt >= K - 1) return(NULL)
    ext <- r[rep(1, K - 1 - dt), , drop = FALSE]
    ext[[time]] <- (dt + 1):(K - 1)
    if ("timesqr" %in% names(ext)) ext$timesqr <- ext[[time]]^2
    ext[[outcome]] <- 0L                 # eternally outcome-free after the competing event
    ext
  })
  add <- do.call(rbind, add[!vapply(add, is.null, logical(1))])
  out <- rbind(d, add)
  out[order(out[[id]], out[[time]]), , drop = FALSE]
}

#' Cloning–censoring–weighting for strategies indistinguishable at time zero
#' (Sessions 7–8: sustained strategies + grace periods)
#'
#' When two sustained strategies share the same data at time zero (e.g. everyone
#' gets a first dose at baseline; the strategies differ only in WHEN a second dose
#' is taken), you cannot assign arms from baseline data without immortal-time bias.
#' Instead: CLONE each person into both arms, CENSOR a clone when its observed data
#' deviate from its assigned strategy, and IP-WEIGHT to undo the selection bias that
#' censoring induces. Returns the cloned, weighted long data (arm 0 vs arm 1), ready
#' for `pooled_logistic_risk(..., treat = "arm", weights = "w")`.
#'
#' Each arm is a window `c(lo, hi)` for the timing of the SECOND dose (the first is
#' at baseline). Exact-timing strategies use lo == hi (Session 7); grace periods use
#' lo < hi (Session 8). Deviation = second dose before `lo` (censor that week) or not
#' received by `hi` (censor at hi + 1). During a grace window the within-window timing
#' is not penalized ("natural" weighting).
#'
#' @param data long person-time data for INITIATORS (first dose at time 0).
#' @param covariates time-varying + baseline confounders for the dose-timing model.
#' @param arm0,arm1 numeric c(lo, hi) second-dose windows for the two strategies.
#' @param treat per-interval dose indicator; @param outcome binary outcome.
#' @param time,id columns; @param treat_cum_lag cumulative-dose-lagged column
#'   (1 while the first—but not yet second—dose has been received).
#' @param K horizon; @param stabilize stabilized weights; @param truncate weight quantile.
#' @return cloned long data with `arm` (0/1), `w` (analysis weight), and `outcome`
#'   set to NA on deviated (censored) person-time.
clone_censor_weight <- function(data, covariates, arm0, arm1,
                                treat = "treat", outcome = "hosp", time = "time",
                                id = "id", treat_cum_lag = "treat_cum_lag1", K = NULL,
                                stabilize = TRUE, truncate = 0.99) {
  d <- as.data.frame(data); d <- d[order(d[[id]], d[[time]]), , drop = FALSE]
  if (is.null(K)) K <- max(d[[time]]) + 1L

  ## second-dose week per person (first dose is at time 0)
  sdw_tab <- tapply(seq_len(nrow(d)), d[[id]], function(ix) {
    tt <- d[[time]][ix]; aa <- d[[treat]][ix]
    w <- tt[tt >= 1 & aa == 1]
    if (length(w)) min(w) else NA_integer_
  })

  ## dose-timing model among decision person-weeks (first dose given, second not yet).
  ## Time terms are always included (dose timing varies with follow-up week), matching
  ## the course's use of calendar time in the weight models.
  d$.t <- d[[time]]; d$.t2 <- d$.t^2
  dec <- d[[treat_cum_lag]] == 1
  den_terms <- c(covariates, ".t", ".t2")
  fd <- stats::glm(stats::reformulate(den_terms, response = treat),
                   family = stats::binomial("logit"), data = d[dec, , drop = FALSE])
  pd <- stats::predict(fd, d, type = "response")
  d$.pd <- ifelse(d[[treat]] == 1, pd, 1 - pd); d$.pd[!dec] <- 1
  if (stabilize) {                                   # numerator: time only (stabilizes)
    fn <- stats::glm(stats::reformulate(c(".t", ".t2"), response = treat),
                     family = stats::binomial("logit"), data = d[dec, , drop = FALSE])
    pn <- stats::predict(fn, d, type = "response")
    d$.pn <- ifelse(d[[treat]] == 1, pn, 1 - pn); d$.pn[!dec] <- 1
  } else d$.pn <- 1

  make_arm <- function(win, a_idx) {
    lo <- win[1]; hi <- win[2]
    cl <- d; cl$arm <- a_idx
    s <- sdw_tab[as.character(cl[[id]])]
    cens_wk <- ifelse(!is.na(s) & s < lo, s,
                ifelse(is.na(s) | s > hi, hi + 1L, NA_integer_))
    cl[[outcome]][!is.na(cens_wk) & cl[[time]] >= cens_wk] <- NA          # deviation -> censor
    if (hi > lo) {                                                        # grace: don't penalize within-window timing
      ingrace <- cl[[time]] >= lo & cl[[time]] <= (hi - 1)
      cl$.pd[ingrace] <- 1; cl$.pn[ingrace] <- 1
    }
    cl <- cl[order(cl[[id]], cl[[time]]), , drop = FALSE]
    cl$w <- ave_cumprod(cl$.pn, cl[[id]]) / ave_cumprod(cl$.pd, cl[[id]])
    cl
  }

  both <- rbind(make_arm(arm0, 0L), make_arm(arm1, 1L))
  if (!is.null(truncate)) {
    thr <- stats::quantile(both$w[!is.na(both[[outcome]])], truncate, na.rm = TRUE)
    both$w <- pmin(both$w, thr)
  }
  both$.pd <- both$.pn <- both$.t <- both$.t2 <- NULL
  both
}

#' Effect on a single (non-time-to-event) outcome — continuous or binary
#'
#' Target trial emulation is NOT limited to time-to-event outcomes. This helper
#' estimates the causal contrast for an outcome measured once per person (e.g. a
#' continuous biomarker at end of follow-up, or a binary yes/no by end of
#' follow-up), under the same confounding-adjustment options as the survival
#' engine: marginal (RCT / matched data), standardization / g-computation over
#' baseline covariates, or IP weighting.
#'
#' Estimand by type:
#'   - "continuous": mean difference  E[Y|a=1] - E[Y|a=0]
#'   - "binary":     risk difference and risk ratio  (P[Y=1|a=1] vs a=0)
#'
#' @param data long person-time OR person-level data frame.
#' @param treat name of the (baseline) treatment column (0/1).
#' @param outcome name of the outcome column.
#' @param type "continuous" or "binary".
#' @param reduce how to collapse long data to one row per person:
#'   "at_time" (take the row at `at`, default for continuous, e.g. titer at K-1),
#'   "ever" (max over follow-up = cumulative binary incidence; default for binary),
#'   or "none" (data already has one row per person).
#' @param at integer time index used when reduce = "at_time" (default K-1).
#' @param id,time column names. @param K horizon.
#' @param covariates baseline covariates to standardize over (g-computation). NULL = marginal.
#' @param weights optional IP-weight column name.
#' @return named list: for continuous `md`; for binary `risk0`,`risk1`,`rd`,`rr`; plus `model`.
point_effect <- function(data, treat, outcome, type = c("continuous", "binary"),
                         reduce = c("auto", "at_time", "ever", "none"),
                         at = NULL, id = "id", time = "time", K = 24L,
                         covariates = NULL, weights = NULL) {
  type <- match.arg(type); reduce <- match.arg(reduce)
  if (reduce == "auto") reduce <- if (type == "binary") "ever" else "at_time"
  if (is.null(at)) at <- K - 1L
  d <- as.data.frame(data)

  # collapse to one row per person
  if (reduce == "at_time") {
    d <- d[d[[time]] == at, , drop = FALSE]
  } else if (reduce == "ever") {
    agg <- stats::aggregate(d[[outcome]], list(id = d[[id]]), max, na.rm = TRUE)
    base <- d[d[[time]] == min(d[[time]]), , drop = FALSE]
    base[[outcome]] <- agg$x[match(base[[id]], agg$id)]
    d <- base
  } # "none": leave as is

  d[[".y"]] <- d[[outcome]]; d[[".a"]] <- d[[treat]]
  fam <- if (type == "binary") stats::binomial("logit") else stats::gaussian()
  rhs <- ".a"
  if (!is.null(covariates)) rhs <- paste(rhs, "+", paste(covariates, collapse = " + "))
  form <- stats::as.formula(paste0(".y ~ ", rhs))
  w <- if (is.null(weights)) NULL else d[[weights]]
  fit <- stats::glm(form, family = fam, data = d, weights = w)

  # g-computation: predict everyone under a=0 and a=1, average
  pred <- function(a) {
    nd <- d; nd[[".a"]] <- a
    p <- as.numeric(stats::predict(fit, nd, type = "response"))
    if (is.null(weights)) mean(p) else stats::weighted.mean(p, d[[weights]])
  }
  m0 <- pred(0); m1 <- pred(1)
  if (type == "binary")
    list(risk0 = m0, risk1 = m1, rd = m1 - m0, rr = m1 / m0, model = fit)
  else
    list(mean0 = m0, mean1 = m1, md = m1 - m0, model = fit)
}

#' Convenience: continuous mean difference at end of follow-up (Session 1)
#' Thin wrapper around point_effect(type = "continuous"); marginal by default.
mean_diff <- function(data, treat, outcome = "titer", time = "time", K = 24L) {
  d <- as.data.frame(data)
  d <- d[d[[time]] == (K - 1), ]
  fit <- stats::glm(stats::as.formula(paste(outcome, "~", treat)),
                    family = stats::gaussian(), data = d)
  ci <- stats::confint.default(fit)[treat, ]
  c(md = unname(stats::coef(fit)[treat]), lower = ci[1], upper = ci[2])
}
