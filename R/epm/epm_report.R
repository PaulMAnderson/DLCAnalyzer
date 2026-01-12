#' EPM (Elevated Plus Maze) Report Generation
#'
#' Functions for generating comprehensive EPM behavioral analysis reports
#' with plots, metrics, and interpretations.
#'
#' @name epm_report
NULL

#' Generate EPM report for single subject
#'
#' Creates a comprehensive analysis report for one subject's EPM behavior,
#' including trajectory plots, heatmaps, zone occupancy charts, and metrics.
#'
#' @param epm_data List. EPM data from load_epm_data()
#' @param output_dir Character. Directory for output files
#' @param subject_id Character. Subject identifier (default: from epm_data)
#' @param format Character. Report format: "plots_only" (default), "html", or "pdf"
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List with paths to generated files:
#'   \describe{
#'     \item{trajectory}{Path to trajectory plot PNG}
#'     \item{heatmap}{Path to heatmap PNG}
#'     \item{zone_time}{Path to zone occupancy bar chart PNG}
#'     \item{metrics_csv}{Path to metrics CSV file}
#'     \item{summary_txt}{Path to summary text file}
#'   }
#'
#' @examples
#' \dontrun{
#' epm_data <- load_epm_data("ID7687_DLC.csv")
#' report <- generate_epm_report(epm_data, output_dir = "reports/EPM_ID7687")
#' }
#'
#' @export
generate_epm_report <- function(epm_data, output_dir, subject_id = NULL,
                                format = "plots_only", fps = NULL) {
  # Validate inputs
  if (!is.list(epm_data) || !"data" %in% names(epm_data)) {
    stop("epm_data must be a list with 'data' element", call. = FALSE)
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Determine subject ID
  if (is.null(subject_id)) {
    subject_id <- epm_data$subject_id
  }

  # Get fps
  if (is.null(fps)) {
    fps <- epm_data$fps
  }

  message("Generating EPM report for ", subject_id)

  # Extract data
  df <- epm_data$data

  # Run analysis
  results <- analyze_epm(epm_data, fps = fps)

  # Generate plots
  message("Creating visualization plots...")
  plots <- generate_epm_plots(df, results, subject_id = subject_id,
                               arena_config = epm_data$arena_config)

  # Save plots
  output_files <- list()

  output_files$trajectory <- file.path(output_dir, paste0(subject_id, "_trajectory.png"))
  save_epm_plot(plots$trajectory, output_files$trajectory, width = 8, height = 8)

  output_files$heatmap <- file.path(output_dir, paste0(subject_id, "_heatmap.png"))
  save_epm_plot(plots$heatmap, output_files$heatmap, width = 8, height = 8)

  output_files$zone_time <- file.path(output_dir, paste0(subject_id, "_zone_time.png"))
  save_epm_plot(plots$zone_time, output_files$zone_time, width = 7, height = 5)

  # Save metrics to CSV
  output_files$metrics_csv <- file.path(output_dir, paste0(subject_id, "_metrics.csv"))
  metrics_df <- as.data.frame(results[!sapply(results, is.list)])
  metrics_df$subject_id <- subject_id
  write.csv(metrics_df, output_files$metrics_csv, row.names = FALSE)

  # Generate summary text
  output_files$summary_txt <- file.path(output_dir, paste0(subject_id, "_summary.txt"))
  generate_epm_summary_text(results, output_files$summary_txt, subject_id = subject_id)

  message("Report generated in: ", output_dir)

  return(invisible(output_files))
}


#' Generate EPM plots for single subject
#'
#' Creates standard visualization plots for EPM analysis including trajectory
#' with arm boundaries, heatmap, and zone occupancy bar chart.
#'
#' @param df Data frame. EPM tracking data with zone columns
#' @param results List. Output from analyze_epm()
#' @param subject_id Character. Subject identifier for plot titles
#' @param arena_config List. Arena configuration for drawing arm boundaries
#'
#' @return List of ggplot2 objects:
#'   \describe{
#'     \item{trajectory}{Trajectory plot colored by zone with arm boundaries}
#'     \item{heatmap}{Position density heatmap}
#'     \item{zone_time}{Zone occupancy bar chart}
#'   }
#'
#' @keywords internal
generate_epm_plots <- function(df, results, subject_id = "Subject", arena_config = NULL) {
  # Load ggplot2 if not already loaded
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 package is required for plotting. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  # Set default arena config if needed
  if (is.null(arena_config)) {
    arena_config <- list(
      arm_length = 40,
      arm_width = 5,
      center_size = 10
    )
  }

  # 1. Trajectory plot with arm boundaries
  p_trajectory <- plot_epm_trajectory(df, arena_config, subject_id)

  # 2. Heatmap
  p_heatmap <- plot_epm_heatmap(df, arena_config, subject_id)

  # 3. Zone occupancy bar chart
  p_zone_time <- plot_epm_zone_time(results, subject_id)

  return(list(
    trajectory = p_trajectory,
    heatmap = p_heatmap,
    zone_time = p_zone_time
  ))
}


#' Plot EPM trajectory with arm boundaries
#'
#' Creates trajectory plot colored by zone (open arms, closed arms, center)
#' with EPM arm boundaries overlaid.
#'
#' @param df Data frame with x, y, and zone columns
#' @param arena_config List with arm dimensions
#' @param subject_id Character for plot title
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_epm_trajectory <- function(df, arena_config, subject_id = "Subject") {
  # Extract arm dimensions
  arm_length <- arena_config$arm_length
  arm_width <- arena_config$arm_width
  center_size <- arena_config$center_size
  center_radius <- center_size / 2

  # Define zone colors
  zone_colors <- ifelse(df$zone_open_arms == 1, "Open arms",
                       ifelse(df$zone_closed_arms == 1, "Closed arms",
                             ifelse(df$zone_center == 1, "Center", "Outside")))

  # Create plot data
  plot_df <- data.frame(
    x = df$x,
    y = df$y,
    zone = factor(zone_colors, levels = c("Open arms", "Closed arms", "Center", "Outside"))
  )

  # Create plot
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = x, y = y, color = zone)) +
    ggplot2::geom_path(alpha = 0.4, linewidth = 0.3) +
    ggplot2::geom_point(size = 0.5, alpha = 0.3) +
    ggplot2::scale_color_manual(
      values = c("Open arms" = "#E74C3C", "Closed arms" = "#3498DB",
                 "Center" = "#2ECC71", "Outside" = "#95A5A6"),
      name = "Zone"
    ) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = paste(subject_id, "- EPM Trajectory"),
      x = "X position (cm)",
      y = "Y position (cm)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      legend.position = "right"
    )

  # Add EPM arm boundaries
  # Center circle
  theta <- seq(0, 2 * pi, length.out = 100)
  center_circle <- data.frame(
    x = center_radius * cos(theta),
    y = center_radius * sin(theta)
  )
  p <- p + ggplot2::geom_path(data = center_circle, ggplot2::aes(x = x, y = y),
                               color = "black", linewidth = 1, inherit.aes = FALSE)

  # Arm boundaries (rectangles)
  # North arm
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_width/2, xmax = arm_width/2,
                             ymin = center_radius, ymax = arm_length,
                             fill = NA, color = "black", linewidth = 0.8, linetype = "dashed")
  # South arm
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_width/2, xmax = arm_width/2,
                             ymin = -arm_length, ymax = -center_radius,
                             fill = NA, color = "black", linewidth = 0.8, linetype = "dashed")
  # East arm
  p <- p + ggplot2::annotate("rect",
                             xmin = center_radius, xmax = arm_length,
                             ymin = -arm_width/2, ymax = arm_width/2,
                             fill = NA, color = "black", linewidth = 0.8, linetype = "dashed")
  # West arm
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_length, xmax = -center_radius,
                             ymin = -arm_width/2, ymax = arm_width/2,
                             fill = NA, color = "black", linewidth = 0.8, linetype = "dashed")

  # Add arm labels
  label_dist <- arm_length * 0.7
  p <- p + ggplot2::annotate("text", x = 0, y = label_dist, label = "North\n(Open)",
                             size = 3, fontface = "bold")
  p <- p + ggplot2::annotate("text", x = 0, y = -label_dist, label = "South\n(Open)",
                             size = 3, fontface = "bold")
  p <- p + ggplot2::annotate("text", x = label_dist, y = 0, label = "East\n(Closed)",
                             size = 3, fontface = "bold")
  p <- p + ggplot2::annotate("text", x = -label_dist, y = 0, label = "West\n(Closed)",
                             size = 3, fontface = "bold")

  return(p)
}


#' Plot EPM position heatmap
#'
#' Creates 2D density heatmap of animal position throughout trial.
#'
#' @param df Data frame with x, y columns
#' @param arena_config List with arm dimensions
#' @param subject_id Character for plot title
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_epm_heatmap <- function(df, arena_config, subject_id = "Subject") {
  # Create heatmap
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::stat_density_2d(ggplot2::aes(fill = ggplot2::after_stat(density)),
                             geom = "raster", contour = FALSE, n = 100) +
    ggplot2::scale_fill_viridis_c(name = "Density", option = "plasma") +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = paste(subject_id, "- Position Heatmap"),
      x = "X position (cm)",
      y = "Y position (cm)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      legend.position = "right"
    )

  # Add arm boundaries
  arm_width <- arena_config$arm_width
  arm_length <- arena_config$arm_length
  center_radius <- arena_config$center_size / 2

  # Center circle
  theta <- seq(0, 2 * pi, length.out = 100)
  center_circle <- data.frame(
    x = center_radius * cos(theta),
    y = center_radius * sin(theta)
  )
  p <- p + ggplot2::geom_path(data = center_circle, ggplot2::aes(x = x, y = y),
                               color = "white", linewidth = 1, inherit.aes = FALSE, alpha = 0.7)

  # Arm boundaries
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_width/2, xmax = arm_width/2,
                             ymin = center_radius, ymax = arm_length,
                             fill = NA, color = "white", linewidth = 0.6, linetype = "dashed", alpha = 0.7)
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_width/2, xmax = arm_width/2,
                             ymin = -arm_length, ymax = -center_radius,
                             fill = NA, color = "white", linewidth = 0.6, linetype = "dashed", alpha = 0.7)
  p <- p + ggplot2::annotate("rect",
                             xmin = center_radius, xmax = arm_length,
                             ymin = -arm_width/2, ymax = arm_width/2,
                             fill = NA, color = "white", linewidth = 0.6, linetype = "dashed", alpha = 0.7)
  p <- p + ggplot2::annotate("rect",
                             xmin = -arm_length, xmax = -center_radius,
                             ymin = -arm_width/2, ymax = arm_width/2,
                             fill = NA, color = "white", linewidth = 0.6, linetype = "dashed", alpha = 0.7)

  return(p)
}


#' Plot EPM zone occupancy bar chart
#'
#' Creates bar chart showing time spent in each zone type.
#'
#' @param results List from analyze_epm()
#' @param subject_id Character for plot title
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_epm_zone_time <- function(results, subject_id = "Subject") {
  # Prepare data
  zone_data <- data.frame(
    Zone = factor(c("Open Arms", "Closed Arms", "Center"),
                 levels = c("Open Arms", "Closed Arms", "Center")),
    Time_sec = c(results$time_in_open_arms_sec,
                results$time_in_closed_arms_sec,
                results$time_in_center_sec),
    Percentage = c(results$pct_time_in_open,
                  results$pct_time_in_closed,
                  results$pct_time_in_center)
  )

  # Create plot
  p <- ggplot2::ggplot(zone_data, ggplot2::aes(x = Zone, y = Percentage, fill = Zone)) +
    ggplot2::geom_bar(stat = "identity", color = "black", linewidth = 0.5) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%\n(%.1fs)", Percentage, Time_sec)),
                      vjust = 1.5, color = "white", fontface = "bold", size = 4) +
    ggplot2::scale_fill_manual(
      values = c("Open Arms" = "#E74C3C", "Closed Arms" = "#3498DB", "Center" = "#2ECC71")
    ) +
    ggplot2::labs(
      title = paste(subject_id, "- Zone Occupancy"),
      subtitle = sprintf("Open Arm Ratio: %.3f (%s)",
                        results$open_arm_ratio,
                        interpret_epm_anxiety(results$open_arm_ratio,
                                            results$entries_ratio,
                                            results$total_arm_entries)),
      x = NULL,
      y = "Time (%)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5),
      legend.position = "none",
      axis.text.x = ggplot2::element_text(size = 11, face = "bold")
    ) +
    ggplot2::ylim(0, max(zone_data$Percentage) * 1.15)

  return(p)
}


#' Save EPM plot to file
#'
#' Wrapper for saving ggplot2 objects to PNG files.
#'
#' @param plot ggplot2 object
#' @param filename Character. Output file path
#' @param width Numeric. Plot width in inches (default: 8)
#' @param height Numeric. Plot height in inches (default: 8)
#' @param dpi Numeric. Resolution (default: 300)
#'
#' @return Invisibly returns filename
#'
#' @keywords internal
save_epm_plot <- function(plot, filename, width = 8, height = 8, dpi = 300) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required for saving plots", call. = FALSE)
  }

  ggplot2::ggsave(filename, plot, width = width, height = height, dpi = dpi)
  message("Plot saved: ", filename)

  return(invisible(filename))
}


#' Generate EPM summary text report
#'
#' Creates a text file with formatted EPM analysis results and interpretation.
#'
#' @param results List from analyze_epm()
#' @param output_file Character. Path for output text file
#' @param subject_id Character. Subject identifier
#'
#' @return Invisibly returns output_file path
#'
#' @keywords internal
generate_epm_summary_text <- function(results, output_file, subject_id = NULL) {
  # Open file connection
  con <- file(output_file, "w")

  # Write header
  writeLines("===============================================", con)
  writeLines("  EPM (Elevated Plus Maze) Analysis Summary", con)
  writeLines("===============================================", con)
  writeLines("", con)

  if (!is.null(subject_id)) {
    writeLines(paste("Subject ID:", subject_id), con)
    writeLines("", con)
  }

  # Anxiety indices
  writeLines("ANXIETY ASSESSMENT:", con)
  writeLines("-------------------", con)
  anxiety_level <- interpret_epm_anxiety(results$open_arm_ratio,
                                          results$entries_ratio,
                                          results$total_arm_entries)
  writeLines(sprintf("Overall Level: %s", anxiety_level), con)
  writeLines("", con)
  writeLines(sprintf("Open Arm Ratio:  %.3f  (time-based anxiety index)", results$open_arm_ratio), con)
  writeLines(sprintf("Entries Ratio:   %.3f  (entry-based anxiety index)", results$entries_ratio), con)
  writeLines("", con)

  # Interpretation guide
  writeLines("Interpretation Guide:", con)
  writeLines("  Open Arm Ratio < 0.15: High anxiety", con)
  writeLines("  Open Arm Ratio 0.15-0.25: Moderate-high anxiety", con)
  writeLines("  Open Arm Ratio 0.25-0.40: Moderate anxiety", con)
  writeLines("  Open Arm Ratio 0.40-0.55: Moderate-low anxiety", con)
  writeLines("  Open Arm Ratio > 0.55: Low anxiety", con)
  writeLines("", con)

  # Time in zones
  writeLines("TIME IN ZONES:", con)
  writeLines("--------------", con)
  writeLines(sprintf("Open arms:     %7.1f sec  (%5.1f%%)", results$time_in_open_arms_sec, results$pct_time_in_open), con)
  writeLines(sprintf("Closed arms:   %7.1f sec  (%5.1f%%)", results$time_in_closed_arms_sec, results$pct_time_in_closed), con)
  writeLines(sprintf("Center:        %7.1f sec  (%5.1f%%)", results$time_in_center_sec, results$pct_time_in_center), con)
  writeLines(sprintf("Total duration:%7.1f sec", results$total_duration_sec), con)
  writeLines("", con)

  # Entry metrics
  writeLines("ARM ENTRIES:", con)
  writeLines("------------", con)
  writeLines(sprintf("Open arms:     %3d", results$entries_to_open), con)
  writeLines(sprintf("Closed arms:   %3d", results$entries_to_closed), con)
  writeLines(sprintf("Center:        %3d", results$entries_to_center), con)
  writeLines(sprintf("Total entries: %3d", results$total_arm_entries), con)

  if (!results$sufficient_exploration) {
    writeLines("", con)
    writeLines("WARNING: Total arm entries < 5", con)
    writeLines("Results may not be reliable due to low exploration.", con)
  }
  writeLines("", con)

  # Latencies
  writeLines("LATENCIES:", con)
  writeLines("----------", con)
  if (!is.na(results$latency_to_open_sec)) {
    writeLines(sprintf("First open arm entry: %.1f sec", results$latency_to_open_sec), con)
  } else {
    writeLines("First open arm entry: Never entered open arms", con)
  }
  writeLines("", con)

  # Locomotor activity
  writeLines("LOCOMOTOR ACTIVITY:", con)
  writeLines("-------------------", con)
  writeLines(sprintf("Total distance:       %7.1f cm", results$total_distance_cm), con)
  writeLines(sprintf("Average velocity:     %7.2f cm/s", results$avg_velocity_cm_s), con)
  writeLines(sprintf("Distance in open:     %7.1f cm", results$distance_in_open_cm), con)
  writeLines(sprintf("Distance in closed:   %7.1f cm", results$distance_in_closed_cm), con)
  writeLines("", con)

  # Footer
  writeLines("===============================================", con)
  writeLines(paste("Generated:", Sys.time()), con)
  writeLines("===============================================", con)

  # Close file
  close(con)

  message("Summary text saved: ", output_file)

  return(invisible(output_file))
}


#' Generate batch EPM report
#'
#' Creates reports for multiple subjects and a combined summary.
#'
#' @param epm_data_list List of EPM data structures
#' @param output_dir Character. Base directory for all reports
#' @param fps Numeric. Frames per second (if not in data structures)
#'
#' @return List with paths to all generated files
#'
#' @examples
#' \dontrun{
#' files <- list.files("data/EPM", pattern = "*.csv", full.names = TRUE)
#' epm_list <- lapply(files, load_epm_data)
#' batch_reports <- generate_epm_batch_report(epm_list, "reports/EPM_batch")
#' }
#'
#' @export
generate_epm_batch_report <- function(epm_data_list, output_dir, fps = NULL) {
  if (!is.list(epm_data_list) || length(epm_data_list) == 0) {
    stop("epm_data_list must be a non-empty list", call. = FALSE)
  }

  message("Generating batch EPM reports for ", length(epm_data_list), " subjects")

  # Create base output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Generate individual reports
  individual_reports <- list()
  for (i in seq_along(epm_data_list)) {
    epm_data <- epm_data_list[[i]]
    subject_id <- epm_data$subject_id

    # Create subject-specific subdirectory
    subject_dir <- file.path(output_dir, subject_id)

    # Generate report
    tryCatch({
      report_files <- generate_epm_report(epm_data, subject_dir, subject_id = subject_id, fps = fps)
      individual_reports[[subject_id]] <- report_files
    }, error = function(e) {
      warning("Failed to generate report for ", subject_id, ": ", e$message)
    })
  }

  # Analyze batch
  batch_results <- analyze_epm_batch(epm_data_list, fps = fps)

  # Export batch results to CSV
  batch_csv <- file.path(output_dir, "EPM_batch_results.csv")
  write.csv(batch_results, batch_csv, row.names = FALSE)

  message("Batch analysis complete. ", length(individual_reports), " reports generated.")
  message("Batch results saved to: ", batch_csv)

  return(invisible(list(
    individual_reports = individual_reports,
    batch_csv = batch_csv,
    batch_results = batch_results
  )))
}
