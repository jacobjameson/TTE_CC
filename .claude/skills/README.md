# Claude Code skills (built in milestones M2–M3)

M1 (this commit) ships the foundation: the course-faithful R engine (`../../R/`), the reference
library (`../../reference/`), the synthetic teaching data (`../../data/`), a worked example, and the
test suite. The interactive skills are added next, each as its own folder here with a `SKILL.md`.

Planned v1 skills (see `../../reference/course-map.md` for the methodology each enforces):

| Track | Skill | Milestone |
|-------|-------|-----------|
| Specify | `target-trial` ⭐ | M2 |
| Specify | `time-zero` | M2 |
| Specify | `competing-events` | M3 |
| Emulate | `emulate-randomization` | M2 |
| Analyze | `tte-estimate` (rct · matching · sequential-emulation · ip-weighting) | M2–M3 |
| Check | `check-emulation` | M3 |
| Report | `tte-report` | M3 |

v2 adds `sustained-strategies` and cloning / grace-period analysis (course Sessions 6–8).
