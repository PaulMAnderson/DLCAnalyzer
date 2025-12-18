# R/visualization/plot_tracking.R
# Visualization functions for tracking data

#' Plot tracking heatmap
#'
#' Creates a 2D density heatmap showing animal position over time
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param body_part Body part to plot (default: "mouse_center")
#' @param bins Number of bins for heatmap (default: 50)
#'
#' @return ggplot object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_configs("arena.yaml", arena_id = "arena1")
#' p <- plot_heatmap(tracking_data, arena)
#' print(p)
#' }
plot_heatmap <- function(tracking_data, arena_config,
                        body_part = "mouse_center", bins = 50) {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  # Validate inputs
  if (!inherits(tracking_data, "tracking_data")) {
    stop("tracking_data must be a tracking_data object")
  }
  if (!inherits(arena_config, "arena_config")) {
    stop("arena_config must be an arena_config object")
  }

  # Extract tracking data for specified body part
  track_df <- tracking_data$tracking
  if (!body_part %in% track_df$body_part) {
    stop(sprintf("Body part '%s' not found in tracking data", body_part))
  }

  # Filter to body part
  track_df <- track_df[track_df$body_part == body_part, ]

  # Remove NA values
  track_df <- track_df[!is.na(track_df$x) & !is.na(track_df$y), ]

  if (nrow(track_df) == 0) {
    stop("No valid tracking data for specified body part")
  }

  # Create base plot with 2D density
  p <- ggplot2::ggplot(track_df, ggplot2::aes(x = x, y = y)) +
    ggplot2::stat_density_2d(
      ggplot2::aes(fill = ggplot2::after_stat(density)),
      geom = "raster",
      contour = FALSE,
      bins = bins
    ) +
    ggplot2::scale_fill_viridis_c(
      name = "Occupancy\nDensity",
      option = "plasma"
    ) +
    ggplot2::coord_fixed() +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Position Heatmap",
      subtitle = sprintf("Body part: %s", body_part),
      x = "X Position (pixels)",
      y = "Y Position (pixels)"
    ) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5)
    )

  # Add zone boundaries if available
  if (!is.null(arena_config$zones) && length(arena_config$zones) > 0) {
    zone_boundaries <- extract_zone_boundaries(arena_config)
    if (!is.null(zone_boundaries)) {
      p <- p + ggplot2::geom_path(
        data = zone_boundaries,
        ggplot2::aes(x = x, y = y, group = zone_id),
        color = "white",
        size = 0.8,
        linetype = "dashed"
      )
    }
  }

  return(p)
}


#' Plot trajectory
#'
#' Plots the animal's path through the arena
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param body_part Body part to plot (default: "mouse_center")
#' @param color_by_time Color trajectory by time (default: TRUE)
#' @param max_points Maximum points to plot (for performance, default: 5000)
#'
#' @return ggplot object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_configs("arena.yaml", arena_id = "arena1")
#' p <- plot_trajectory(tracking_data, arena)
#' print(p)
#' }
plot_trajectory <- function(tracking_data, arena_config,
                           body_part = "mouse_center",
                           color_by_time = TRUE, max_points = 5000) {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  # Validate inputs
  if (!inherits(tracking_data, "tracking_data")) {
    stop("tracking_data must be a tracking_data object")
  }
  if (!inherits(arena_config, "arena_config")) {
    stop("arena_config must be an arena_config object")
  }

  # Extract tracking data for specified body part
  track_df <- tracking_data$tracking
  if (!body_part %in% track_df$body_part) {
    stop(sprintf("Body part '%s' not found in tracking data", body_part))
  }

  # Filter to body part
  track_df <- track_df[track_df$body_part == body_part, ]

  # Remove NA values
  track_df <- track_df[!is.na(track_df$x) & !is.na(track_df$y), ]

  if (nrow(track_df) == 0) {
    stop("No valid tracking data for specified body part")
  }

  # Downsample if too many points
  if (nrow(track_df) > max_points) {
    indices <- seq(1, nrow(track_df), length.out = max_points)
    track_df <- track_df[indices, ]
  }

  # Create base plot
  if (color_by_time) {
    p <- ggplot2::ggplot(track_df, ggplot2::aes(x = x, y = y, color = time)) +
      ggplot2::geom_path(size = 0.5, alpha = 0.7) +
      ggplot2::scale_color_viridis_c(
        name = "Time (s)",
        option = "viridis"
      )
  } else {
    p <- ggplot2::ggplot(track_df, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_path(color = "#2c7bb6", size = 0.5, alpha = 0.7)
  }

  # Add start and end points
  p <- p +
    ggplot2::geom_point(
      data = track_df[1, ],
      ggplot2::aes(x = x, y = y),
      color = "green",
      size = 3,
      shape = 21,
      fill = "lightgreen",
      stroke = 1.5
    ) +
    ggplot2::geom_point(
      data = track_df[nrow(track_df), ],
      ggplot2::aes(x = x, y = y),
      color = "red",
      size = 3,
      shape = 21,
      fill = "pink",
      stroke = 1.5
    ) +
    ggplot2::coord_fixed() +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Movement Trajectory",
      subtitle = sprintf("Body part: %s (Start: green, End: red)", body_part),
      x = "X Position (pixels)",
      y = "Y Position (pixels)"
    ) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5)
    )

  # Add zone boundaries if available
  if (!is.null(arena_config$zones) && length(arena_config$zones) > 0) {
    zone_boundaries <- extract_zone_boundaries(arena_config)
    if (!is.null(zone_boundaries)) {
      p <- p + ggplot2::geom_path(
        data = zone_boundaries,
        ggplot2::aes(x = x, y = y, group = zone_id),
        color = "black",
        size = 0.8,
        linetype = "dashed",
        inherit.aes = FALSE
      )
    }
  }

  return(p)
}


#' Plot zone occupancy
#'
#' Creates bar or pie chart of time spent in each zone
#'
#' @param occupancy_data Data frame from calculate_zone_occupancy()
#' @param plot_type Type of plot: "bar", "pie", or "both" (default: "bar")
#'
#' @return ggplot object or list of ggplot objects (if plot_type = "both")
#'
#' @export
#'
#' @examples
#' \dontrun{
#' occupancy <- calculate_zone_occupancy(tracking_data, arena)
#' p <- plot_zone_occupancy(occupancy, plot_type = "bar")
#' print(p)
#' }
plot_zone_occupancy <- function(occupancy_data, plot_type = "bar") {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  # Validate inputs
  if (!is.data.frame(occupancy_data)) {
    stop("occupancy_data must be a data frame")
  }
  if (!plot_type %in% c("bar", "pie", "both")) {
    stop("plot_type must be 'bar', 'pie', or 'both'")
  }

  required_cols <- c("zone_id", "percentage")
  if (!all(required_cols %in% names(occupancy_data))) {
    stop(sprintf("occupancy_data must contain columns: %s",
                 paste(required_cols, collapse = ", ")))
  }

  plots <- list()

  # Bar chart
  if (plot_type %in% c("bar", "both")) {
    p_bar <- ggplot2::ggplot(occupancy_data,
                            ggplot2::aes(x = zone_id, y = percentage, fill = zone_id)) +
      ggplot2::geom_bar(stat = "identity", color = "black", size = 0.3) +
      ggplot2::scale_fill_brewer(palette = "Set2", name = "Zone") +
      ggplot2::labs(
        title = "Zone Occupancy",
        x = "Zone",
        y = "Percentage of Time (%)"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
        legend.position = "none"
      )

    plots$bar <- p_bar
  }

  # Pie chart
  if (plot_type %in% c("pie", "both")) {
    # Calculate positions for labels
    occupancy_data$pos <- cumsum(occupancy_data$percentage) - 0.5 * occupancy_data$percentage

    p_pie <- ggplot2::ggplot(occupancy_data,
                            ggplot2::aes(x = "", y = percentage, fill = zone_id)) +
      ggplot2::geom_bar(stat = "identity", width = 1, color = "white") +
      ggplot2::coord_polar("y", start = 0) +
      ggplot2::scale_fill_brewer(palette = "Set2", name = "Zone") +
      ggplot2::geom_text(
        ggplot2::aes(y = pos, label = sprintf("%.1f%%", percentage)),
        color = "white",
        fontface = "bold"
      ) +
      ggplot2::labs(title = "Zone Occupancy Distribution") +
      ggplot2::theme_void() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
      )

    plots$pie <- p_pie
  }

  # Return appropriate plot(s)
  if (plot_type == "both") {
    return(plots)
  } else {
    return(plots[[plot_type]])
  }
}


#' Plot zone transitions
#'
#' Visualizes transitions between zones
#'
#' @param transition_data Data frame from calculate_zone_transitions()
#' @param plot_type Type of plot: "matrix", "network", or "chord" (default: "matrix")
#' @param min_transitions Minimum transitions to show (filter noise, default: 5)
#'
#' @return ggplot object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' transitions <- calculate_zone_transitions(tracking_data, arena)
#' p <- plot_zone_transitions(transitions, plot_type = "matrix")
#' print(p)
#' }
plot_zone_transitions <- function(transition_data, plot_type = "matrix",
                                  min_transitions = 5) {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  # Validate inputs
  if (!is.data.frame(transition_data)) {
    stop("transition_data must be a data frame")
  }
  if (!plot_type %in% c("matrix", "network", "chord")) {
    stop("plot_type must be 'matrix', 'network', or 'chord'")
  }

  required_cols <- c("from_zone", "to_zone", "n_transitions")
  if (!all(required_cols %in% names(transition_data))) {
    stop(sprintf("transition_data must contain columns: %s",
                 paste(required_cols, collapse = ", ")))
  }

  # Filter by minimum transitions
  transition_data <- transition_data[transition_data$n_transitions >= min_transitions, ]

  if (nrow(transition_data) == 0) {
    warning("No transitions meet the minimum threshold")
    return(NULL)
  }

  # For now, implement matrix plot (heatmap)
  # Network and chord plots require additional packages
  if (plot_type == "matrix") {
    p <- ggplot2::ggplot(transition_data,
                        ggplot2::aes(x = from_zone, y = to_zone, fill = n_transitions)) +
      ggplot2::geom_tile(color = "white", size = 0.5) +
      ggplot2::geom_text(
        ggplot2::aes(label = n_transitions),
        color = "white",
        fontface = "bold"
      ) +
      ggplot2::scale_fill_viridis_c(
        name = "Number of\nTransitions",
        option = "inferno"
      ) +
      ggplot2::labs(
        title = "Zone Transition Matrix",
        x = "From Zone",
        y = "To Zone"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
      )

    return(p)
  } else {
    stop(sprintf("Plot type '%s' not yet implemented. Only 'matrix' is currently supported.",
                plot_type))
  }
}


#' Extract zone boundaries for plotting
#'
#' Internal helper function to extract zone boundary coordinates
#'
#' @param arena_config arena_config object
#'
#' @return Data frame with x, y, zone_id columns, or NULL if no zones
#'
#' @keywords internal
extract_zone_boundaries <- function(arena_config) {
  if (is.null(arena_config$zones) || length(arena_config$zones) == 0) {
    return(NULL)
  }

  boundaries_list <- lapply(names(arena_config$zones), function(zone_id) {
    zone <- arena_config$zones[[zone_id]]

    if (zone$type == "polygon" && !is.null(zone$vertices)) {
      # For polygons, use vertices
      df <- as.data.frame(zone$vertices)
      # Close the polygon
      df <- rbind(df, df[1, ])
      df$zone_id <- zone_id
      return(df)
    } else if (zone$type == "circle" && !is.null(zone$center) && !is.null(zone$radius)) {
      # For circles, generate points around perimeter
      theta <- seq(0, 2 * pi, length.out = 100)
      x <- zone$center$x + zone$radius * cos(theta)
      y <- zone$center$y + zone$radius * sin(theta)
      df <- data.frame(x = x, y = y, zone_id = zone_id)
      return(df)
    } else if (zone$type == "rectangle" && !is.null(zone$bounds)) {
      # For rectangles, create boundary
      x <- c(zone$bounds$x_min, zone$bounds$x_max, zone$bounds$x_max,
             zone$bounds$x_min, zone$bounds$x_min)
      y <- c(zone$bounds$y_min, zone$bounds$y_min, zone$bounds$y_max,
             zone$bounds$y_max, zone$bounds$y_min)
      df <- data.frame(x = x, y = y, zone_id = zone_id)
      return(df)
    }

    return(NULL)
  })

  # Combine all boundaries
  boundaries_list <- boundaries_list[!sapply(boundaries_list, is.null)]

  if (length(boundaries_list) == 0) {
    return(NULL)
  }

  boundaries <- do.call(rbind, boundaries_list)
  return(boundaries)
}
