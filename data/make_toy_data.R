###############################################################################
## TTE_CC -- Synthetic teaching dataset generator
##
## Creates TWO original, fully-synthetic datasets that MIRROR the structure of a
## target-trial-emulation teaching dataset (an RCT + an observational study of a
## fictional vaccine "VACX" vs. coronavirus hospitalization), in long /
## person-time (weekly) format with a 24-week horizon.
##
##   - vac_toy_random : a randomized trial (treatment independent of covariates)
##   - vac_toy_obs    : an observational study (treatment confounded by covariates)
##
## These are 100% generated here from a known data-generating mechanism, so the
## TRUE marginal 24-week risks / risk difference / risk ratio are known exactly
## (stored in toy_truth.rds). Confounding is deliberately injected into the
## observational data so that a naive analysis is visibly biased while matching /
## standardization / IP weighting recover the truth.
##
## NOTE: This is an independent toy dataset. It does NOT contain or reproduce any
## data from the CAUSALab Target Trial Emulation course. Variable NAMES follow
## common person-time conventions so the code reads like the course's.
##
## Reproducible: set.seed below. Run:  Rscript data/make_toy_data.R
###############################################################################

set.seed(20260628)
suppressWarnings(suppressMessages({
  has_dt <- requireNamespace("data.table", quietly = TRUE)
}))

K <- 24L  # weeks of follow-up (time = 0..K-1; outcomes counted at end of interval)

## ---------------------------------------------------------------------------
## 1. Baseline covariate generator (shared structure for both datasets)
## ---------------------------------------------------------------------------
draw_baseline <- function(n) {
  age <- round(pmin(pmax(rnorm(n, 55, 15), 18), 95))
  age_cat <- cut(age,
                 breaks = c(17,20,25,30,35,40,45,50,55,60,65,70,75,80, Inf),
                 labels = 1:14) |> as.integer()
  sex   <- rbinom(n, 1, 0.52)                      # 0 male, 1 female
  race  <- sample(1:3, n, replace = TRUE, prob = c(0.6, 0.2, 0.2))
  urban <- rbinom(n, 1, 0.7)
  # number of risk factors for severe disease (1=0 rf ... 5=4+ rf), rises with age
  rf_lp <- -1.2 + 0.03 * (age - 55)
  baseline_risk <- 1L + rbinom(n, 4, plogis(rf_lp))
  smoke <- sample(1:3, n, replace = TRUE, prob = c(0.5, 0.3, 0.2))
  bmi   <- round(pmin(pmax(rnorm(n, 28, 5), 15), 55), 1)
  obese <- as.integer(bmi >= 30)
  diabetes <- rbinom(n, 1, plogis(-2 + 0.02 * (age - 55) + 0.05 * (bmi - 28)))
  heartd   <- rbinom(n, 1, plogis(-2.5 + 0.04 * (age - 55)))
  ckd      <- rbinom(n, 1, plogis(-3 + 0.03 * (age - 55)))
  liverd   <- rbinom(n, 1, plogis(-3.2 + 0.02 * (age - 55)))
  cancer   <- rbinom(n, 1, plogis(-3 + 0.03 * (age - 55)))
  pcp_visits <- sample(1:4, n, replace = TRUE, prob = c(0.4, 0.3, 0.2, 0.1))
  flu_vac    <- sample(1:4, n, replace = TRUE, prob = c(0.3, 0.3, 0.25, 0.15))
  data.frame(age, age_cat, sex, race, urban, baseline_risk, smoke, bmi, obese,
             diabetes, heartd, ckd, liverd, cancer, pcp_visits, flu_vac)
}

## A single linear predictor summarizing baseline severity (drives the outcome).
## Higher = sicker = higher weekly hazard of hospitalization.
severity_lp <- function(b) {
  0.030 * (b$age - 55) +
  0.350 * (b$baseline_risk - 1) +
  0.250 * b$diabetes + 0.300 * b$heartd + 0.250 * b$ckd +
  0.200 * b$obese   + 0.150 * (b$smoke - 1)
}

## ---------------------------------------------------------------------------
## 2. Discrete-time hazard model for hospitalization (the "truth")
##    logit h_k = a0 + a1*k + a2*k^2 + bA*treat + severity_lp
##    bA < 0  => vaccine is protective (the known causal effect).
## ---------------------------------------------------------------------------
a0 <- -4.6; a1 <- -0.015; a2 <- 0.0004
bA <- -0.85                       # log-hazard effect of treatment (protective)

haz <- function(k, treat, sev) plogis(a0 + a1 * k + a2 * k^2 + bA * treat + sev)

## Simulate a person-time long dataset given baseline + a (possibly time-fixed)
## treatment vector, returning event week (or NA) under administrative censoring.
sim_event_week <- function(treat, sev) {
  n <- length(sev)
  evt <- rep(NA_integer_, n)
  for (k in 0:(K - 1)) {
    at_risk <- is.na(evt)
    if (!any(at_risk)) break
    p <- haz(k, treat[at_risk], sev[at_risk])
    hit <- rbinom(sum(at_risk), 1, p) == 1
    idx <- which(at_risk)[hit]
    evt[idx] <- k
  }
  evt
}

## Expand a per-person event/censor summary into long person-time rows.
expand_long <- function(base, id, treat_b, evt, death_wk = NULL, cens_wk = NULL) {
  rows <- vector("list", nrow(base))
  for (i in seq_len(nrow(base))) {
    # last observed week = first of event / death / LTFU / administrative end
    ends <- c(evt[i], if (!is.null(death_wk)) death_wk[i],
              if (!is.null(cens_wk)) cens_wk[i], K - 1L)
    last <- min(ends, na.rm = TRUE)
    wk <- 0:last
    d <- base[rep(i, length(wk)), , drop = FALSE]
    d$time <- wk
    d$hosp  <- as.integer(!is.na(evt[i])      & wk == evt[i])
    if (!is.null(death_wk)) d$death  <- as.integer(!is.na(death_wk[i]) & wk == death_wk[i]) else d$death <- 0L
    if (!is.null(cens_wk))  d$censor <- as.integer(!is.na(cens_wk[i])  & wk == cens_wk[i])  else d$censor <- 0L
    d$id <- id[i]
    d$treat_b <- treat_b[i]
    rows[[i]] <- d
  }
  out <- do.call(rbind, rows)
  out$timesqr <- out$time^2
  rownames(out) <- NULL
  out
}

## ---------------------------------------------------------------------------
## 3. RANDOMIZED trial: treatment independent of covariates
## ---------------------------------------------------------------------------
n_rct <- 6000L
b_rct <- draw_baseline(n_rct)
sev_rct <- severity_lp(b_rct)
random  <- rbinom(n_rct, 1, 0.5)             # 1:1 randomization
evt_rct <- sim_event_week(random, sev_rct)

vac_toy_random <- expand_long(b_rct, id = seq_len(n_rct),
                              treat_b = random, evt = evt_rct)
names(vac_toy_random)[names(vac_toy_random) == "treat_b"] <- "random"
vac_toy_random$treat <- vac_toy_random$random   # point treatment == assignment
# secondary continuous outcome: antibody titer at end of follow-up
titer_mean <- 50 + 120 * vac_toy_random$random - 0.3 * (vac_toy_random$age - 55)
vac_toy_random$titer <- round(titer_mean + rnorm(nrow(vac_toy_random), 0, 20), 1)
vac_toy_random <- vac_toy_random[order(vac_toy_random$id, vac_toy_random$time),
                                 c("id","time","timesqr","age","age_cat","sex","race",
                                   "urban","baseline_risk","smoke","bmi","obese","diabetes",
                                   "heartd","ckd","liverd","cancer","pcp_visits","flu_vac",
                                   "random","treat","hosp","titer")]

## ---------------------------------------------------------------------------
## 4. OBSERVATIONAL study: treatment CONFOUNDED by covariates,
##    + informative loss to follow-up (censor) and competing event (death).
## ---------------------------------------------------------------------------
n_obs <- 8000L
b_obs <- draw_baseline(n_obs)
# observational extras present in such cohorts
b_obs$immuno   <- rbinom(n_obs, 1, plogis(-3 + 0.02 * (b_obs$age - 55)))
b_obs$pregnant <- as.integer(b_obs$sex == 1 & b_obs$age < 45) * rbinom(n_obs, 1, 0.05)
sev_obs <- severity_lp(b_obs)

# Confounding: sicker / older / more health-seeking people more likely to get vaccinated
treat_lp <- -0.2 + 0.025 * (b_obs$age - 55) + 0.30 * (b_obs$baseline_risk - 1) +
            0.25 * (b_obs$pcp_visits - 1) + 0.20 * (b_obs$flu_vac - 1)
treat <- rbinom(n_obs, 1, plogis(treat_lp))
evt_obs <- sim_event_week(treat, sev_obs)

# competing event: death (higher for sicker/older); independent-ish of treatment
death_wk <- sim_event_week(rep(0, n_obs), sev_obs - 1.0)   # rarer than hosp
death_wk <- ifelse(runif(n_obs) < 0.5, death_wk, NA_integer_)
# informative LTFU: less health-seeking people drop out more -> needs IPCW
cens_lp <- -3.2 - 0.20 * (b_obs$pcp_visits - 1)
cens_wk <- sim_event_week(rep(0, n_obs), cens_lp)           # crude weekly LTFU
cens_wk <- ifelse(runif(n_obs) < 0.6, cens_wk, NA_integer_)

obs_long <- expand_long(b_obs, id = seq_len(n_obs), treat_b = treat,
                        evt = evt_obs, death_wk = death_wk, cens_wk = cens_wk)
obs_long$cal_time <- obs_long$time            # single enrollment week (baseline = wk 0)
obs_long$cal_timesqr <- obs_long$cal_time^2
obs_long$treat <- obs_long$treat_b            # point (baseline) treatment for v1 spine
obs_long$elig_1 <- 1L                         # all included are eligible (toy)
obs_long$elig_2 <- as.integer(obs_long$treat_b == 1)  # initiators (for v2 cloning)
vac_toy_obs <- obs_long[order(obs_long$id, obs_long$time),
                        c("id","cal_time","cal_timesqr","time","timesqr",
                          "elig_1","elig_2","age","age_cat","sex","race","urban",
                          "baseline_risk","smoke","bmi","obese","diabetes","heartd","ckd",
                          "liverd","cancer","immuno","pregnant","pcp_visits","flu_vac",
                          "treat","treat_b","hosp","death","censor")]

## ---------------------------------------------------------------------------
## 5. GROUND TRUTH (g-formula on the true hazard over the eligible population)
##    True marginal 24-week risk under "everyone treated" vs "everyone untreated".
## ---------------------------------------------------------------------------
true_risk <- function(b, sev, a) {
  S <- rep(1, nrow(b))
  for (k in 0:(K - 1)) S <- S * (1 - haz(k, a, sev))
  mean(1 - S)
}
truth <- list(
  K = K, bA = bA,
  rct = list(risk1 = true_risk(b_rct, sev_rct, 1),
             risk0 = true_risk(b_rct, sev_rct, 0)),
  obs = list(risk1 = true_risk(b_obs, sev_obs, 1),
             risk0 = true_risk(b_obs, sev_obs, 0))
)
truth$rct$rd <- truth$rct$risk1 - truth$rct$risk0
truth$rct$rr <- truth$rct$risk1 / truth$rct$risk0
truth$obs$rd <- truth$obs$risk1 - truth$obs$risk0
truth$obs$rr <- truth$obs$risk1 / truth$obs$risk0

## ---------------------------------------------------------------------------
## 5b. TIME-VARYING dataset for SUSTAINED strategies / cloning (v2; Sessions 6-8)
##     Every person initiates a FIRST dose at baseline (week 0). A SECOND dose is
##     received at a later week whose timing is confounded by a time-varying
##     symptom (symp): symptomatic weeks DELAY the 2nd dose AND raise the outcome
##     hazard -> time-varying confounding. Two doses are more protective than one.
##     Strategies of interest: "2nd dose by week w" for different w.
## ---------------------------------------------------------------------------
K_tv <- 12L
g0 <- -3.0; g_dose2 <- -1.0; g_symp <- 0.9; g_sev <- 1.0   # outcome hazard
hz_outcome <- function(cum2, symp, sev) plogis(g0 + g_dose2 * cum2 + g_symp * symp + g_sev * sev)
p_symp0 <- function(sev) plogis(-1.0 + 0.8 * sev)
p_symp  <- function(prev, sev) plogis(-1.4 + 1.6 * prev + 0.6 * sev)
p_dose2 <- function(symp, k) plogis(-1.6 - 1.1 * symp + 0.15 * k)   # symptomatic -> delay

sim_tv_person <- function(sev) {
  symp <- integer(K_tv); cum <- integer(K_tv); treat <- integer(K_tv)
  hosp <- integer(K_tv)
  cum[1] <- 1L; treat[1] <- 1L                       # first dose at week 0 (index 1)
  symp[1] <- rbinom(1, 1, p_symp0(sev))
  got2 <- FALSE
  evt <- NA_integer_
  for (k in 2:K_tv) {                                # weeks 1..K_tv-1
    symp[k] <- rbinom(1, 1, p_symp(symp[k - 1], sev))
    cum[k] <- cum[k - 1]
    if (!got2 && rbinom(1, 1, p_dose2(symp[k], k - 1)) == 1) {
      treat[k] <- 1L; cum[k] <- 2L; got2 <- TRUE
    }
  }
  for (k in 1:K_tv) {
    if (is.na(evt) && rbinom(1, 1, hz_outcome(as.integer(cum[k] == 2), symp[k], sev)) == 1)
      evt <- k - 1L
  }
  list(symp = symp, cum = cum, treat = treat, evt = evt)
}

n_tv <- 6000L
b_tv <- draw_baseline(n_tv)
sev_tv <- severity_lp(b_tv)
tv_rows <- vector("list", n_tv)
for (i in 1:n_tv) {
  s <- sim_tv_person(sev_tv[i])
  last <- min(c(s$evt, K_tv - 1L), na.rm = TRUE)
  wk <- 0:last
  d <- b_tv[rep(i, length(wk)), , drop = FALSE]
  d$id <- i; d$time <- wk; d$timesqr <- wk^2
  d$symp <- s$symp[wk + 1]
  d$symp_lag1 <- c(0L, s$symp[wk + 1][-length(wk)])
  d$treat <- s$treat[wk + 1]
  d$treat_cum <- s$cum[wk + 1]
  d$treat_cum_lag1 <- c(1L, s$cum[wk + 1][-length(wk)])
  d$first_treat <- 0L
  d$hosp <- as.integer(!is.na(s$evt) & wk == s$evt)
  d$elig_2 <- 1L
  tv_rows[[i]] <- d
}
vac_toy_tv <- do.call(rbind, tv_rows)
vac_toy_tv <- vac_toy_tv[order(vac_toy_tv$id, vac_toy_tv$time),
                         c("id","time","timesqr","age","age_cat","sex","race","urban",
                           "baseline_risk","smoke","bmi","obese","diabetes","heartd","ckd",
                           "liverd","cancer","pcp_visits","flu_vac","symp","symp_lag1",
                           "treat","treat_cum","treat_cum_lag1","first_treat","elig_2","hosp")]
rownames(vac_toy_tv) <- NULL

## Monte-Carlo per-protocol truth: risk under "2nd dose exactly at week w"
## (treat_cum = 1 for weeks 0..w-1, then 2), marginal over severity + symptom paths.
true_risk_tv <- function(w, n_mc = 40000L) {
  sev <- severity_lp(draw_baseline(n_mc))
  alive <- rep(TRUE, n_mc); hit <- rep(FALSE, n_mc)
  symp <- rbinom(n_mc, 1, p_symp0(sev))
  for (k in 0:(K_tv - 1)) {
    if (k > 0) symp <- rbinom(n_mc, 1, p_symp(symp, sev))
    cum2 <- as.integer(k >= w)                       # 2nd dose has been received by week w
    h <- hz_outcome(cum2, symp, sev)
    new <- alive & !hit & (runif(n_mc) < h)
    hit <- hit | new
  }
  mean(hit)
}
truth$tv <- list(K = K_tv,
                 risk_w3 = true_risk_tv(3), risk_w5 = true_risk_tv(5))
truth$tv$rd <- truth$tv$risk_w5 - truth$tv$risk_w3   # later 2nd dose - earlier 2nd dose
truth$tv$rr <- truth$tv$risk_w5 / truth$tv$risk_w3

## ---------------------------------------------------------------------------
## 6. Write outputs (csv + rda + truth)
## ---------------------------------------------------------------------------
out_dir <- if (dir.exists("data")) "data" else "."
write.csv(vac_toy_random, file.path(out_dir, "vac_toy_random.csv"), row.names = FALSE)
write.csv(vac_toy_obs,    file.path(out_dir, "vac_toy_obs.csv"),    row.names = FALSE)
write.csv(vac_toy_tv,     file.path(out_dir, "vac_toy_tv.csv"),     row.names = FALSE)
save(vac_toy_random, file = file.path(out_dir, "vac_toy_random.rda"))
save(vac_toy_obs,    file = file.path(out_dir, "vac_toy_obs.rda"))
save(vac_toy_tv,     file = file.path(out_dir, "vac_toy_tv.rda"))
saveRDS(truth,       file = file.path(out_dir, "toy_truth.rds"))

cat("Toy data written to", normalizePath(out_dir), "\n")
cat(sprintf("RCT  : n=%d, person-weeks=%d | true risk1=%.4f risk0=%.4f RD=%.4f RR=%.3f\n",
            length(unique(vac_toy_random$id)), nrow(vac_toy_random),
            truth$rct$risk1, truth$rct$risk0, truth$rct$rd, truth$rct$rr))
cat(sprintf("OBS  : n=%d, person-weeks=%d | true risk1=%.4f risk0=%.4f RD=%.4f RR=%.3f\n",
            length(unique(vac_toy_obs$id)), nrow(vac_toy_obs),
            truth$obs$risk1, truth$obs$risk0, truth$obs$rd, truth$obs$rr))
cat(sprintf("TV   : n=%d, person-weeks=%d | per-protocol truth: risk(2nd@wk3)=%.4f risk(2nd@wk5)=%.4f RD=%.4f\n",
            length(unique(vac_toy_tv$id)), nrow(vac_toy_tv),
            truth$tv$risk_w3, truth$tv$risk_w5, truth$tv$rd))
