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
| Emulate | `sustained-strategies` | ✅ shipped (v2) |
| Check | `check-emulation` | ✅ shipped |
| Report | `tte-report` | ✅ shipped |

v1 (Sessions 1–5) and v2 (Sessions 6–8: sustained strategies, cloning, grace periods) complete —
the full course is covered.

Typical flow: **`target-trial` → `time-zero` → (`emulate-randomization` and/or
`sustained-strategies`) → `tte-estimate` → `check-emulation` → `tte-report`**.
