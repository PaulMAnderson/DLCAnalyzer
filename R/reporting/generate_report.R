# R/reporting/generate_report.R
# Functions for generating analysis reports

#' Generate subject report
#'
#' Creates comprehensive analysis report for a single subject
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object
#' @param output_dir Directory for output files (default: "reports")
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param format Report format: "html", "pdf", or "both" (default: "html")
#'
#' @return List with paths to generated report file(s) and metrics
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load data
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_configs("arena.yaml", arena_id = "arena1")
#'
#' # Generate report
#' report <- generate_subject_report(tracking_data, arena,
#'                                   output_dir = "reports/subject1")
#' }
generate_subject_report <- function(tracking_data, arena_config,
                                   output_dir = "reports",
                                   body_part = "mouse_center",
                                   format = "html") {
  # Validate inputs
  if (!inherits(tracking_data, "tracking_data")) {
    stop("tracking_data must be a tracking_data object")
  }
  if (!inherits(arena_config, "arena_config")) {
    stop("arena_config must be an arena_config object")
  }
  if (!format %in% c("html", "pdf", "both")) {
    stop("format must be 'html', 'pdf', or 'both'")
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  plots_dir <- file.path(output_dir, "plots")
  if (!dir.exists(plots_dir)) {
    dir.create(plots_dir, recursive = TRUE)
  }

  # Get subject ID from metadata
  subject_id <- tracking_data$metadata$subject_id
  if (is.null(subject_id) || subject_id == "") {
    subject_id <- "unknown"
  }

  message(sprintf("Generating report for subject: %s", subject_id))

  # 1. Run quality checks
  message("  - Running quality checks...")
  quality_results <- tryCatch({
    assess_tracking_quality(tracking_data, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Quality assessment failed: %s", e$message))
    NULL
  })

  # 2. Calculate all metrics
  message("  - Calculating zone metrics...")

  # Zone occupancy
  occupancy <- tryCatch({
    calculate_zone_occupancy(tracking_data, arena_config, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Zone occupancy calculation failed: %s", e$message))
    NULL
  })

  # Zone entries
  entries <- tryCatch({
    calculate_zone_entries(tracking_data, arena_config, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Zone entries calculation failed: %s", e$message))
    NULL
  })

  # Zone exits
  exits <- tryCatch({
    calculate_zone_exits(tracking_data, arena_config, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Zone exits calculation failed: %s", e$message))
    NULL
  })

  # Zone latency
  latency <- tryCatch({
    calculate_zone_latency(tracking_data, arena_config, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Zone latency calculation failed: %s", e$message))
    NULL
  })

  # Zone transitions
  transitions <- tryCatch({
    calculate_zone_transitions(tracking_data, arena_config, body_part = body_part)
  }, error = function(e) {
    warning(sprintf("Zone transitions calculation failed: %s", e$message))
    NULL
  })

  # 3. Generate plots (if visualization functions are available)
  message("  - Generating plots...")
  plot_files <- list()

  # Heatmap
  if (exists("plot_heatmap")) {
    tryCatch({
      p <- plot_heatmap(tracking_data, arena_config, body_part = body_part)
      heatmap_file <- file.path(plots_dir, "heatmap.png")
      ggsave(heatmap_file, p, width = 8, height = 6, dpi = 300)
      plot_files$heatmap <- heatmap_file
    }, error = function(e) {
      warning(sprintf("Heatmap generation failed: %s", e$message))
    })
  }

  # Trajectory
  if (exists("plot_trajectory")) {
    tryCatch({
      p <- plot_trajectory(tracking_data, arena_config, body_part = body_part)
      trajectory_file <- file.path(plots_dir, "trajectory.png")
      ggsave(trajectory_file, p, width = 8, height = 6, dpi = 300)
      plot_files$trajectory <- trajectory_file
    }, error = function(e) {
      warning(sprintf("Trajectory plot generation failed: %s", e$message))
    })
  }

  # Occupancy plot
  if (!is.null(occupancy) && exists("plot_zone_occupancy")) {
    tryCatch({
      p <- plot_zone_occupancy(occupancy, plot_type = "bar")
      occupancy_file <- file.path(plots_dir, "occupancy.png")
      ggsave(occupancy_file, p, width = 8, height = 6, dpi = 300)
      plot_files$occupancy <- occupancy_file
    }, error = function(e) {
      warning(sprintf("Occupancy plot generation failed: %s", e$message))
    })
  }

  # Transitions plot
  if (!is.null(transitions) && exists("plot_zone_transitions")) {
    tryCatch({
      p <- plot_zone_transitions(transitions, plot_type = "matrix")
      transitions_file <- file.path(plots_dir, "transitions.png")
      ggsave(transitions_file, p, width = 8, height = 6, dpi = 300)
      plot_files$transitions <- transitions_file
    }, error = function(e) {
      warning(sprintf("Transitions plot generation failed: %s", e$message))
    })
  }

  # 4. Save metrics as CSV
  message("  - Saving metrics...")
  metrics_file <- file.path(output_dir, sprintf("%s_metrics.csv", subject_id))

  # Combine all metrics into a single data frame
  all_metrics <- list()

  if (!is.null(occupancy)) {
    occupancy$metric_type <- "occupancy"
    all_metrics$occupancy <- occupancy
  }
  if (!is.null(entries)) {
    entries$metric_type <- "entries"
    all_metrics$entries <- entries
  }
  if (!is.null(latency)) {
    latency$metric_type <- "latency"
    all_metrics$latency <- latency
  }

  if (length(all_metrics) > 0) {
    tryCatch({
      combined_metrics <- do.call(rbind, lapply(names(all_metrics), function(name) {
        df <- all_metrics[[name]]
        df$subject_id <- subject_id
        df
      }))
      write.csv(combined_metrics, metrics_file, row.names = FALSE)
    }, error = function(e) {
      warning(sprintf("Failed to save metrics: %s", e$message))
    })
  }

  # 5. Generate HTML/PDF report using R Markdown (if template exists)
  message("  - Generating report document...")
  report_files <- list()

  template_file <- system.file("templates", "subject_report.Rmd",
                               package = "DLCAnalyzer")
  if (template_file == "") {
    # Try local path
    template_file <- file.path("inst", "templates", "subject_report.Rmd")
  }

  if (file.exists(template_file)) {
    tryCatch({
      # Prepare data for template
      report_data <- list(
        subject_id = subject_id,
        paradigm = tracking_data$metadata$paradigm,
        date = Sys.Date(),
        fps = tracking_data$metadata$fps,
        n_frames = nrow(tracking_data$tracking),
        duration = nrow(tracking_data$tracking) / tracking_data$metadata$fps,
        quality_summary = quality_results,
        occupancy = occupancy,
        entries = entries,
        exits = exits,
        latency = latency,
        transitions = transitions,
        plot_files = plot_files
      )

      # Render report
      if (format %in% c("html", "both")) {
        output_file <- file.path(output_dir, sprintf("%s_report.html", subject_id))
        rmarkdown::render(template_file,
                         output_file = output_file,
                         params = report_data,
                         quiet = TRUE)
        report_files$html <- output_file
      }

      if (format %in% c("pdf", "both")) {
        output_file <- file.path(output_dir, sprintf("%s_report.pdf", subject_id))
        rmarkdown::render(template_file,
                         output_format = "pdf_document",
                         output_file = output_file,
                         params = report_data,
                         quiet = TRUE)
        report_files$pdf <- output_file
      }
    }, error = function(e) {
      warning(sprintf("Report rendering failed: %s", e$message))
      warning("Metrics and plots have been saved, but report document could not be generated")
    })
  } else {
    message("  - Note: R Markdown template not found, skipping report document generation")
    message("    Metrics and plots have been saved to: ", output_dir)
  }

  message("Report generation complete!")

  # Return list of output files
  result <- list(
    subject_id = subject_id,
    output_dir = output_dir,
    metrics_file = metrics_file,
    plot_files = plot_files,
    report_files = report_files,
    metrics = list(
      quality = quality_results,
      occupancy = occupancy,
      entries = entries,
      exits = exits,
      latency = latency,
      transitions = transitions
    )
  )

  class(result) <- "dlc_report"
  return(result)
}


#' Print method for dlc_report objects
#'
#' @param x A dlc_report object
#' @param ... Additional arguments (not used)
#'
#' @export
print.dlc_report <- function(x, ...) {
  cat("DLCAnalyzer Report\n")
  cat("==================\n\n")
  cat(sprintf("Subject ID: %s\n", x$subject_id))
  cat(sprintf("Output Directory: %s\n\n", x$output_dir))

  cat("Generated Files:\n")
  cat(sprintf("  Metrics: %s\n", x$metrics_file))

  if (length(x$plot_files) > 0) {
    cat("  Plots:\n")
    for (name in names(x$plot_files)) {
      cat(sprintf("    - %s: %s\n", name, x$plot_files[[name]]))
    }
  }

  if (length(x$report_files) > 0) {
    cat("  Reports:\n")
    for (name in names(x$report_files)) {
      cat(sprintf("    - %s: %s\n", toupper(name), x$report_files[[name]]))
    }
  }

  invisible(x)
}


#' Generate group comparison report
#'
#' Compares multiple subjects or groups
#'
#' @param tracking_data_list List of tracking_data objects
#' @param arena_config arena_config object
#' @param group_info Data frame with columns: subject_id, group, treatment, etc.
#' @param output_dir Directory for output (default: "reports")
#' @param comparisons List of comparisons to make (e.g., list(c("control", "treatment")))
#' @param format Report format: "html", "pdf", or "both"
#'
#' @return Path to generated report
#'
#' @export
generate_group_report <- function(tracking_data_list, arena_config,
                                 group_info, output_dir = "reports",
                                 comparisons = NULL, format = "html",
                                 body_part = "mouse_center",
                                 scale_factor = NULL) {
  # Validate inputs
  if (!is.list(tracking_data_list) || length(tracking_data_list) == 0) {
    stop("tracking_data_list must be a non-empty list of tracking_data objects")
  }

  if (!is.data.frame(group_info)) {
    stop("group_info must be a data frame")
  }

  if (!"subject_id" %in% names(group_info) || !"group" %in% names(group_info)) {
    stop("group_info must contain 'subject_id' and 'group' columns")
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  message("Generating group comparison report...")

  # Extract metrics for each subject
  message("  - Extracting metrics for each subject...")
  all_metrics <- lapply(seq_along(tracking_data_list), function(i) {
    tryCatch({
      extract_all_metrics(tracking_data_list[[i]], arena_config,
                         body_part, scale_factor)
    }, error = function(e) {
      warning(sprintf("Failed to extract metrics for subject %d: %s", i, e$message))
      NULL
    })
  })

  # Filter out failed extractions
  all_metrics <- all_metrics[!sapply(all_metrics, is.null)]

  if (length(all_metrics) == 0) {
    stop("Failed to extract metrics for any subject")
  }

  # Add subject IDs to metrics
  for (i in seq_along(all_metrics)) {
    all_metrics[[i]]$subject_id <- group_info$subject_id[i]
    all_metrics[[i]]$group <- group_info$group[i]
  }

  # Combine all metrics
  combined_metrics <- do.call(rbind, all_metrics)

  # Save combined metrics
  metrics_file <- file.path(output_dir, "group_metrics.csv")
  write.csv(combined_metrics, metrics_file, row.names = FALSE)
  message(sprintf("  - Saved combined metrics to: %s", metrics_file))

  # Perform group comparisons
  message("  - Performing statistical comparisons...")
  comparison_results <- list()

  if (is.null(comparisons)) {
    # Compare all unique groups pairwise
    unique_groups <- unique(group_info$group)
    if (length(unique_groups) == 2) {
      comparisons <- list(c(unique_groups[1], unique_groups[2]))
    } else if (length(unique_groups) > 2) {
      message("  - More than 2 groups detected. Specify comparisons parameter for pairwise tests")
    }
  }

  if (!is.null(comparisons)) {
    for (comp in comparisons) {
      group_a_name <- comp[1]
      group_b_name <- comp[2]

      # Get metrics for each group
      group_a_metrics <- all_metrics[group_info$group == group_a_name]
      group_b_metrics <- all_metrics[group_info$group == group_b_name]

      if (length(group_a_metrics) > 0 && length(group_b_metrics) > 0) {
        comp_result <- compare_groups(group_a_metrics, group_b_metrics,
                                     group_a_name, group_b_name,
                                     test_type = "t.test",
                                     correction = "fdr")

        comparison_results[[paste(group_a_name, "vs", group_b_name)]] <- comp_result

        # Save comparison results
        comp_file <- file.path(output_dir,
                              sprintf("comparison_%s_vs_%s.csv",
                                    group_a_name, group_b_name))
        write.csv(comp_result, comp_file, row.names = FALSE)
        message(sprintf("  - Saved comparison: %s", comp_file))
      }
    }
  }

  message("Group comparison report complete!")

  # Return result
  result <- list(
    output_dir = output_dir,
    metrics_file = metrics_file,
    comparison_files = comparison_results,
    combined_metrics = combined_metrics
  )

  class(result) <- "dlc_group_report"
  return(result)
}


# Note: compare_subjects and compare_groups functions are now in
# R/reporting/group_comparisons.R
