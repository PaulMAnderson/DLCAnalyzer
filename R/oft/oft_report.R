#' OFT (Open Field Test) Report Generation
#'
#' Functions for generating comprehensive OFT behavioral analysis reports.
#'
#' @name oft_report
NULL

#' Generate OFT report for single arena
#'
#' Creates a comprehensive analysis report for one subject's OFT behavior.
#'
#' @param arena_data List. Single arena data from load_oft_data()
#' @param output_dir Character. Directory for output files
#' @param subject_id Character. Subject identifier (default: from arena_data)
#' @param format Character. Report format: "html", "pdf", or "plots_only" (default: "plots_only")
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List with paths to generated files
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' report <- generate_oft_report(oft_data$Arena_1, output_dir = "reports/arena1")
#' }
#'
#' @export
generate_oft_report <- function(arena_data, output_dir, subject_id = NULL,
                                format = "plots_only", fps = 25) {
  # Validate inputs
  if (!is.list(arena_data) || !"data" %in% names(arena_data)) {
    stop("arena_data must be a list with 'data' element", call. = FALSE)
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Determine subject ID
  if (is.null(subject_id)) {
    if (!is.null(arena_data$subject_id)) {
      subject_id <- paste0("Subject_", arena_data$subject_id)
    } else if (!is.null(arena_data$arena_id)) {
      subject_id <- paste0("Arena_", arena_data$arena_id)
    } else {
      subject_id <- "Unknown"
    }
  }

  message("Generating OFT report for ", subject_id)

  # Extract data
  df <- arena_data$data

  # Run analysis
  results <- analyze_oft(df, fps = fps)

  # Generate plots
  plots <- generate_oft_plots(df, results, subject_id = subject_id)

  # Save plots
  output_files <- list()

  output_files$trajectory <- file.path(output_dir, paste0(subject_id, "_trajectory.png"))
  save_plot(plots$trajectory, output_files$trajectory, width = 8, height = 6)

  output_files$heatmap <- file.path(output_dir, paste0(subject_id, "_heatmap.png"))
  save_plot(plots$heatmap, output_files$heatmap, width = 8, height = 6)

  output_files$zone_time <- file.path(output_dir, paste0(subject_id, "_zone_time.png"))
  save_plot(plots$zone_time, output_files$zone_time, width = 6, height = 5)

  # Save metrics to CSV
  output_files$metrics_csv <- file.path(output_dir, paste0(subject_id, "_metrics.csv"))
  metrics_df <- as.data.frame(results[!sapply(results, is.list)])
  metrics_df$subject_id <- subject_id
  write.csv(metrics_df, output_files$metrics_csv, row.names = FALSE)

  # Generate summary text
  output_files$summary_txt <- file.path(output_dir, paste0(subject_id, "_summary.txt"))
  generate_oft_summary_text(results, output_files$summary_txt, subject_id = subject_id)

  message("Report generated in: ", output_dir)

  return(output_files)
}

#' Generate OFT plots for single subject
#'
#' Creates standard visualization plots for OFT analysis.
#'
#' @param df Data frame. OFT tracking data with zone columns
#' @param results List. Output from analyze_oft()
#' @param subject_id Character. Subject identifier for titles
#'
#' @return List of ggplot2 objects
#'
#' @keywords internal
generate_oft_plots <- function(df, results, subject_id = "Subject") {
  # Check for required functions
  if (!exists("plot_trajectory") || !exists("plot_heatmap") ||
      !exists("plot_zone_occupancy")) {
    stop("Required plotting functions not found. Ensure R/common/plotting.R is loaded.",
         call. = FALSE)
  }

  # Find zone columns
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)

  # Infer zone boundaries for visualization
  zone_boundaries <- list()
  if ("zone_center" %in% zone_cols) {
    zone_boundaries$center <- infer_zone_boundaries(df$x_center, df$y_center,
                                                    df$zone_center)
  }

  # Trajectory plot colored by zone
  zone_data <- NULL
  if ("zone_center" %in% colnames(df)) {
    zone_data <- df$zone_center
  }

  p_trajectory <- plot_trajectory(
    df$x_center, df$y_center,
    color_by = if (!is.null(zone_data)) "zone" else "time",
    zone_data = zone_data,
    zone_boundaries = zone_boundaries,
    title = paste(subject_id, "- OFT Trajectory"),
    point_size = 0.3,
    alpha = 0.5
  )

  # Heatmap
  p_heatmap <- plot_heatmap(
    df$x_center, df$y_center,
    bins = 40,
    title = paste(subject_id, "- OFT Position Heatmap"),
    zone_boundaries = zone_boundaries
  )

  # Zone occupancy bar chart
  zone_times <- c(
    Center = results$time_in_center_sec,
    Periphery = results$time_in_periphery_sec
  )

  p_zone_time <- plot_zone_occupancy(
    zone_times,
    zone_labels = c("Center", "Periphery"),
    title = paste(subject_id, "- Time in Zones"),
    fill_colors = c("Center" = "#FF6B6B", "Periphery" = "#4ECDC4")
  )

  return(list(
    trajectory = p_trajectory,
    heatmap = p_heatmap,
    zone_time = p_zone_time
  ))
}

#' Generate OFT summary text report
#'
#' Creates a human-readable text summary of OFT metrics.
#'
#' @param results List. Output from analyze_oft()
#' @param output_file Character. Path for output text file
#' @param subject_id Character. Subject identifier
#'
#' @return Invisibly returns output_file path
#'
#' @keywords internal
generate_oft_summary_text <- function(results, output_file, subject_id = "Subject") {
  # Create summary text
  summary_lines <- c(
    "========================================================",
    paste("Open Field Test Analysis - ", subject_id),
    "========================================================",
    "",
    "TRIAL INFORMATION:",
    sprintf("  Total Duration: %.2f seconds (%.2f minutes)",
            results$total_duration_sec, results$total_duration_sec / 60),
    sprintf("  Frame Rate: %d fps", results$fps),
    "",
    "TIME IN ZONES:",
    sprintf("  Time in Center: %.2f seconds (%.1f%%)",
            results$time_in_center_sec, results$pct_time_in_center),
    sprintf("  Time in Periphery: %.2f seconds (%.1f%%)",
            results$time_in_periphery_sec, results$pct_time_in_periphery),
    "",
    "CENTER ZONE ACTIVITY:",
    sprintf("  Entries to Center: %d", results$entries_to_center),
    sprintf("  Latency to First Center Entry: %.2f seconds",
            ifelse(is.na(results$latency_to_center_sec), Inf,
                   results$latency_to_center_sec)),
    "",
    "LOCOMOTION:",
    sprintf("  Total Distance Traveled: %.2f cm", results$total_distance_cm),
    sprintf("  Average Velocity: %.2f cm/s", results$avg_velocity_cm_s),
    sprintf("  Distance in Center: %.2f cm (%.1f%%)",
            results$distance_in_center_cm,
            ifelse(results$total_distance_cm > 0,
                   results$distance_in_center_cm / results$total_distance_cm * 100,
                   0)),
    sprintf("  Distance in Periphery: %.2f cm (%.1f%%)",
            results$distance_in_periphery_cm,
            ifelse(results$total_distance_cm > 0,
                   results$distance_in_periphery_cm / results$total_distance_cm * 100,
                   0))
  )

  # Add thigmotaxis if available
  if (!is.na(results$thigmotaxis_index)) {
    summary_lines <- c(summary_lines,
      "",
      "THIGMOTAXIS (WALL-HUGGING):",
      sprintf("  Time Near Walls: %.2f seconds", results$time_near_wall_sec),
      sprintf("  Thigmotaxis Index: %.3f", results$thigmotaxis_index)
    )
  }

  # Add interpretation
  summary_lines <- c(summary_lines,
    "",
    "INTERPRETATION:",
    interpret_oft_results(results),
    "",
    "========================================================",
    paste("Generated:", Sys.time()),
    "========================================================"
  )

  # Write to file
  writeLines(summary_lines, output_file)

  message("Summary saved to: ", output_file)
  invisible(output_file)
}

#' Interpret OFT results
#'
#' Provides basic interpretation of OFT behavioral metrics.
#'
#' @param results List. Output from analyze_oft()
#'
#' @return Character vector with interpretation
#'
#' @keywords internal
interpret_oft_results <- function(results) {
  interpretation <- c()

  # Anxiety-like behavior interpretation (based on center avoidance)
  if (results$pct_time_in_center < 5) {
    interpretation <- c(interpretation,
      "  - High anxiety-like behavior: Subject spent <5% of time in center zone",
      "    (center avoidance is a classic anxiety phenotype)")
  } else if (results$pct_time_in_center > 15) {
    interpretation <- c(interpretation,
      "  - Low anxiety-like behavior: Subject spent >15% of time in center zone",
      "    (reduced center avoidance suggests lower anxiety)")
  } else {
    interpretation <- c(interpretation,
      "  - Moderate anxiety-like behavior: Subject spent 5-15% of time in center zone")
  }

  # Center entries interpretation
  if (results$entries_to_center < 5) {
    interpretation <- c(interpretation,
      "  - Low exploratory activity: Few entries to center (<5)")
  } else if (results$entries_to_center > 15) {
    interpretation <- c(interpretation,
      "  - High exploratory activity: Many entries to center (>15)")
  }

  # Latency interpretation
  if (!is.na(results$latency_to_center_sec)) {
    if (results$latency_to_center_sec > 60) {
      interpretation <- c(interpretation,
        "  - Delayed center exploration: Latency >60 seconds")
    } else if (results$latency_to_center_sec < 10) {
      interpretation <- c(interpretation,
        "  - Rapid center exploration: Latency <10 seconds")
    }
  } else {
    interpretation <- c(interpretation,
      "  - WARNING: Subject never entered center zone during trial")
  }

  # Locomotor activity interpretation
  duration_min <- results$total_duration_sec / 60
  distance_per_min <- results$total_distance_cm / duration_min

  if (distance_per_min < 500) {
    interpretation <- c(interpretation,
      sprintf("  - Low locomotor activity: %.0f cm/min", distance_per_min))
  } else if (distance_per_min > 1500) {
    interpretation <- c(interpretation,
      sprintf("  - High locomotor activity: %.0f cm/min", distance_per_min))
  } else {
    interpretation <- c(interpretation,
      sprintf("  - Normal locomotor activity: %.0f cm/min", distance_per_min))
  }

  # Thigmotaxis interpretation
  if (!is.na(results$thigmotaxis_index)) {
    if (results$thigmotaxis_index > 0.8) {
      interpretation <- c(interpretation,
        "  - Strong thigmotaxis: Subject spent >80% of time near walls",
        "    (wall-hugging suggests heightened anxiety)")
    }
  }

  return(interpretation)
}

#' Generate batch OFT report for multiple arenas
#'
#' Creates reports for all arenas in a loaded OFT dataset.
#'
#' @param oft_data List. Output from load_oft_data()
#' @param output_dir Character. Base directory for reports
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return Data frame with batch analysis results
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' batch_results <- generate_oft_batch_report(oft_data, output_dir = "reports/oft")
#' }
#'
#' @export
generate_oft_batch_report <- function(oft_data, output_dir, fps = 25) {
  # Validate input
  if (!exists("validate_oft_data")) {
    stop("Required function 'validate_oft_data' not found.", call. = FALSE)
  }

  validate_oft_data(oft_data)

  # Create base output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  message("Generating batch OFT reports for ", length(oft_data), " arenas...")

  # Analyze all arenas
  batch_results <- analyze_oft_batch(oft_data, fps = fps)

  # Generate individual reports
  for (arena_name in names(oft_data)) {
    arena_data <- oft_data[[arena_name]]

    # Create subject-specific directory
    subject_id <- paste0("Arena_", arena_data$arena_id)
    arena_output_dir <- file.path(output_dir, subject_id)

    # Generate report
    generate_oft_report(arena_data, arena_output_dir, subject_id = subject_id, fps = fps)
  }

  # Save batch summary CSV
  batch_summary_file <- file.path(output_dir, "batch_summary.csv")
  export_oft_results(batch_results, batch_summary_file)

  # Generate comparison plots
  comparison_plots_dir <- file.path(output_dir, "comparisons")
  generate_oft_comparison_plots(batch_results, comparison_plots_dir)

  message("Batch report generation complete!")
  message("Results saved to: ", output_dir)

  return(batch_results)
}

#' Generate comparison plots across multiple OFT subjects
#'
#' Creates plots comparing key metrics across subjects.
#'
#' @param batch_results Data frame. Output from analyze_oft_batch()
#' @param output_dir Character. Directory for comparison plots
#'
#' @return List of paths to saved plots
#'
#' @keywords internal
generate_oft_comparison_plots <- function(batch_results, output_dir) {
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  library(ggplot2)

  output_files <- list()

  # 1. Center time comparison
  p_center_time <- ggplot(batch_results, aes(x = arena_name, y = pct_time_in_center)) +
    geom_bar(stat = "identity", fill = "#FF6B6B") +
    labs(title = "Comparison: Percentage Time in Center",
         x = "Arena", y = "% Time in Center") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  output_files$center_time <- file.path(output_dir, "comparison_center_time.png")
  save_plot(p_center_time, output_files$center_time, width = 8, height = 6)

  # 2. Total distance comparison
  p_distance <- ggplot(batch_results, aes(x = arena_name, y = total_distance_cm)) +
    geom_bar(stat = "identity", fill = "#4ECDC4") +
    labs(title = "Comparison: Total Distance Traveled",
         x = "Arena", y = "Distance (cm)") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  output_files$distance <- file.path(output_dir, "comparison_distance.png")
  save_plot(p_distance, output_files$distance, width = 8, height = 6)

  # 3. Center entries comparison
  p_entries <- ggplot(batch_results, aes(x = arena_name, y = entries_to_center)) +
    geom_bar(stat = "identity", fill = "#95E1D3") +
    labs(title = "Comparison: Entries to Center Zone",
         x = "Arena", y = "Number of Entries") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  output_files$entries <- file.path(output_dir, "comparison_entries.png")
  save_plot(p_entries, output_files$entries, width = 8, height = 6)

  # 4. Velocity comparison
  p_velocity <- ggplot(batch_results, aes(x = arena_name, y = avg_velocity_cm_s)) +
    geom_bar(stat = "identity", fill = "#F38181") +
    labs(title = "Comparison: Average Velocity",
         x = "Arena", y = "Velocity (cm/s)") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  output_files$velocity <- file.path(output_dir, "comparison_velocity.png")
  save_plot(p_velocity, output_files$velocity, width = 8, height = 6)

  message("Comparison plots saved to: ", output_dir)

  return(output_files)
}
