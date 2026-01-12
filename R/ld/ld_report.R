#' LD (Light/Dark Box) Report Generation
#'
#' Functions for generating comprehensive LD behavioral analysis reports.
#'
#' @name ld_report
NULL

#' Generate LD report for single arena
#'
#' Creates a comprehensive analysis report for one subject's LD behavior.
#'
#' @param arena_data List. Single arena data from load_ld_data()
#' @param output_dir Character. Directory for output files
#' @param subject_id Character. Subject identifier (default: from arena_data)
#' @param format Character. Report format: "html", "pdf", or "plots_only" (default: "plots_only")
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List with paths to generated files
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' report <- generate_ld_report(ld_data$Arena_1, output_dir = "reports/arena1")
#' }
#'
#' @export
generate_ld_report <- function(arena_data, output_dir, subject_id = NULL,
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

  message("Generating LD report for ", subject_id)

  # Extract data
  df <- arena_data$data

  # Run analysis
  results <- analyze_ld(df, fps = fps)

  # Generate plots
  plots <- generate_ld_plots(df, results, subject_id = subject_id)

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
  generate_ld_summary_text(results, output_files$summary_txt, subject_id = subject_id)

  message("Report generated in: ", output_dir)

  return(output_files)
}

#' Generate LD plots for single subject
#'
#' Creates standard visualization plots for LD analysis.
#'
#' @param df Data frame. LD tracking data with zone columns
#' @param results List. Output from analyze_ld()
#' @param subject_id Character. Subject identifier for titles
#'
#' @return List of ggplot2 objects
#'
#' @keywords internal
generate_ld_plots <- function(df, results, subject_id = "Subject") {
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
  if ("zone_light_floor" %in% zone_cols) {
    zone_boundaries$light <- infer_zone_boundaries(df$x_center, df$y_center,
                                                   df$zone_light_floor)
  }

  # Trajectory plot colored by zone
  zone_data <- NULL
  if ("zone_light_floor" %in% colnames(df)) {
    zone_data <- df$zone_light_floor
  }

  p_trajectory <- plot_trajectory(
    df$x_center, df$y_center,
    color_by = if (!is.null(zone_data)) "zone" else "time",
    zone_data = zone_data,
    zone_boundaries = zone_boundaries,
    title = paste(subject_id, "- Trajectory"),
    point_size = 0.3,
    alpha = 0.5
  )

  # Heatmap
  p_heatmap <- plot_heatmap(
    df$x_center, df$y_center,
    bins = 40,
    title = paste(subject_id, "- Position Heatmap"),
    zone_boundaries = zone_boundaries
  )

  # Zone occupancy bar chart
  zone_times <- c(
    Light = results$time_in_light_sec,
    Dark = results$time_in_dark_sec
  )

  p_zone_time <- plot_zone_occupancy(
    zone_times,
    zone_labels = c("Light", "Dark"),
    title = paste(subject_id, "- Time in Zones"),
    fill_colors = c("Light" = "#FFD700", "Dark" = "#4B4B4B")
  )

  return(list(
    trajectory = p_trajectory,
    heatmap = p_heatmap,
    zone_time = p_zone_time
  ))
}

#' Generate LD summary text report
#'
#' Creates a human-readable text summary of LD metrics.
#'
#' @param results List. Output from analyze_ld()
#' @param output_file Character. Path for output text file
#' @param subject_id Character. Subject identifier
#'
#' @return Invisibly returns output_file path
#'
#' @keywords internal
generate_ld_summary_text <- function(results, output_file, subject_id = "Subject") {
  # Create summary text
  summary_lines <- c(
    "========================================================",
    paste("Light/Dark Box Analysis - ", subject_id),
    "========================================================",
    "",
    "TRIAL INFORMATION:",
    sprintf("  Total Duration: %.2f seconds (%.2f minutes)",
            results$total_duration_sec, results$total_duration_sec / 60),
    sprintf("  Frame Rate: %d fps", results$fps),
    "",
    "TIME IN ZONES:",
    sprintf("  Time in Light: %.2f seconds (%.1f%%)",
            results$time_in_light_sec, results$pct_time_in_light),
    sprintf("  Time in Dark: %.2f seconds (%.1f%%)",
            results$time_in_dark_sec, results$pct_time_in_dark),
    "",
    "ZONE ENTRIES:",
    sprintf("  Entries to Light: %d", results$entries_to_light),
    sprintf("  Entries to Dark: %d", results$entries_to_dark),
    sprintf("  Total Transitions: %d", results$transitions),
    "",
    "LATENCY:",
    sprintf("  Latency to First Light Entry: %.2f seconds",
            ifelse(is.na(results$latency_to_light_sec), Inf,
                   results$latency_to_light_sec)),
    sprintf("  Latency to First Dark Entry: %.2f seconds",
            ifelse(is.na(results$latency_to_dark_sec), Inf,
                   results$latency_to_dark_sec)),
    "",
    "LOCOMOTION:",
    sprintf("  Total Distance Traveled: %.2f cm", results$total_distance_cm),
    sprintf("  Distance in Light: %.2f cm (%.1f%%)",
            results$distance_in_light_cm,
            results$distance_in_light_cm / results$total_distance_cm * 100),
    sprintf("  Distance in Dark: %.2f cm (%.1f%%)",
            results$distance_in_dark_cm,
            results$distance_in_dark_cm / results$total_distance_cm * 100),
    "",
    "INTERPRETATION:",
    interpret_ld_results(results),
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

#' Interpret LD results
#'
#' Provides basic interpretation of LD behavioral metrics.
#'
#' @param results List. Output from analyze_ld()
#'
#' @return Character vector with interpretation
#'
#' @keywords internal
interpret_ld_results <- function(results) {
  interpretation <- c()

  # Anxiety-like behavior interpretation
  if (results$pct_time_in_light < 30) {
    interpretation <- c(interpretation,
      "  - High anxiety-like behavior: Subject spent <30% of time in light zone")
  } else if (results$pct_time_in_light > 50) {
    interpretation <- c(interpretation,
      "  - Low anxiety-like behavior: Subject spent >50% of time in light zone")
  } else {
    interpretation <- c(interpretation,
      "  - Moderate anxiety-like behavior: Subject spent 30-50% of time in light zone")
  }

  # Exploratory behavior
  if (results$entries_to_light < 5) {
    interpretation <- c(interpretation,
      "  - Low exploratory behavior: Few transitions between zones")
  } else if (results$entries_to_light > 15) {
    interpretation <- c(interpretation,
      "  - High exploratory behavior: Frequent transitions between zones")
  }

  # Latency interpretation
  if (!is.na(results$latency_to_light_sec) && results$latency_to_light_sec > 60) {
    interpretation <- c(interpretation,
      "  - High initial avoidance: Long latency to enter light zone")
  }

  return(interpretation)
}

#' Generate batch LD report
#'
#' Creates reports for all arenas in a dataset and a summary comparison.
#'
#' @param ld_data List. Output from load_ld_data()
#' @param output_dir Character. Base directory for reports
#' @param fps Numeric. Frames per second (default: 25)
#' @param generate_comparison Logical. Generate group comparison plots (default: TRUE)
#'
#' @return List with paths to all generated reports
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' reports <- generate_ld_batch_report(ld_data, output_dir = "reports/LD_analysis")
#' }
#'
#' @export
generate_ld_batch_report <- function(ld_data, output_dir, fps = 25,
                                     generate_comparison = TRUE) {
  if (!is.list(ld_data) || length(ld_data) == 0) {
    stop("ld_data must be a non-empty list", call. = FALSE)
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  message("Generating batch LD reports for ", length(ld_data), " arenas")

  # Generate individual reports
  individual_reports <- list()

  for (arena_name in names(ld_data)) {
    arena_output_dir <- file.path(output_dir, arena_name)
    individual_reports[[arena_name]] <- generate_ld_report(
      ld_data[[arena_name]],
      output_dir = arena_output_dir,
      subject_id = arena_name,
      fps = fps
    )
  }

  # Run batch analysis
  batch_results <- analyze_ld_batch(ld_data, fps = fps)

  # Save batch results
  batch_csv <- file.path(output_dir, "all_subjects_metrics.csv")
  write.csv(batch_results, batch_csv, row.names = FALSE)

  message("Batch metrics saved to: ", batch_csv)

  # Generate comparison plots if requested
  comparison_plots <- NULL
  if (generate_comparison && nrow(batch_results) > 1) {
    comparison_plots <- generate_ld_comparison_plots(batch_results, output_dir)
  }

  return(list(
    individual_reports = individual_reports,
    batch_csv = batch_csv,
    comparison_plots = comparison_plots
  ))
}

#' Generate LD comparison plots
#'
#' Creates comparison visualizations across multiple subjects.
#'
#' @param batch_results Data frame. Output from analyze_ld_batch()
#' @param output_dir Character. Directory for output plots
#'
#' @return List with paths to comparison plots
#'
#' @keywords internal
generate_ld_comparison_plots <- function(batch_results, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning("ggplot2 required for comparison plots")
    return(NULL)
  }

  output_files <- list()

  # Create a pseudo-group for plotting (all subjects in one group)
  batch_results$group <- "All"

  # Plot time in light
  if ("pct_time_in_light" %in% colnames(batch_results)) {
    p1 <- ggplot2::ggplot(batch_results,
                          ggplot2::aes(x = arena_name, y = pct_time_in_light)) +
      ggplot2::geom_bar(stat = "identity", fill = "#FFD700") +
      ggplot2::geom_hline(yintercept = 50, linetype = "dashed", color = "red") +
      ggplot2::labs(title = "Time in Light Zone (% by Arena)",
                    x = "Arena", y = "% Time in Light") +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
      )

    output_files$time_in_light <- file.path(output_dir, "comparison_time_in_light.png")
    save_plot(p1, output_files$time_in_light, width = 8, height = 6)
  }

  # Plot entries
  if ("entries_to_light" %in% colnames(batch_results)) {
    p2 <- ggplot2::ggplot(batch_results,
                          ggplot2::aes(x = arena_name, y = entries_to_light)) +
      ggplot2::geom_bar(stat = "identity", fill = "#4682B4") +
      ggplot2::labs(title = "Light Zone Entries by Arena",
                    x = "Arena", y = "Number of Entries") +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
      )

    output_files$entries <- file.path(output_dir, "comparison_entries.png")
    save_plot(p2, output_files$entries, width = 8, height = 6)
  }

  # Plot total distance
  if ("total_distance_cm" %in% colnames(batch_results)) {
    p3 <- ggplot2::ggplot(batch_results,
                          ggplot2::aes(x = arena_name, y = total_distance_cm)) +
      ggplot2::geom_bar(stat = "identity", fill = "#32CD32") +
      ggplot2::labs(title = "Total Distance Traveled by Arena",
                    x = "Arena", y = "Distance (cm)") +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
      )

    output_files$distance <- file.path(output_dir, "comparison_distance.png")
    save_plot(p3, output_files$distance, width = 8, height = 6)
  }

  message("Comparison plots generated")
  return(output_files)
}
