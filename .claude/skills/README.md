# Claude Code skills

Each skill is a folder with a `SKILL.md` (and any assets). Invoke in Claude Code by name,
e.g. `/target-trial`. They build on the course-faithful R engine (`../../R/`) and reference
library (`../../reference/`).

| Track | Skill | Status |
|-------|-------|--------|
| Specify | `target-trial` ⭐ | ✅ shipped |
| Specify | `time-zero` | ✅ shipped |
| Specify | `competing-events` | ✅ shipped |
| Emulate | `emulate-randomization` | ✅ shipped |
| Analyze | `tte-estimate` (rct · matching · standardize · ipw+ipcw · sequential · competing-events) | ✅ shipped |
| Check | `check-emulation` | ✅ shipped |
| Report | `tte-report` | ✅ shipped |

v1 complete (course Sessions 1–5). v2 will add `sustained-strategies` and cloning / grace-period
analysis (course Sessions 6–8).

Typical flow: **`target-trial` → `time-zero` → `emulate-randomization` → `tte-estimate`
→ `check-emulation` → `tte-report`**.
