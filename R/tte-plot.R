###############################################################################
## TTE_CC -- House plotting style for cumulative-incidence (risk) curves
##
## Reproduces the look of the course's risk-curve figures: minimal theme,
## cumulative incidence on the y-axis (%), two-colour palette.
##   #E7B800 = comparator / no-treatment   #2E9FDF = treatment
###############################################################################

tte_palette <- c(comparator = "#E7B800", treatment = "#2E9FDF")

#' Plot cumulative-incidence (risk) curves from a pooled_logistic_risk() result
#'
#' @param fit list returned by `pooled_logistic_risk()` (uses `$curve`).
#' @param labels length-2 character vector c(comparator, treatment).
#' @param ymax upper y-limit (proportion). Default auto.
#' @return a ggplot object.
tte_riskplot <- function(fit, labels = c("No treatment", "Treatment"), ymax = NULL) {
  stopifnot(requireNamespace("ggplot2", quietly = TRUE))
  cv <- fit$curve
  # prepend an origin (risk 0 at time 0) so curves start at the y-axis
  cv <- rbind(data.frame(time = 0, risk0 = 0, risk1 = 0, rd = 0, rr = NA), cv)
  if (is.null(ymax)) ymax <- max(cv$risk0, cv$risk1) * 1.1

  ggplot2::ggplot(cv, ggplot2::aes(x = .data$time)) +
    ggplot2::geom_line(ggplot2::aes(y = .data$risk1, colour = "treatment"),
                       linewidth = 1.4) +
    ggplot2::geom_line(ggplot2::aes(y = .data$risk0, colour = "comparator"),
                       linewidth = 1.4) +
    ggplot2::scale_colour_manual(values = tte_palette,
                                 breaks = c("comparator", "treatment"),
                                 labels = labels, name = NULL) +
    ggplot2::scale_y_continuous(
      limits = c(0, ymax),
      labels = function(x) paste0(formatC(100 * x, format = "f", digits = 1), "%")) +
    ggplot2::labs(x = "Weeks", y = "Cumulative incidence (%)") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(
      legend.position = c(0.25, 0.85),
      axis.line = ggplot2::element_line(colour = "black"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank())
}
