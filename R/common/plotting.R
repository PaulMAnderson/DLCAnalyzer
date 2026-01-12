#' Plotting Functions for DLCAnalyzer
#'
#' Common plotting functions for behavioral tracking data visualization.
#'
#' @name plotting
NULL

#' Plot trajectory
#'
#' Creates a trajectory plot with optional color coding and zone boundaries.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#' @param color_by Character. Variable to color by: "time", "zone", or NULL (default: "time")
#' @param zone_data Numeric vector. Zone membership for color coding (if color_by = "zone")
#' @param zone_boundaries List. Zone boundary information for overlay (optional)
#' @param title Character. Plot title (default: "Trajectory")
#' @param point_size Numeric. Size of trajectory points (default: 0.5)
#' @param alpha Numeric. Transparency of points (default: 0.6)
#'
#' @return A ggplot2 object
#'
#' @examples
#' \dontrun{
#' plot_trajectory(df$x_center, df$y_center, title = "Mouse Movement")
#' }
#'
#' @export
plot_trajectory <- function(x, y, color_by = "time", zone_data = NULL,
                           zone_boundaries = NULL, title = "Trajectory",
                           point_size = 0.5, alpha = 0.6) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  # Create data frame
  df <- data.frame(x = x, y = y, index = seq_along(x))

  # Add color variable
  if (!is.null(color_by) && color_by == "zone" && !is.null(zone_data)) {
    df$color_var <- factor(zone_data)
    color_label <- "Zone"
  } else if (!is.null(color_by) && color_by == "time") {
    df$color_var <- df$index
    color_label <- "Time"
  } else {
    df$color_var <- 1
    color_label <- ""
  }

  # Create plot
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = color_var)) +
    ggplot2::geom_path(alpha = alpha, size = 0.3) +
    ggplot2::geom_point(size = point_size, alpha = alpha) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, x = "X (cm)", y = "Y (cm)", color = color_label) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    )

  # Add zone boundaries if provided
  if (!is.null(zone_boundaries)) {
    for (zone_name in names(zone_boundaries)) {
      zone <- zone_boundaries[[zone_name]]
      if (all(c("x_min", "x_max", "y_min", "y_max") %in% names(zone))) {
        p <- p + ggplot2::geom_rect(
          ggplot2::aes(xmin = zone$x_min, xmax = zone$x_max,
                      ymin = zone$y_min, ymax = zone$y_max),
          fill = NA, color = "red", linetype = "dashed",
          inherit.aes = FALSE
        )
      }
    }
  }

  # Use appropriate color scale
  if (color_label == "Time") {
    p <- p + ggplot2::scale_color_viridis_c(option = "plasma")
  } else if (color_label == "Zone") {
    p <- p + ggplot2::scale_color_manual(values = c("0" = "blue", "1" = "red"))
  }

  return(p)
}

#' Plot heatmap of position density
#'
#' Creates a 2D density heatmap showing where the animal spent most time.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#' @param bins Integer. Number of bins for each axis (default: 50)
#' @param title Character. Plot title (default: "Position Heatmap")
#' @param zone_boundaries List. Zone boundary information for overlay (optional)
#'
#' @return A ggplot2 object
#'
#' @examples
#' \dontrun{
#' plot_heatmap(df$x_center, df$y_center, bins = 40)
#' }
#'
#' @export
plot_heatmap <- function(x, y, bins = 50, title = "Position Heatmap",
                         zone_boundaries = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  df <- data.frame(x = x, y = y)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bin2d(bins = bins) +
    ggplot2::scale_fill_viridis_c(option = "inferno", name = "Count") +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, x = "X (cm)", y = "Y (cm)") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    )

  # Add zone boundaries if provided
  if (!is.null(zone_boundaries)) {
    for (zone_name in names(zone_boundaries)) {
      zone <- zone_boundaries[[zone_name]]
      if (all(c("x_min", "x_max", "y_min", "y_max") %in% names(zone))) {
        p <- p + ggplot2::geom_rect(
          ggplot2::aes(xmin = zone$x_min, xmax = zone$x_max,
                      ymin = zone$y_min, ymax = zone$y_max),
          fill = NA, color = "white", linetype = "dashed", size = 1,
          inherit.aes = FALSE
        )
      }
    }
  }

  return(p)
}

#' Plot zone occupancy bar chart
#'
#' Creates a bar chart showing time spent in different zones.
#'
#' @param zone_times Named numeric vector. Time in seconds for each zone
#' @param zone_labels Character vector. Labels for zones (default: names of zone_times)
#' @param title Character. Plot title (default: "Time in Zones")
#' @param y_label Character. Y-axis label (default: "Time (seconds)")
#' @param fill_colors Character vector. Colors for bars (optional)
#'
#' @return A ggplot2 object
#'
#' @examples
#' \dontrun{
#' zone_times <- c(light = 120, dark = 180)
#' plot_zone_occupancy(zone_times, title = "LD Box Occupancy")
#' }
#'
#' @export
plot_zone_occupancy <- function(zone_times, zone_labels = names(zone_times),
                               title = "Time in Zones", y_label = "Time (seconds)",
                               fill_colors = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  if (is.null(zone_labels)) {
    zone_labels <- paste0("Zone_", seq_along(zone_times))
  }

  df <- data.frame(
    zone = factor(zone_labels, levels = zone_labels),
    time = as.numeric(zone_times)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = zone, y = time, fill = zone)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::labs(title = title, x = "Zone", y = y_label) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      legend.position = "none"
    )

  if (!is.null(fill_colors)) {
    p <- p + ggplot2::scale_fill_manual(values = fill_colors)
  } else {
    p <- p + ggplot2::scale_fill_brewer(palette = "Set2")
  }

  return(p)
}

#' Plot group comparison
#'
#' Creates plots for comparing a metric across experimental groups.
#'
#' @param data Data frame with metric and group columns
#' @param metric_col Character. Name of metric column to plot
#' @param group_col Character. Name of group column
#' @param plot_type Character. Type of plot: "boxplot" or "violin" (default: "boxplot")
#' @param title Character. Plot title (optional)
#' @param y_label Character. Y-axis label (default: metric_col)
#' @param add_points Logical. Add individual points (default: TRUE)
#'
#' @return A ggplot2 object
#'
#' @examples
#' \dontrun{
#' results <- data.frame(
#'   time_in_light = c(120, 150, 100, 180, 200, 170),
#'   group = rep(c("Control", "Treatment"), each = 3)
#' )
#' plot_group_comparison(results, "time_in_light", "group")
#' }
#'
#' @export
plot_group_comparison <- function(data, metric_col, group_col,
                                 plot_type = "boxplot", title = NULL,
                                 y_label = metric_col, add_points = TRUE) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }

  if (!metric_col %in% colnames(data) || !group_col %in% colnames(data)) {
    stop("metric_col and group_col must be column names in data", call. = FALSE)
  }

  if (is.null(title)) {
    title <- paste(metric_col, "by", group_col)
  }

  # Create plot base
  p <- ggplot2::ggplot(data, ggplot2::aes_string(x = group_col, y = metric_col,
                                                 fill = group_col))

  # Add plot type
  if (plot_type == "boxplot") {
    p <- p + ggplot2::geom_boxplot(alpha = 0.7, outlier.shape = NA)
  } else if (plot_type == "violin") {
    p <- p + ggplot2::geom_violin(alpha = 0.7, trim = FALSE)
  } else {
    stop("plot_type must be 'boxplot' or 'violin'", call. = FALSE)
  }

  # Add individual points
  if (add_points) {
    p <- p + ggplot2::geom_jitter(width = 0.2, alpha = 0.5, size = 2)
  }

  # Styling
  p <- p +
    ggplot2::labs(title = title, x = group_col, y = y_label) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      legend.position = "none"
    ) +
    ggplot2::scale_fill_brewer(palette = "Set2")

  return(p)
}

#' Save plot to file
#'
#' Convenience function to save ggplot2 plots with consistent settings.
#'
#' @param plot A ggplot2 object
#' @param filename Character. Output filename
#' @param width Numeric. Plot width in inches (default: 8)
#' @param height Numeric. Plot height in inches (default: 6)
#' @param dpi Numeric. Resolution in DPI (default: 300)
#'
#' @return Invisibly returns filename
#'
#' @examples
#' \dontrun{
#' p <- plot_trajectory(x, y)
#' save_plot(p, "trajectory.png")
#' }
#'
#' @export
save_plot <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  # Create directory if needed
  output_dir <- dirname(filename)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE)
  }

  # Save plot
  ggplot2::ggsave(filename, plot = plot, width = width, height = height,
                  dpi = dpi, units = "in")

  message("Plot saved to: ", filename)
  invisible(filename)
}

#' Create multi-panel figure
#'
#' Combines multiple plots into a single figure.
#'
#' @param plot_list List of ggplot2 objects
#' @param ncol Integer. Number of columns (default: 2)
#' @param nrow Integer. Number of rows (default: NULL, auto-calculated)
#' @param title Character. Overall title (optional)
#'
#' @return A combined plot (requires patchwork or gridExtra package)
#'
#' @examples
#' \dontrun{
#' p1 <- plot_trajectory(x, y)
#' p2 <- plot_heatmap(x, y)
#' combined <- create_multi_panel(list(p1, p2), ncol = 2)
#' }
#'
#' @export
create_multi_panel <- function(plot_list, ncol = 2, nrow = NULL, title = NULL) {
  if (requireNamespace("patchwork", quietly = TRUE)) {
    # Use patchwork if available
    combined <- patchwork::wrap_plots(plot_list, ncol = ncol, nrow = nrow)
    if (!is.null(title)) {
      combined <- combined + patchwork::plot_annotation(title = title)
    }
    return(combined)
  } else if (requireNamespace("gridExtra", quietly = TRUE)) {
    # Fall back to gridExtra
    if (is.null(nrow)) {
      nrow <- ceiling(length(plot_list) / ncol)
    }
    combined <- gridExtra::grid.arrange(grobs = plot_list, ncol = ncol, nrow = nrow,
                                       top = title)
    return(combined)
  } else {
    stop("Either 'patchwork' or 'gridExtra' package is required. ",
         "Install with: install.packages('patchwork')", call. = FALSE)
  }
}
