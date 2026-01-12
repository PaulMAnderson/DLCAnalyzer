#' EPM (Elevated Plus Maze) Analysis Functions
#'
#' Functions for analyzing EPM behavioral metrics including anxiety indices,
#' zone occupancy, and locomotor activity.
#'
#' @name epm_analysis
NULL

#' Analyze EPM behavioral metrics
#'
#' Comprehensive analysis of EPM behavior including anxiety indices, time in zones,
#' zone entries, latencies, and locomotor activity. Returns results in standard
#' format matching LD/OFT/NORT pipelines.
#'
#' @param epm_data List. EPM data structure from load_epm_data(), OR
#'                      Data frame with required columns (frame, time, x, y,
#'                      zone_open_arms, zone_closed_arms, zone_center)
#' @param fps Numeric. Frames per second (only needed if passing data frame directly)
#' @param min_exploration Numeric. Minimum total arm entries required for valid
#'                        anxiety assessment (default: 5)
#'
#' @return List with EPM behavioral metrics:
#'   \describe{
#'     \item{time_in_open_arms_sec}{Time spent in open arms (seconds)}
#'     \item{time_in_closed_arms_sec}{Time spent in closed arms (seconds)}
#'     \item{time_in_center_sec}{Time spent in center platform (seconds)}
#'     \item{pct_time_in_open}{Percentage of time in open arms}
#'     \item{pct_time_in_closed}{Percentage of time in closed arms}
#'     \item{pct_time_in_center}{Percentage of time in center}
#'     \item{open_arm_ratio}{Open arm time / (open + closed arm time) - KEY ANXIETY INDEX}
#'     \item{entries_to_open}{Number of entries into open arms}
#'     \item{entries_to_closed}{Number of entries into closed arms}
#'     \item{entries_to_center}{Number of entries into center}
#'     \item{total_arm_entries}{Total entries into any arm (open + closed)}
#'     \item{entries_ratio}{Open entries / total entries - ANXIETY INDEX}
#'     \item{latency_to_open_sec}{Time to first open arm entry (seconds)}
#'     \item{total_distance_cm}{Total distance traveled (cm)}
#'     \item{avg_velocity_cm_s}{Average velocity (cm/s)}
#'     \item{distance_in_open_cm}{Distance traveled in open arms (cm)}
#'     \item{distance_in_closed_cm}{Distance traveled in closed arms (cm)}
#'     \item{total_duration_sec}{Total trial duration (seconds)}
#'     \item{sufficient_exploration}{Logical. Met minimum exploration criterion}
#'   }
#'
#' @examples
#' \dontrun{
#' # Analyze EPM data
#' epm_data <- load_epm_data("ID7687_DLC.csv")
#' results <- analyze_epm(epm_data)
#'
#' # Check anxiety index
#' print(results$open_arm_ratio)  # Lower = higher anxiety
#'
#' # Interpret results
#' if (results$open_arm_ratio < 0.2) {
#'   print("High anxiety")
#' } else if (results$open_arm_ratio > 0.4) {
#'   print("Low anxiety")
#' }
#' }
#'
#' @export
analyze_epm <- function(epm_data, fps = NULL, min_exploration = 5) {
  # Handle different input types
  if (is.list(epm_data) && "data" %in% names(epm_data)) {
    # Full EPM data structure
    df <- epm_data$data
    fps <- epm_data$fps
  } else if (is.data.frame(epm_data)) {
    # Just the data frame
    df <- epm_data
    if (is.null(fps)) {
      stop("fps must be provided when passing a data frame directly", call. = FALSE)
    }
  } else {
    stop("epm_data must be an EPM data structure or data frame", call. = FALSE)
  }

  # Validate required columns
  required_cols <- c("frame", "time", "x", "y", "zone_open_arms",
                     "zone_closed_arms", "zone_center")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  # Calculate time in zones (using existing function from LD pipeline)
  time_in_open <- calculate_zone_time(df$zone_open_arms, fps)
  time_in_closed <- calculate_zone_time(df$zone_closed_arms, fps)
  time_in_center <- calculate_zone_time(df$zone_center, fps)
  total_duration <- max(df$time, na.rm = TRUE)

  # Calculate percentages
  pct_time_open <- (time_in_open / total_duration) * 100
  pct_time_closed <- (time_in_closed / total_duration) * 100
  pct_time_center <- (time_in_center / total_duration) * 100

  # Calculate open arm ratio (KEY anxiety index)
  open_arm_ratio <- calculate_open_arm_ratio(time_in_open, time_in_closed)

  # Calculate zone entries (using existing function from LD pipeline)
  entries_open <- detect_zone_entries(df$zone_open_arms)
  entries_closed <- detect_zone_entries(df$zone_closed_arms)
  entries_center <- detect_zone_entries(df$zone_center)
  total_arm_entries <- entries_open + entries_closed

  # Calculate entries ratio (anxiety index)
  entries_ratio <- calculate_entries_ratio(entries_open, entries_closed)

  # Calculate latency to first open arm entry (using existing function)
  latency_to_open <- calculate_zone_latency(df$zone_open_arms, fps)

  # Calculate locomotor activity
  total_distance <- calculate_total_distance(df$x, df$y)
  avg_velocity <- total_distance / total_duration

  # Calculate distance in each zone type (using existing function)
  distance_in_open <- calculate_distance_in_zone(df$x, df$y, df$zone_open_arms)
  distance_in_closed <- calculate_distance_in_zone(df$x, df$y, df$zone_closed_arms)

  # Check exploration criterion
  sufficient_exploration <- total_arm_entries >= min_exploration

  # Compile results in standard format
  results <- list(
    # Time metrics
    time_in_open_arms_sec = time_in_open,
    time_in_closed_arms_sec = time_in_closed,
    time_in_center_sec = time_in_center,
    pct_time_in_open = pct_time_open,
    pct_time_in_closed = pct_time_closed,
    pct_time_in_center = pct_time_center,

    # Anxiety indices
    open_arm_ratio = open_arm_ratio,
    entries_ratio = entries_ratio,

    # Entry counts
    entries_to_open = entries_open,
    entries_to_closed = entries_closed,
    entries_to_center = entries_center,
    total_arm_entries = total_arm_entries,

    # Latencies
    latency_to_open_sec = latency_to_open,

    # Locomotor activity
    total_distance_cm = total_distance,
    avg_velocity_cm_s = avg_velocity,
    distance_in_open_cm = distance_in_open,
    distance_in_closed_cm = distance_in_closed,

    # Trial info
    total_duration_sec = total_duration,
    sufficient_exploration = sufficient_exploration
  )

  return(results)
}


#' Calculate open arm ratio
#'
#' Primary anxiety index for EPM. Ratio of time in open arms to total time in arms.
#' Lower values indicate higher anxiety.
#'
#' Formula: time_open / (time_open + time_closed)
#'
#' @param time_open Numeric. Time spent in open arms (seconds)
#' @param time_closed Numeric. Time spent in closed arms (seconds)
#'
#' @return Numeric. Open arm ratio (0-1), or NA if never entered any arm
#'
#' @examples
#' \dontrun{
#' ratio <- calculate_open_arm_ratio(45, 135)  # 0.25 (higher anxiety)
#' ratio <- calculate_open_arm_ratio(90, 90)   # 0.50 (moderate)
#' ratio <- calculate_open_arm_ratio(120, 60)  # 0.67 (lower anxiety)
#' }
#'
#' @export
calculate_open_arm_ratio <- function(time_open, time_closed) {
  if (!is.numeric(time_open) || !is.numeric(time_closed)) {
    stop("time_open and time_closed must be numeric", call. = FALSE)
  }

  if (time_open < 0 || time_closed < 0) {
    stop("Times cannot be negative", call. = FALSE)
  }

  # Total time in arms
  total_arm_time <- time_open + time_closed

  # Handle edge case: never entered any arm
  if (total_arm_time == 0) {
    return(NA_real_)
  }

  # Calculate ratio
  ratio <- time_open / total_arm_time

  return(ratio)
}


#' Calculate entries ratio
#'
#' Secondary anxiety index for EPM. Ratio of open arm entries to total arm entries.
#' Lower values indicate higher anxiety / risk aversion.
#'
#' Formula: entries_open / (entries_open + entries_closed)
#'
#' @param entries_open Integer. Number of entries into open arms
#' @param entries_closed Integer. Number of entries into closed arms
#'
#' @return Numeric. Entries ratio (0-1), or NA if no arm entries
#'
#' @examples
#' \dontrun{
#' ratio <- calculate_entries_ratio(3, 12)  # 0.20 (higher anxiety)
#' ratio <- calculate_entries_ratio(6, 6)   # 0.50 (moderate)
#' ratio <- calculate_entries_ratio(10, 5)  # 0.67 (lower anxiety)
#' }
#'
#' @export
calculate_entries_ratio <- function(entries_open, entries_closed) {
  if (!is.numeric(entries_open) || !is.numeric(entries_closed)) {
    stop("entries_open and entries_closed must be numeric", call. = FALSE)
  }

  if (entries_open < 0 || entries_closed < 0) {
    stop("Entry counts cannot be negative", call. = FALSE)
  }

  # Total arm entries
  total_entries <- entries_open + entries_closed

  # Handle edge case: never entered any arm
  if (total_entries == 0) {
    return(NA_real_)
  }

  # Calculate ratio
  ratio <- entries_open / total_entries

  return(ratio)
}


#' Calculate total distance traveled
#'
#' Calculates cumulative distance from frame-to-frame displacement.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#'
#' @return Numeric. Total distance in same units as coordinates (typically cm)
#'
#' @keywords internal
calculate_total_distance <- function(x, y) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (length(x) < 2) {
    return(0)
  }

  # Calculate distance between consecutive points
  dx <- diff(x)
  dy <- diff(y)
  distances <- sqrt(dx^2 + dy^2)

  # Sum total distance (excluding NA)
  total_distance <- sum(distances, na.rm = TRUE)

  return(total_distance)
}


#' Analyze EPM batch data
#'
#' Process multiple EPM subjects and combine results into a single data frame.
#' Useful for comparing anxiety metrics across experimental groups.
#'
#' @param epm_data_list List of EPM data structures (from load_epm_data())
#' @param fps Numeric. Frames per second (only if passing raw data frames)
#' @param min_exploration Numeric. Minimum arm entries for valid assessment (default: 5)
#'
#' @return Data frame with one row per subject and columns for all EPM metrics
#'
#' @examples
#' \dontrun{
#' # Load multiple subjects
#' files <- list.files("data/EPM", pattern = "*.csv", full.names = TRUE)
#' epm_list <- lapply(files, load_epm_data)
#' names(epm_list) <- sapply(epm_list, function(x) x$subject_id)
#'
#' # Analyze batch
#' results_df <- analyze_epm_batch(epm_list)
#'
#' # Compare groups
#' mean(results_df$open_arm_ratio)
#' }
#'
#' @export
analyze_epm_batch <- function(epm_data_list, fps = NULL, min_exploration = 5) {
  if (!is.list(epm_data_list) || length(epm_data_list) == 0) {
    stop("epm_data_list must be a non-empty list", call. = FALSE)
  }

  # Analyze each subject
  results_list <- list()
  for (i in seq_along(epm_data_list)) {
    epm_data <- epm_data_list[[i]]

    # Get subject ID
    if (is.list(epm_data) && "subject_id" %in% names(epm_data)) {
      subject_id <- epm_data$subject_id
    } else if (!is.null(names(epm_data_list)[i])) {
      subject_id <- names(epm_data_list)[i]
    } else {
      subject_id <- paste0("Subject_", i)
    }

    # Analyze
    tryCatch({
      results <- analyze_epm(epm_data, fps = fps, min_exploration = min_exploration)
      results$subject_id <- subject_id
      results_list[[i]] <- results
    }, error = function(e) {
      warning("Failed to analyze subject ", subject_id, ": ", e$message)
      return(NULL)
    })
  }

  # Remove any failed analyses
  results_list <- results_list[!sapply(results_list, is.null)]

  if (length(results_list) == 0) {
    stop("No subjects were successfully analyzed", call. = FALSE)
  }

  # Convert to data frame
  results_df <- do.call(rbind, lapply(results_list, as.data.frame))
  rownames(results_df) <- NULL

  # Reorder columns (subject_id first)
  col_order <- c("subject_id", setdiff(names(results_df), "subject_id"))
  results_df <- results_df[, col_order]

  return(results_df)
}


#' Export EPM results to CSV
#'
#' Saves EPM analysis results to a CSV file for further analysis or reporting.
#'
#' @param results List or data frame. Results from analyze_epm() or analyze_epm_batch()
#' @param output_file Character. Path for output CSV file
#' @param append Logical. Append to existing file (default: FALSE)
#'
#' @return Invisibly returns the input results
#'
#' @examples
#' \dontrun{
#' epm_data <- load_epm_data("ID7687_DLC.csv")
#' results <- analyze_epm(epm_data)
#' export_epm_results(results, "epm_results.csv")
#'
#' # Or batch results
#' batch_results <- analyze_epm_batch(epm_list)
#' export_epm_results(batch_results, "epm_batch_results.csv")
#' }
#'
#' @export
export_epm_results <- function(results, output_file, append = FALSE) {
  if (!is.list(results) && !is.data.frame(results)) {
    stop("results must be a list or data frame", call. = FALSE)
  }

  # Convert list to data frame if needed
  if (is.list(results) && !is.data.frame(results)) {
    results_df <- as.data.frame(results)
  } else {
    results_df <- results
  }

  # Create output directory if needed
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Write CSV
  write.csv(results_df, output_file, row.names = FALSE, append = append)

  message("Results exported to: ", output_file)

  return(invisible(results))
}


#' Interpret EPM anxiety level
#'
#' Provides qualitative interpretation of anxiety based on open arm ratio.
#' Uses established EPM literature benchmarks.
#'
#' @param open_arm_ratio Numeric. Open arm ratio from analyze_epm()
#' @param entries_ratio Numeric. Entries ratio (optional, for additional context)
#' @param total_entries Integer. Total arm entries (optional, for exploration check)
#'
#' @return Character. Anxiety interpretation: "High", "Moderate-High",
#'         "Moderate", "Moderate-Low", "Low", or "Insufficient exploration"
#'
#' @details
#' Anxiety level guidelines:
#' - Open arm ratio < 0.15: High anxiety
#' - 0.15-0.25: Moderate-high anxiety
#' - 0.25-0.40: Moderate anxiety
#' - 0.40-0.55: Moderate-low anxiety
#' - > 0.55: Low anxiety
#'
#' Note: Requires minimum 5 arm entries for valid assessment.
#'
#' @examples
#' \dontrun{
#' results <- analyze_epm(epm_data)
#' anxiety <- interpret_epm_anxiety(results$open_arm_ratio,
#'                                   results$entries_ratio,
#'                                   results$total_arm_entries)
#' print(anxiety)  # e.g., "Moderate anxiety"
#' }
#'
#' @export
interpret_epm_anxiety <- function(open_arm_ratio, entries_ratio = NULL,
                                   total_entries = NULL) {
  # Check exploration criterion
  if (!is.null(total_entries) && total_entries < 5) {
    return("Insufficient exploration")
  }

  # Handle missing data
  if (is.na(open_arm_ratio)) {
    return("No arm exploration")
  }

  # Interpret based on open arm ratio (primary index)
  if (open_arm_ratio < 0.15) {
    anxiety <- "High anxiety"
  } else if (open_arm_ratio < 0.25) {
    anxiety <- "Moderate-high anxiety"
  } else if (open_arm_ratio < 0.40) {
    anxiety <- "Moderate anxiety"
  } else if (open_arm_ratio < 0.55) {
    anxiety <- "Moderate-low anxiety"
  } else {
    anxiety <- "Low anxiety"
  }

  # Add entries ratio context if provided
  if (!is.null(entries_ratio) && !is.na(entries_ratio)) {
    # If entries ratio substantially differs from time ratio, note it
    if (abs(open_arm_ratio - entries_ratio) > 0.15) {
      if (entries_ratio < open_arm_ratio) {
        anxiety <- paste0(anxiety, " (fewer entries than time suggests)")
      } else {
        anxiety <- paste0(anxiety, " (more entries than time suggests)")
      }
    }
  }

  return(anxiety)
}


#' Print EPM results summary
#'
#' Formatted console output of EPM analysis results.
#'
#' @param results List. Results from analyze_epm()
#' @param subject_id Character. Subject identifier (optional)
#'
#' @return Invisibly returns input results
#'
#' @examples
#' \dontrun{
#' epm_data <- load_epm_data("ID7687_DLC.csv")
#' results <- analyze_epm(epm_data)
#' print_epm_results(results, subject_id = "ID7687")
#' }
#'
#' @export
print_epm_results <- function(results, subject_id = NULL) {
  if (!is.list(results)) {
    stop("results must be a list from analyze_epm()", call. = FALSE)
  }

  cat("\n=== EPM Analysis Results ===\n")
  if (!is.null(subject_id)) {
    cat("Subject:", subject_id, "\n")
  }
  cat("\n")

  # Anxiety indices (primary metrics)
  cat("ANXIETY INDICES:\n")
  cat(sprintf("  Open Arm Ratio:    %.3f", results$open_arm_ratio))
  anxiety_level <- interpret_epm_anxiety(results$open_arm_ratio,
                                          results$entries_ratio,
                                          results$total_arm_entries)
  cat(sprintf(" (%s)\n", anxiety_level))
  cat(sprintf("  Entries Ratio:     %.3f\n", results$entries_ratio))
  cat("\n")

  # Time metrics
  cat("TIME IN ZONES:\n")
  cat(sprintf("  Open arms:     %6.1f sec (%5.1f%%)\n",
              results$time_in_open_arms_sec, results$pct_time_in_open))
  cat(sprintf("  Closed arms:   %6.1f sec (%5.1f%%)\n",
              results$time_in_closed_arms_sec, results$pct_time_in_closed))
  cat(sprintf("  Center:        %6.1f sec (%5.1f%%)\n",
              results$time_in_center_sec, results$pct_time_in_center))
  cat("\n")

  # Entry metrics
  cat("ARM ENTRIES:\n")
  cat(sprintf("  Open arms:     %3d\n", results$entries_to_open))
  cat(sprintf("  Closed arms:   %3d\n", results$entries_to_closed))
  cat(sprintf("  Center:        %3d\n", results$entries_to_center))
  cat(sprintf("  Total entries: %3d", results$total_arm_entries))
  if (!results$sufficient_exploration) {
    cat(" (LOW - results may not be reliable)")
  }
  cat("\n\n")

  # Latencies
  cat("LATENCIES:\n")
  if (!is.na(results$latency_to_open_sec)) {
    cat(sprintf("  First open arm entry: %.1f sec\n", results$latency_to_open_sec))
  } else {
    cat("  First open arm entry: Never entered\n")
  }
  cat("\n")

  # Locomotor activity
  cat("LOCOMOTOR ACTIVITY:\n")
  cat(sprintf("  Total distance:       %.1f cm\n", results$total_distance_cm))
  cat(sprintf("  Average velocity:     %.2f cm/s\n", results$avg_velocity_cm_s))
  cat(sprintf("  Distance in open:     %.1f cm\n", results$distance_in_open_cm))
  cat(sprintf("  Distance in closed:   %.1f cm\n", results$distance_in_closed_cm))
  cat("\n")

  # Trial info
  cat(sprintf("Total duration: %.1f sec\n", results$total_duration_sec))
  cat("\n")

  return(invisible(results))
}
