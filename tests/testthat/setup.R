## Shared setup for the test suite: locate project root, source helpers, load data.
root <- normalizePath(file.path("..", ".."))
source(file.path(root, "R", "tte-helpers.R"))
source(file.path(root, "R", "tte-plot.R"))
load(file.path(root, "data", "vac_toy_random.rda"))  # vac_toy_random
load(file.path(root, "data", "vac_toy_obs.rda"))      # vac_toy_obs
truth <- readRDS(file.path(root, "data", "toy_truth.rds"))
