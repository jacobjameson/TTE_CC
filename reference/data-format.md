# Required data format: long / person-time

Target trial emulation is done on **long (person-time)** data — **one row per person per follow-up
interval**. Every estimation helper in this toolkit assumes it. Check the format *before* analysis
(`check_person_time()`); convert wide survival data into it with `to_person_time()`.

## The shape
One row per person per interval (here, per week), carrying:

| Column | Meaning |
|---|---|
| `id` | person identifier (repeats across that person's rows) |
| `time` | **integer** follow-up interval, **starting at 0** (`timesqr` = its square) |
| covariates `L` | value at the *start* of the interval (time-fixed repeat; time-varying change) |
| treatment `A` | value at the *end* of the interval (or baseline treatment for point interventions) |
| outcome `Y` | **binary** indicator that the event occurred in this interval |

Plus, as needed: `cal_time` (calendar time for sequential trials), `death` / `censor` (competing
event / loss to follow-up), lagged treatment / cumulative dose for sustained strategies.

Rules the helpers rely on:
- exactly **one row per (id, time)** — no duplicates;
- `time` is integer-valued, **starts at 0**, and is **contiguous** within a person (0,1,2,… no gaps);
- the outcome is **0/1** in each interval (the event is flagged in the interval it occurs);
- time-fixed variables take the same value on all of a person's rows.

## A minimal example
```
id  time  age  treat  hosp
 1     0   52      1     0
 1     1   52      1     0
 1     2   52      1     1     # event in week 2 -> hosp = 1 on this (last) row
 2     0   67      0     0
 2     1   67      0     0     # ... censored / followed onward
```

## Getting there
- **Already long?** Run `check_person_time(data, id, time, outcome)` — it reports duplicates, gaps,
  non-integer/negative time, or a non-binary outcome, and errors on the fatal ones.
- **Wide (one row per person with a survival time + event)?** Use
  `to_person_time(data, id, surv_time, event, K, keep = <baseline covariates>)` to expand to person-time
  (the event is placed in the final interval; follow-up is administratively censored at `K`).
- **Other shapes** (e.g. one row per visit/claim): reshape to one row per person-interval at the time
  scale at which covariates/treatment/outcomes meaningfully change (often weeks or months), then
  validate with `check_person_time()`.

Choosing the interval length is a modeling decision: fine enough that treatment, covariates, and the
outcome don't change materially *within* an interval; coarse enough to be tractable.
