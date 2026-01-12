#' NORT (Novel Object Recognition Test) Report Generation
#'
#' Functions for generating comprehensive NORT behavioral analysis reports.
#'
#' @name nort_report
NULL

#' Generate NORT report for single arena
#'
#' Creates a comprehensive analysis report for one subject's NORT behavior
#' including discrimination index, exploration patterns, and visualizations.
#'
#' @param arena_data List. Single arena data from load_nort_data()
#' @param output_dir Character. Directory for output files
#' @param subject_id Character. Subject identifier (default: from arena_data)
#' @param novel_side Character. Which side is novel: "left" or "right"
#' @param format Character. Report format: "html", "pdf", or "plots_only" (default: "plots_only")
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List with paths to generated files
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx", novel_side = "left")
#' report <- generate_nort_report(
#'   nort_data$Arena_1,
#'   output_dir = "reports/arena1",
#'   novel_side = "left"
#' )
#' }
#'
#' @export
generate_nort_report <- function(arena_data, output_dir, subject_id = NULL,
                                 novel_side = "left", format = "plots_only",
                                 fps = 25) {
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

  # Use novel_side from metadata if available
  if (!is.null(arena_data$novel_side) && arena_data$novel_side != "neither") {
    novel_side <- arena_data$novel_side
  }

  message("Generating NORT report for ", subject_id, " (novel side: ", novel_side, ")")

  # Extract data
  df <- arena_data$data

  # Run analysis
  results <- analyze_nort(df, fps = fps, novel_side = novel_side)

  # Generate plots
  plots <- generate_nort_plots(df, results, subject_id = subject_id, novel_side = novel_side)

  # Save plots
  output_files <- list()

  output_files$trajectory <- file.path(output_dir, paste0(subject_id, "_trajectory.png"))
  save_plot(plots$trajectory, output_files$trajectory, width = 10, height = 6)

  output_files$heatmap <- file.path(output_dir, paste0(subject_id, "_heatmap.png"))
  save_plot(plots$heatmap, output_files$heatmap, width = 8, height = 6)

  output_files$exploration <- file.path(output_dir, paste0(subject_id, "_object_exploration.png"))
  save_plot(plots$exploration, output_files$exploration, width = 6, height = 5)

  # Save metrics to CSV
  output_files$metrics_csv <- file.path(output_dir, paste0(subject_id, "_metrics.csv"))
  metrics_df <- as.data.frame(results[!sapply(results, is.list)])
  metrics_df$subject_id <- subject_id
  write.csv(metrics_df, output_files$metrics_csv, row.names = FALSE)

  # Generate summary text
  output_files$summary_txt <- file.path(output_dir, paste0(subject_id, "_summary.txt"))
  generate_nort_summary_text(results, output_files$summary_txt, subject_id = subject_id)

  message("NORT report generated in: ", output_dir)

  return(output_files)
}

#' Generate NORT plots for single subject
#'
#' Creates standard visualization plots for NORT analysis including dual
#' trajectory (nose + center), heatmap, and object exploration comparison.
#'
#' @param df Data frame. NORT tracking data with zone columns
#' @param results List. Output from analyze_nort()
#' @param subject_id Character. Subject identifier for titles
#' @param novel_side Character. Which side is novel ("left" or "right")
#'
#' @return List of ggplot2 objects
#'
#' @keywords internal
generate_nort_plots <- function(df, results, subject_id = "Subject", novel_side = "left") {
  # Check for required functions
  if (!exists("plot_trajectory") || !exists("plot_heatmap")) {
    stop("Required plotting functions not found. Ensure R/common/plotting.R is loaded.",
         call. = FALSE)
  }

  # Check for ggplot2
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting", call. = FALSE)
  }

  # Dual trajectory plot (nose + center)
  # Nose for exploration, center for locomotion
  p_trajectory <- plot_dual_trajectory_nort(
    df$x_nose, df$y_nose,
    df$x_center, df$y_center,
    title = paste(subject_id, "- NORT Trajectory"),
    subtitle = paste("Nose (exploration) in blue, Center (locomotion) in gray"),
    point_size = 0.3,
    alpha = 0.4
  )

  # Heatmap (using center-point for general arena usage)
  p_heatmap <- plot_heatmap(
    df$x_center, df$y_center,
    bins = 40,
    title = paste(subject_id, "- NORT Position Heatmap")
  )

  # Object exploration comparison
  p_exploration <- plot_object_exploration_comparison(
    novel_time = results$novel_object_time_sec,
    familiar_time = results$familiar_object_time_sec,
    subject_id = subject_id,
    novel_side = novel_side,
    di = results$discrimination_index
  )

  return(list(
    trajectory = p_trajectory,
    heatmap = p_heatmap,
    exploration = p_exploration
  ))
}

#' Plot dual trajectory for NORT
#'
#' Plots both nose-point and center-point trajectories overlaid.
#'
#' @param x_nose Numeric vector. Nose X coordinates
#' @param y_nose Numeric vector. Nose Y coordinates
#' @param x_center Numeric vector. Center X coordinates
#' @param y_center Numeric vector. Center Y coordinates
#' @param title Character. Plot title
#' @param subtitle Character. Plot subtitle
#' @param point_size Numeric. Point size (default: 0.3)
#' @param alpha Numeric. Point transparency (default: 0.4)
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_dual_trajectory_nort <- function(x_nose, y_nose, x_center, y_center,
                                     title = "NORT Trajectory",
                                     subtitle = NULL,
                                     point_size = 0.3, alpha = 0.4) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required", call. = FALSE)
  }

  # Create data frames
  df_nose <- data.frame(
    x = x_nose,
    y = y_nose,
    body_part = "Nose (exploration)",
    stringsAsFactors = FALSE
  )

  df_center <- data.frame(
    x = x_center,
    y = y_center,
    body_part = "Center (locomotion)",
    stringsAsFactors = FALSE
  )

  df_combined <- rbind(df_nose, df_center)

  # Create plot
  p <- ggplot2::ggplot(df_combined, ggplot2::aes(x = x, y = y, color = body_part)) +
    ggplot2::geom_path(alpha = alpha, linewidth = 0.5) +
    ggplot2::scale_color_manual(values = c(
      "Nose (exploration)" = "#2E86AB",
      "Center (locomotion)" = "#A23B72"
    )) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "X Position (cm)",
      y = "Y Position (cm)",
      color = "Body Part"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = "bottom",
      aspect.ratio = 1
    ) +
    ggplot2::coord_fixed()

  return(p)
}

#' Plot object exploration comparison
#'
#' Bar chart comparing exploration time for novel vs familiar objects.
#'
#' @param novel_time Numeric. Time exploring novel object (seconds)
#' @param familiar_time Numeric. Time exploring familiar object (seconds)
#' @param subject_id Character. Subject identifier
#' @param novel_side Character. Which side is novel ("left" or "right")
#' @param di Numeric. Discrimination index (optional, for display)
#'
#' @return ggplot2 object
#'
#' @export
plot_object_exploration_comparison <- function(novel_time, familiar_time,
                                              subject_id = "Subject",
                                              novel_side = "left",
                                              di = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required", call. = FALSE)
  }

  # Create data frame
  exploration_df <- data.frame(
    object = c("Novel", "Familiar"),
    time_sec = c(novel_time, familiar_time),
    side = c(novel_side, ifelse(novel_side == "left", "right", "left")),
    stringsAsFactors = FALSE
  )

  # Create subtitle with DI
  subtitle_text <- if (!is.null(di) && !is.na(di)) {
    sprintf("Discrimination Index: %.3f", di)
  } else {
    NULL
  }

  # Create plot
  p <- ggplot2::ggplot(exploration_df, ggplot2::aes(x = object, y = time_sec, fill = object)) +
    ggplot2::geom_bar(stat = "identity", width = 0.7) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.1fs\n(%s)", time_sec, side)),
      vjust = -0.5,
      size = 4
    ) +
    ggplot2::scale_fill_manual(values = c(
      "Novel" = "#FF6B6B",
      "Familiar" = "#4ECDC4"
    )) +
    ggplot2::labs(
      title = paste(subject_id, "- Object Exploration"),
      subtitle = subtitle_text,
      x = "Object Type",
      y = "Exploration Time (seconds)",
      fill = "Object"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.major.x = ggplot2::element_blank()
    ) +
    ggplot2::ylim(0, max(exploration_df$time_sec) * 1.2)

  return(p)
}

#' Generate NORT summary text report
#'
#' Creates a human-readable text summary of NORT metrics with memory assessment.
#'
#' @param results List. Output from analyze_nort()
#' @param output_file Character. Path for output text file
#' @param subject_id Character. Subject identifier
#'
#' @return Invisibly returns output_file path
#'
#' @keywords internal
generate_nort_summary_text <- function(results, output_file, subject_id = "Subject") {
  # Create summary text
  summary_lines <- c(
    "========================================================",
    paste("Novel Object Recognition Test Analysis -", subject_id),
    "========================================================",
    "",
    "TRIAL INFORMATION:",
    sprintf("  Total Duration: %.2f seconds (%.2f minutes)",
            results$total_duration_sec, results$total_duration_sec / 60),
    sprintf("  Novel Object Side: %s", toupper(results$novel_side)),
    sprintf("  Trial Valid: %s (min exploration: 10s)",
            ifelse(results$is_valid_trial, "YES", "NO")),
    "",
    "OBJECT EXPLORATION:",
    sprintf("  Novel Object Time: %.2f seconds", results$novel_object_time_sec),
    sprintf("  Familiar Object Time: %.2f seconds", results$familiar_object_time_sec),
    sprintf("  Total Exploration Time: %.2f seconds", results$total_exploration_sec),
    sprintf("  Novel Object Approaches: %d", results$novel_entries),
    sprintf("  Familiar Object Approaches: %d", results$familiar_entries),
    "",
    "MEMORY DISCRIMINATION INDICES:",
    sprintf("  Discrimination Index (DI): %.3f", results$discrimination_index),
    sprintf("  Preference Score: %.2f%%", results$preference_score),
    sprintf("  Recognition Index: %.3f", results$recognition_index),
    "",
    "  DI Interpretation:",
    paste0("    ", interpret_nort_di(results$discrimination_index))
  )

  # Add locomotion metrics
  if (!is.na(results$total_distance_cm)) {
    summary_lines <- c(summary_lines,
      "",
      "LOCOMOTOR ACTIVITY:",
      sprintf("  Total Distance Traveled: %.2f cm", results$total_distance_cm),
      sprintf("  Average Velocity: %.2f cm/s", results$avg_velocity_cm_s)
    )
  }

  # Add center zone time if available
  if (!is.na(results$time_in_center_sec)) {
    summary_lines <- c(summary_lines,
      sprintf("  Time in Center Zone: %.2f seconds", results$time_in_center_sec)
    )
  }

  # Add interpretation
  summary_lines <- c(summary_lines,
    "",
    "BEHAVIORAL INTERPRETATION:",
    interpret_nort_results(results),
    "",
    "========================================================",
    "DISCRIMINATION INDEX GUIDE:",
    "  DI > 0.3  : Strong novelty preference - intact memory",
    "  DI 0.1-0.3: Moderate novelty preference - likely intact",
    "  DI -0.1-0.1: Weak/no discrimination - impaired or no learning",
    "  DI < -0.1 : Familiarity preference - neophobia/alternate strategy",
    "",
    "VALIDITY CRITERIA:",
    "  - Minimum 10 seconds total exploration recommended",
    "  - Low exploration may indicate lack of motivation or anxiety",
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

#' Interpret NORT results
#'
#' Provides comprehensive interpretation of NORT behavioral metrics.
#'
#' @param results List. Output from analyze_nort()
#'
#' @return Character vector with interpretation
#'
#' @export
interpret_nort_results <- function(results) {
  interpretation <- c()

  # Memory assessment based on DI
  di <- results$discrimination_index

  if (is.na(di)) {
    interpretation <- c(interpretation,
      "  - No object exploration detected - cannot assess memory function",
      "  - Check if subject was motivated to explore or if objects were salient"
    )
  } else if (di > 0.3) {
    interpretation <- c(interpretation,
      "  - STRONG novelty preference indicates INTACT MEMORY",
      "  - Subject successfully discriminated novel from familiar object",
      sprintf("  - Spent %.1f%% of exploration time with novel object",
              results$preference_score)
    )
  } else if (di > 0.1) {
    interpretation <- c(interpretation,
      "  - MODERATE novelty preference suggests likely intact memory",
      "  - Discrimination was present but not strong",
      "  - Consider individual variation in exploration strategy"
    )
  } else if (di >= -0.1) {
    interpretation <- c(interpretation,
      "  - WEAK/NO discrimination detected",
      "  - May indicate impaired memory or lack of learning during habituation",
      "  - Alternative: objects may not have been sufficiently distinct"
    )
  } else {
    interpretation <- c(interpretation,
      "  - FAMILIARITY preference detected (unusual)",
      "  - May indicate neophobia (fear of novel object)",
      "  - Or alternative exploration strategy (returning to familiar)"
    )
  }

  # Exploration validity
  if (!results$is_valid_trial) {
    interpretation <- c(interpretation,
      "",
      sprintf("  WARNING: Low total exploration (%.1f sec < 10 sec minimum)",
              results$total_exploration_sec),
      "  - Results may not be reliable",
      "  - Subject may have been anxious, unmotivated, or fatigued"
    )
  }

  # Locomotor activity context
  if (!is.na(results$total_distance_cm)) {
    if (results$total_distance_cm < 500) {
      interpretation <- c(interpretation,
        "",
        "  - Low overall locomotor activity detected",
        "  - May indicate anxiety, sedation, or lack of motivation"
      )
    } else if (results$total_distance_cm > 5000) {
      interpretation <- c(interpretation,
        "",
        "  - High overall locomotor activity detected",
        "  - May indicate hyperactivity or anxiety"
      )
    }
  }

  return(interpretation)
}

#' Generate batch NORT report
#'
#' Generates reports for all arenas in NORT data plus comparison plots.
#'
#' @param nort_data List. Output from load_nort_data()
#' @param output_dir Character. Base directory for output
#' @param novel_sides Character vector. Novel side for each arena
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return List of output directories for each arena
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx")
#' reports <- generate_nort_batch_report(
#'   nort_data,
#'   output_dir = "reports/NORT",
#'   novel_sides = c("left", "left", "right", "left")
#' )
#' }
#'
#' @export
generate_nort_batch_report <- function(nort_data, output_dir, novel_sides = NULL,
                                       fps = 25) {
  if (!is.list(nort_data) || length(nort_data) == 0) {
    stop("nort_data must be a non-empty list", call. = FALSE)
  }

  # Create base output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  arena_names <- names(nort_data)
  n_arenas <- length(arena_names)

  # Determine novel_sides
  if (is.null(novel_sides)) {
    novel_sides <- sapply(arena_names, function(an) {
      ns <- nort_data[[an]]$novel_side
      if (is.null(ns) || ns == "neither") "left" else ns
    })
  } else if (length(novel_sides) == 1) {
    novel_sides <- rep(novel_sides, n_arenas)
  } else if (length(novel_sides) != n_arenas) {
    stop("novel_sides must match number of arenas (", n_arenas, ")", call. = FALSE)
  }

  # Generate individual reports
  report_dirs <- list()

  for (i in seq_along(arena_names)) {
    arena_name <- arena_names[i]
    arena_data <- nort_data[[arena_name]]
    novel_side <- novel_sides[i]

    # Create arena-specific directory
    arena_dir <- file.path(output_dir, arena_name)

    tryCatch({
      report_dirs[[arena_name]] <- generate_nort_report(
        arena_data,
        output_dir = arena_dir,
        novel_side = novel_side,
        fps = fps
      )
    }, error = function(e) {
      warning("Error generating report for ", arena_name, ": ", e$message, call. = FALSE)
    })
  }

  # Run batch analysis for comparison plots
  message("Generating batch comparison plots...")
  batch_results <- analyze_nort_batch(nort_data, fps = fps, novel_sides = novel_sides)

  # Generate comparison plots
  comparison_dir <- file.path(output_dir, "batch_comparison")
  generate_nort_comparison_plots(batch_results, comparison_dir)

  message("Batch reports complete. Output in: ", output_dir)

  return(list(
    arena_reports = report_dirs,
    batch_results = batch_results,
    comparison_dir = comparison_dir
  ))
}

#' Generate NORT comparison plots across subjects
#'
#' Creates comparison visualizations for multiple subjects.
#'
#' @param batch_results Data frame. Output from analyze_nort_batch()
#' @param output_dir Character. Directory for comparison plots
#'
#' @return List of output file paths
#'
#' @export
generate_nort_comparison_plots <- function(batch_results, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required", call. = FALSE)
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  output_files <- list()

  # DI comparison
  p_di <- ggplot2::ggplot(batch_results,
                          ggplot2::aes(x = arena_name, y = discrimination_index,
                                      fill = is_valid_trial)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    ggplot2::geom_hline(yintercept = 0.2, linetype = "dotted", color = "green",
                       alpha = 0.5) +
    ggplot2::scale_fill_manual(values = c("TRUE" = "#4ECDC4", "FALSE" = "#FFB6B9"),
                               labels = c("TRUE" = "Valid", "FALSE" = "Low Exploration")) +
    ggplot2::labs(
      title = "Discrimination Index Comparison",
      subtitle = "Green line = 0.2 (threshold for intact memory)",
      x = "Subject",
      y = "Discrimination Index",
      fill = "Trial Status"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  output_files$di_comparison <- file.path(output_dir, "discrimination_index_comparison.png")
  save_plot(p_di, output_files$di_comparison, width = 10, height = 6)

  # Exploration time comparison
  # Reshape for grouped bar chart
  exploration_long <- data.frame(
    subject = rep(batch_results$arena_name, 2),
    object = rep(c("Novel", "Familiar"), each = nrow(batch_results)),
    time = c(batch_results$novel_object_time_sec, batch_results$familiar_object_time_sec),
    stringsAsFactors = FALSE
  )

  p_exploration <- ggplot2::ggplot(exploration_long,
                                   ggplot2::aes(x = subject, y = time, fill = object)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge") +
    ggplot2::scale_fill_manual(values = c("Novel" = "#FF6B6B", "Familiar" = "#4ECDC4")) +
    ggplot2::labs(
      title = "Object Exploration Time Comparison",
      x = "Subject",
      y = "Exploration Time (seconds)",
      fill = "Object Type"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    )

  output_files$exploration_comparison <- file.path(output_dir, "exploration_time_comparison.png")
  save_plot(p_exploration, output_files$exploration_comparison, width = 10, height = 6)

  message("Comparison plots saved to: ", output_dir)

  return(output_files)
}
