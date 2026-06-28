# Claude Code skills

Each skill is a folder with a `SKILL.md` (and any assets). Invoke in Claude Code by name,
e.g. `/target-trial`. They build on the course-faithful R engine (`../../R/`) and reference
library (`../../reference/`).

| Track | Skill | Status |
|-------|-------|--------|
| Specify | `target-trial` ⭐ | ✅ shipped (M2) |
| Specify | `time-zero` | ✅ shipped (M2) |
| Specify | `competing-events` | planned (M3) |
| Emulate | `emulate-randomization` | ✅ shipped (M2) |
| Analyze | `tte-estimate` (rct · matching · standardize ✓; sequential · ipw → M3) | ✅ shipped (M2, partial) |
| Check | `check-emulation` | planned (M3) |
| Report | `tte-report` | planned (M3) |

v2 adds `sustained-strategies` and cloning / grace-period analysis (course Sessions 6–8).

Typical flow: **`target-trial` → `time-zero` → `emulate-randomization` → `tte-estimate`**
(then `check-emulation` / `tte-report` when shipped).
