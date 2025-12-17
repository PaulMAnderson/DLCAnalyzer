#' Quality Check Functions for DLCAnalyzer
#'
#' This file contains functions for assessing tracking data quality including
#' overall quality metrics, outlier detection, missing data analysis, and
#' movement anomaly detection.
#'
#' @name quality_checks
NULL

#' Check overall tracking quality
#'
#' Performs a comprehensive quality assessment of tracking data, including
#' likelihood statistics, missing data analysis, and frame coverage.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param body_parts Optional character vector specifying which body parts to analyze.
#'   If NULL (default), all body parts are analyzed.
#'
#' @return A list containing quality metrics:
#'   \describe{
#'     \item{overall}{List with total_frames, body_parts, fps, duration_seconds}
#'     \item{likelihood}{Data frame with likelihood statistics per body part}
#'     \item{missing_data}{Data frame with missing data counts and percentages}
#'     \item{recommendations}{Character vector of suggested actions}
#'   }
#'
#' @details
#' The function provides a comprehensive overview of data quality including:
#' \itemize{
#'   \item Likelihood distribution (mean, median, min, quartiles) per body part
#'   \item Missing data counts and percentages
#'   \item Frame coverage statistics
#'   \item Actionable recommendations based on quality metrics
#' }
#'
#' Recommendations are generated when:
#' \itemize{
#'   \item Mean likelihood < 0.9: Suggests filtering threshold
#'   \item Missing data > 10%: Suggests interpolation
#'   \item Missing data > 30%: Warns about data quality
#' }
#'
#' @examples
#' \dontrun{
#' # Check quality of all body parts
#' quality <- check_tracking_quality(tracking_data)
#' print(quality$likelihood)
#' print(quality$recommendations)
#'
#' # Check quality of specific body parts
#' quality <- check_tracking_quality(
#'   tracking_data,
#'   body_parts = c("nose", "tail_base")
#' )
#' }
#'
#' @seealso \code{\link{detect_outliers}}, \code{\link{calculate_missing_data_summary}},
#'   \code{\link{flag_suspicious_jumps}}
#'
#' @export
check_tracking_quality <- function(tracking_data, body_parts = NULL) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  # Determine which body parts to process
  available_parts <- unique(tracking_data$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_analyze <- available_parts
  } else {
    # Validate requested body parts exist
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found in the data and will be ignored: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_analyze <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_analyze) == 0) {
    warning("No valid body parts to analyze")
    # Return empty quality report
    return(list(
      overall = list(
        total_frames = 0,
        body_parts = character(0),
        fps = tracking_data$metadata$fps,
        duration_seconds = 0
      ),
      likelihood = data.frame(
        body_part = character(),
        mean_likelihood = numeric(),
        median_likelihood = numeric(),
        min_likelihood = numeric(),
        q25 = numeric(),
        q75 = numeric(),
        stringsAsFactors = FALSE
      ),
      missing_data = data.frame(
        body_part = character(),
        n_missing = integer(),
        pct_missing = numeric(),
        stringsAsFactors = FALSE
      ),
      recommendations = character(0)
    ))
  }

  # Overall statistics
  total_frames <- max(tracking_data$tracking$frame)
  fps <- tracking_data$metadata$fps
  duration <- total_frames / fps

  overall <- list(
    total_frames = total_frames,
    body_parts = parts_to_analyze,
    fps = fps,
    duration_seconds = duration
  )

  # Likelihood statistics per body part
  likelihood_stats <- data.frame(
    body_part = character(),
    mean_likelihood = numeric(),
    median_likelihood = numeric(),
    min_likelihood = numeric(),
    q25 = numeric(),
    q75 = numeric(),
    stringsAsFactors = FALSE
  )

  # Missing data statistics per body part
  missing_stats <- data.frame(
    body_part = character(),
    n_missing = integer(),
    pct_missing = numeric(),
    stringsAsFactors = FALSE
  )

  # Calculate statistics for each body part
  for (part in parts_to_analyze) {
    part_data <- tracking_data$tracking[tracking_data$tracking$body_part == part, ]

    # Likelihood statistics (if likelihood column exists)
    if ("likelihood" %in% names(part_data)) {
      likelihood_values <- part_data$likelihood[!is.na(part_data$likelihood)]

      if (length(likelihood_values) > 0) {
        likelihood_stats <- rbind(likelihood_stats, data.frame(
          body_part = part,
          mean_likelihood = mean(likelihood_values, na.rm = TRUE),
          median_likelihood = median(likelihood_values, na.rm = TRUE),
          min_likelihood = min(likelihood_values, na.rm = TRUE),
          q25 = quantile(likelihood_values, 0.25, na.rm = TRUE),
          q75 = quantile(likelihood_values, 0.75, na.rm = TRUE),
          stringsAsFactors = FALSE
        ))
      }
    }

    # Missing data statistics
    n_missing <- sum(is.na(part_data$x) | is.na(part_data$y))
    pct_missing <- (n_missing / nrow(part_data)) * 100

    missing_stats <- rbind(missing_stats, data.frame(
      body_part = part,
      n_missing = n_missing,
      pct_missing = pct_missing,
      stringsAsFactors = FALSE
    ))
  }

  # Generate recommendations
  recommendations <- character(0)

  # Check likelihood quality
  if (nrow(likelihood_stats) > 0) {
    low_likelihood_parts <- likelihood_stats$body_part[likelihood_stats$mean_likelihood < 0.9]
    if (length(low_likelihood_parts) > 0) {
      recommendations <- c(recommendations,
                          sprintf("Consider filtering low confidence points for: %s (mean likelihood < 0.9)",
                                paste(low_likelihood_parts, collapse = ", ")))
    }

    min_mean_likelihood <- min(likelihood_stats$mean_likelihood)
    if (min_mean_likelihood < 0.9) {
      recommendations <- c(recommendations,
                          sprintf("Suggested filter threshold: %.2f (based on lowest mean likelihood)",
                                min_mean_likelihood + 0.05))
    }
  }

  # Check missing data
  high_missing_parts <- missing_stats$body_part[missing_stats$pct_missing > 10 &
                                                  missing_stats$pct_missing <= 30]
  if (length(high_missing_parts) > 0) {
    recommendations <- c(recommendations,
                        sprintf("Consider interpolation for: %s (>10%% missing data)",
                              paste(high_missing_parts, collapse = ", ")))
  }

  very_high_missing_parts <- missing_stats$body_part[missing_stats$pct_missing > 30]
  if (length(very_high_missing_parts) > 0) {
    recommendations <- c(recommendations,
                        sprintf("WARNING: High missing data for: %s (>30%% missing). Data quality may be poor.",
                              paste(very_high_missing_parts, collapse = ", ")))
  }

  # Return quality report
  result <- list(
    overall = overall,
    likelihood = likelihood_stats,
    missing_data = missing_stats,
    recommendations = recommendations
  )

  class(result) <- c("quality_report", "list")
  return(result)
}

#' Detect outliers in tracking data
#'
#' Identifies outlier points in x and y coordinates using statistical methods.
#' Outliers may indicate tracking errors or unusual movements that require
#' manual inspection or correction.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param method Character string specifying the outlier detection method.
#'   Options: "iqr" (Interquartile Range), "zscore" (Z-score), "mad" (Median Absolute Deviation).
#'   Default is "iqr".
#' @param threshold Numeric threshold for outlier detection:
#'   \itemize{
#'     \item For "iqr": multiplier for IQR (default 1.5)
#'     \item For "zscore": number of standard deviations (default 3)
#'     \item For "mad": number of MADs (default 3.5)
#'   }
#' @param body_parts Optional character vector specifying which body parts to analyze.
#'   If NULL (default), all body parts are analyzed.
#'
#' @return A data frame with the same structure as tracking_data$tracking,
#'   plus an additional 'is_outlier' logical column indicating outlier points.
#'
#' @details
#' Three outlier detection methods are available:
#'
#' \strong{IQR (Interquartile Range)}:
#' \itemize{
#'   \item Values outside [Q1 - threshold*IQR, Q3 + threshold*IQR] are outliers
#'   \item Default threshold: 1.5 (standard Tukey's fences)
#'   \item Good for skewed distributions
#' }
#'
#' \strong{Z-Score}:
#' \itemize{
#'   \item Values with |z-score| > threshold are outliers
#'   \item Default threshold: 3 (3 standard deviations)
#'   \item Assumes normal distribution
#' }
#'
#' \strong{MAD (Median Absolute Deviation)}:
#' \itemize{
#'   \item Values with |x - median| / MAD > threshold are outliers
#'   \item Default threshold: 3.5
#'   \item Robust to outliers in the detection process
#' }
#'
#' Outliers are detected separately for x and y coordinates. A point is flagged
#' as an outlier if either coordinate is beyond the threshold.
#'
#' @examples
#' \dontrun{
#' # Detect outliers using IQR method
#' outliers <- detect_outliers(tracking_data, method = "iqr", threshold = 1.5)
#' table(outliers$is_outlier)
#'
#' # Use z-score method with stricter threshold
#' outliers <- detect_outliers(tracking_data, method = "zscore", threshold = 2.5)
#'
#' # Detect outliers for specific body parts using MAD
#' outliers <- detect_outliers(
#'   tracking_data,
#'   method = "mad",
#'   body_parts = c("nose", "tail_base")
#' )
#' }
#'
#' @seealso \code{\link{check_tracking_quality}}, \code{\link{flag_suspicious_jumps}}
#'
#' @export
detect_outliers <- function(tracking_data, method = "iqr", threshold = NULL,
                           body_parts = NULL) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  # Validate method
  valid_methods <- c("iqr", "zscore", "mad")
  if (!method %in% valid_methods) {
    stop("method must be one of: ", paste(valid_methods, collapse = ", "))
  }

  # Set default thresholds based on method
  if (is.null(threshold)) {
    threshold <- switch(method,
                       "iqr" = 1.5,
                       "zscore" = 3,
                       "mad" = 3.5)
  }

  if (!is.numeric(threshold) || threshold <= 0) {
    stop("threshold must be a positive numeric value")
  }

  # Determine which body parts to process
  available_parts <- unique(tracking_data$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_analyze <- available_parts
  } else {
    # Validate requested body parts exist
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found in the data and will be ignored: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_analyze <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_analyze) == 0) {
    stop("No valid body parts to analyze")
  }

  # Create result data frame
  result <- tracking_data$tracking
  result$is_outlier <- FALSE

  # Detect outliers for each body part
  for (part in parts_to_analyze) {
    part_idx <- result$body_part == part
    part_data <- result[part_idx, ]

    # Get non-missing coordinates
    valid_idx <- !is.na(part_data$x) & !is.na(part_data$y)

    if (sum(valid_idx) == 0) {
      next  # Skip if no valid data
    }

    x_values <- part_data$x[valid_idx]
    y_values <- part_data$y[valid_idx]

    # Detect outliers based on method
    if (method == "iqr") {
      # IQR method
      x_outliers <- detect_outliers_iqr(x_values, threshold)
      y_outliers <- detect_outliers_iqr(y_values, threshold)
    } else if (method == "zscore") {
      # Z-score method
      x_outliers <- detect_outliers_zscore(x_values, threshold)
      y_outliers <- detect_outliers_zscore(y_values, threshold)
    } else if (method == "mad") {
      # MAD method
      x_outliers <- detect_outliers_mad(x_values, threshold)
      y_outliers <- detect_outliers_mad(y_values, threshold)
    }

    # Combine x and y outliers (outlier if either coordinate is outlier)
    is_outlier_valid <- x_outliers | y_outliers

    # Map back to original indices
    is_outlier_all <- logical(sum(part_idx))
    is_outlier_all[valid_idx] <- is_outlier_valid

    # Update result
    result$is_outlier[part_idx] <- is_outlier_all
  }

  return(result)
}

#' Detect outliers using IQR method
#'
#' @param values Numeric vector of values
#' @param threshold IQR multiplier (default 1.5)
#' @return Logical vector indicating outliers
#' @keywords internal
detect_outliers_iqr <- function(values, threshold = 1.5) {
  q1 <- quantile(values, 0.25, na.rm = TRUE)
  q3 <- quantile(values, 0.75, na.rm = TRUE)
  iqr <- q3 - q1

  lower_bound <- q1 - threshold * iqr
  upper_bound <- q3 + threshold * iqr

  return(values < lower_bound | values > upper_bound)
}

#' Detect outliers using Z-score method
#'
#' @param values Numeric vector of values
#' @param threshold Z-score threshold (default 3)
#' @return Logical vector indicating outliers
#' @keywords internal
detect_outliers_zscore <- function(values, threshold = 3) {
  mean_val <- mean(values, na.rm = TRUE)
  sd_val <- sd(values, na.rm = TRUE)

  if (sd_val == 0) {
    return(rep(FALSE, length(values)))
  }

  z_scores <- abs((values - mean_val) / sd_val)
  return(z_scores > threshold)
}

#' Detect outliers using MAD method
#'
#' @param values Numeric vector of values
#' @param threshold MAD multiplier (default 3.5)
#' @return Logical vector indicating outliers
#' @keywords internal
detect_outliers_mad <- function(values, threshold = 3.5) {
  median_val <- median(values, na.rm = TRUE)
  mad_val <- mad(values, na.rm = TRUE)

  if (mad_val == 0) {
    return(rep(FALSE, length(values)))
  }

  deviations <- abs((values - median_val) / mad_val)
  return(deviations > threshold)
}

#' Calculate detailed missing data summary
#'
#' Provides comprehensive statistics about missing data patterns including
#' per-body-part percentages, gap length distributions, and temporal patterns.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param body_parts Optional character vector specifying which body parts to analyze.
#'   If NULL (default), all body parts are analyzed.
#'
#' @return A list containing:
#'   \describe{
#'     \item{summary}{Data frame with per-body-part missing data statistics}
#'     \item{gap_distribution}{Data frame with gap length frequency distribution}
#'     \item{longest_gaps}{Data frame with longest gap per body part}
#'   }
#'
#' @details
#' The function analyzes missing data (NA values in x or y coordinates) and provides:
#' \itemize{
#'   \item Per-body-part missing data counts and percentages
#'   \item Distribution of gap lengths (consecutive missing frames)
#'   \item Longest gap for each body part with start and end frames
#' }
#'
#' A "gap" is defined as a consecutive sequence of missing data points.
#' Gap statistics help determine appropriate interpolation parameters
#' (e.g., max_gap in interpolate_missing()).
#'
#' @examples
#' \dontrun{
#' # Analyze missing data for all body parts
#' missing_info <- calculate_missing_data_summary(tracking_data)
#' print(missing_info$summary)
#' print(missing_info$gap_distribution)
#' print(missing_info$longest_gaps)
#'
#' # Analyze specific body parts
#' missing_info <- calculate_missing_data_summary(
#'   tracking_data,
#'   body_parts = c("nose", "tail_base")
#' )
#' }
#'
#' @seealso \code{\link{check_tracking_quality}}, \code{\link{interpolate_missing}}
#'
#' @export
calculate_missing_data_summary <- function(tracking_data, body_parts = NULL) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  # Determine which body parts to process
  available_parts <- unique(tracking_data$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_analyze <- available_parts
  } else {
    # Validate requested body parts exist
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found in the data and will be ignored: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_analyze <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_analyze) == 0) {
    warning("No valid body parts to analyze")
    # Return empty summary
    return(list(
      summary = data.frame(
        body_part = character(),
        total_points = integer(),
        n_missing = integer(),
        pct_missing = numeric(),
        n_gaps = integer(),
        mean_gap_length = numeric(),
        stringsAsFactors = FALSE
      ),
      gap_distribution = data.frame(
        gap_length = integer(),
        frequency = integer(),
        stringsAsFactors = FALSE
      ),
      longest_gaps = data.frame(
        body_part = character(),
        gap_length = integer(),
        start_frame = integer(),
        end_frame = integer(),
        stringsAsFactors = FALSE
      )
    ))
  }

  # Initialize result structures
  summary_df <- data.frame(
    body_part = character(),
    total_points = integer(),
    n_missing = integer(),
    pct_missing = numeric(),
    n_gaps = integer(),
    mean_gap_length = numeric(),
    stringsAsFactors = FALSE
  )

  gap_dist_df <- data.frame(
    gap_length = integer(),
    frequency = integer(),
    stringsAsFactors = FALSE
  )

  longest_gaps_df <- data.frame(
    body_part = character(),
    gap_length = integer(),
    start_frame = integer(),
    end_frame = integer(),
    stringsAsFactors = FALSE
  )

  all_gap_lengths <- integer(0)

  # Analyze each body part
  for (part in parts_to_analyze) {
    part_data <- tracking_data$tracking[tracking_data$tracking$body_part == part, ]

    # Identify missing points
    is_missing <- is.na(part_data$x) | is.na(part_data$y)
    n_missing <- sum(is_missing)
    n_total <- nrow(part_data)
    pct_missing <- (n_missing / n_total) * 100

    # Calculate gap statistics
    gap_info <- calculate_gaps(is_missing)

    # Add to summary
    summary_df <- rbind(summary_df, data.frame(
      body_part = part,
      total_points = n_total,
      n_missing = n_missing,
      pct_missing = pct_missing,
      n_gaps = gap_info$n_gaps,
      mean_gap_length = gap_info$mean_gap_length,
      stringsAsFactors = FALSE
    ))

    # Track all gap lengths for distribution
    if (length(gap_info$gap_lengths) > 0) {
      all_gap_lengths <- c(all_gap_lengths, gap_info$gap_lengths)
    }

    # Find longest gap
    if (gap_info$n_gaps > 0) {
      longest_idx <- which.max(gap_info$gap_lengths)
      longest_gaps_df <- rbind(longest_gaps_df, data.frame(
        body_part = part,
        gap_length = gap_info$gap_lengths[longest_idx],
        start_frame = part_data$frame[gap_info$gap_starts[longest_idx]],
        end_frame = part_data$frame[gap_info$gap_ends[longest_idx]],
        stringsAsFactors = FALSE
      ))
    }
  }

  # Create gap distribution (histogram bins)
  if (length(all_gap_lengths) > 0) {
    gap_table <- table(all_gap_lengths)
    gap_dist_df <- data.frame(
      gap_length = as.integer(names(gap_table)),
      frequency = as.integer(gap_table),
      stringsAsFactors = FALSE
    )
    gap_dist_df <- gap_dist_df[order(gap_dist_df$gap_length), ]
  }

  # Return results
  result <- list(
    summary = summary_df,
    gap_distribution = gap_dist_df,
    longest_gaps = longest_gaps_df
  )

  class(result) <- c("missing_data_summary", "list")
  return(result)
}

#' Calculate gap statistics from logical vector
#'
#' @param is_missing Logical vector indicating missing data
#' @return List with gap statistics
#' @keywords internal
calculate_gaps <- function(is_missing) {
  if (sum(is_missing) == 0) {
    return(list(
      n_gaps = 0,
      mean_gap_length = 0,
      gap_lengths = integer(0),
      gap_starts = integer(0),
      gap_ends = integer(0)
    ))
  }

  # Use run length encoding to find consecutive gaps
  rle_result <- rle(is_missing)

  # Find indices where value is TRUE (missing)
  gap_indices <- which(rle_result$values)

  if (length(gap_indices) == 0) {
    return(list(
      n_gaps = 0,
      mean_gap_length = 0,
      gap_lengths = integer(0),
      gap_starts = integer(0),
      gap_ends = integer(0)
    ))
  }

  # Get gap lengths
  gap_lengths <- rle_result$lengths[gap_indices]

  # Calculate start and end positions
  cumsum_lengths <- cumsum(rle_result$lengths)
  gap_ends <- cumsum_lengths[gap_indices]
  gap_starts <- gap_ends - gap_lengths + 1

  return(list(
    n_gaps = length(gap_lengths),
    mean_gap_length = mean(gap_lengths),
    gap_lengths = gap_lengths,
    gap_starts = gap_starts,
    gap_ends = gap_ends
  ))
}

#' Flag suspicious jumps in trajectory
#'
#' Detects implausible frame-to-frame displacements that may indicate tracking
#' errors or very rapid movements requiring manual inspection.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param max_displacement Numeric value specifying the maximum plausible displacement
#'   in pixels between consecutive frames. If NULL (default), automatically calculated
#'   as the 99th percentile of observed displacements.
#' @param body_parts Optional character vector specifying which body parts to analyze.
#'   If NULL (default), all body parts are analyzed.
#'
#' @return A data frame with the same structure as tracking_data$tracking,
#'   plus additional columns:
#'   \describe{
#'     \item{displacement}{Frame-to-frame Euclidean distance}
#'     \item{is_suspicious_jump}{Logical indicating suspicious jumps}
#'   }
#'
#' @details
#' The function calculates Euclidean distance between consecutive frames:
#' \deqn{displacement = \sqrt{(x_i - x_{i-1})^2 + (y_i - y_{i-1})^2}}
#'
#' If max_displacement is not provided, it is automatically set to the 99th percentile
#' of all observed displacements. This adaptive threshold works well for most datasets
#' but can be overridden if you have domain knowledge about plausible movement speeds.
#'
#' Suspicious jumps may indicate:
#' \itemize{
#'   \item Tracking errors (body part swaps)
#'   \item Occlusions followed by reappearance
#'   \item Very rapid movements (e.g., startle responses)
#' }
#'
#' The first frame of each body part's trajectory is never flagged as suspicious
#' (displacement is NA).
#'
#' @examples
#' \dontrun{
#' # Auto-detect suspicious jumps
#' jumps <- flag_suspicious_jumps(tracking_data)
#' sum(jumps$is_suspicious_jump, na.rm = TRUE)
#'
#' # Use custom threshold (50 pixels)
#' jumps <- flag_suspicious_jumps(tracking_data, max_displacement = 50)
#'
#' # Analyze specific body parts
#' jumps <- flag_suspicious_jumps(
#'   tracking_data,
#'   max_displacement = 100,
#'   body_parts = c("nose", "tail_base")
#' )
#'
#' # View flagged frames
#' flagged <- jumps[jumps$is_suspicious_jump %in% TRUE, ]
#' print(flagged[, c("frame", "body_part", "displacement")])
#' }
#'
#' @seealso \code{\link{detect_outliers}}, \code{\link{check_tracking_quality}}
#'
#' @export
flag_suspicious_jumps <- function(tracking_data, max_displacement = NULL,
                                 body_parts = NULL) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  # Determine which body parts to process
  available_parts <- unique(tracking_data$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_analyze <- available_parts
  } else {
    # Validate requested body parts exist
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found in the data and will be ignored: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_analyze <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_analyze) == 0) {
    stop("No valid body parts to analyze")
  }

  # Create result data frame
  result <- tracking_data$tracking
  result$displacement <- NA_real_
  result$is_suspicious_jump <- FALSE

  # Calculate displacements for all parts to get threshold if needed
  all_displacements <- numeric(0)

  for (part in parts_to_analyze) {
    part_idx <- result$body_part == part
    part_data <- result[part_idx, ]

    # Calculate frame-to-frame displacement
    n_points <- nrow(part_data)
    displacement <- rep(NA_real_, n_points)

    for (i in 2:n_points) {
      if (!is.na(part_data$x[i]) && !is.na(part_data$y[i]) &&
          !is.na(part_data$x[i-1]) && !is.na(part_data$y[i-1])) {
        dx <- part_data$x[i] - part_data$x[i-1]
        dy <- part_data$y[i] - part_data$y[i-1]
        displacement[i] <- sqrt(dx^2 + dy^2)
      }
    }

    # Store displacement
    result$displacement[part_idx] <- displacement

    # Collect for threshold calculation
    all_displacements <- c(all_displacements, displacement[!is.na(displacement)])
  }

  # Determine threshold
  if (is.null(max_displacement)) {
    if (length(all_displacements) == 0) {
      warning("No valid displacements found; cannot auto-calculate threshold")
      return(result)
    }
    max_displacement <- quantile(all_displacements, 0.99, na.rm = TRUE)
  } else {
    if (!is.numeric(max_displacement) || max_displacement <= 0) {
      stop("max_displacement must be a positive numeric value")
    }
  }

  # Flag suspicious jumps
  for (part in parts_to_analyze) {
    part_idx <- result$body_part == part
    displacement <- result$displacement[part_idx]

    is_suspicious <- !is.na(displacement) & displacement > max_displacement
    result$is_suspicious_jump[part_idx] <- is_suspicious
  }

  # Add threshold as attribute
  attr(result, "max_displacement") <- max_displacement

  return(result)
}

#' Generate comprehensive quality report
#'
#' Combines all quality check functions into a single comprehensive report
#' with actionable recommendations for preprocessing.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param output_format Character string specifying output format.
#'   Options: "text" (human-readable), "list" (structured data).
#'   Default is "text".
#'
#' @return If output_format = "text", returns a character vector with formatted report.
#'   If output_format = "list", returns a list with all quality metrics.
#'
#' @details
#' The comprehensive report includes:
#' \itemize{
#'   \item Overall quality metrics (check_tracking_quality)
#'   \item Outlier detection results (detect_outliers with IQR method)
#'   \item Missing data analysis (calculate_missing_data_summary)
#'   \item Suspicious jump detection (flag_suspicious_jumps)
#'   \item Prioritized recommendations for preprocessing
#' }
#'
#' @examples
#' \dontrun{
#' # Generate text report
#' report <- generate_quality_report(tracking_data, output_format = "text")
#' cat(report, sep = "\n")
#'
#' # Generate structured data report
#' report <- generate_quality_report(tracking_data, output_format = "list")
#' print(report$quality$recommendations)
#' print(report$missing_data$summary)
#' }
#'
#' @seealso \code{\link{check_tracking_quality}}, \code{\link{detect_outliers}},
#'   \code{\link{calculate_missing_data_summary}}, \code{\link{flag_suspicious_jumps}}
#'
#' @export
generate_quality_report <- function(tracking_data, output_format = "text") {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  if (!output_format %in% c("text", "list")) {
    stop("output_format must be either 'text' or 'list'")
  }

  # Run all quality checks
  quality <- check_tracking_quality(tracking_data)
  outliers <- detect_outliers(tracking_data, method = "iqr", threshold = 1.5)
  missing <- calculate_missing_data_summary(tracking_data)
  jumps <- flag_suspicious_jumps(tracking_data)

  # Count issues
  n_outliers <- sum(outliers$is_outlier, na.rm = TRUE)
  n_jumps <- sum(jumps$is_suspicious_jump, na.rm = TRUE)
  max_displacement <- attr(jumps, "max_displacement")

  if (output_format == "list") {
    # Return structured data
    return(list(
      quality = quality,
      outliers = list(
        data = outliers,
        n_outliers = n_outliers
      ),
      missing_data = missing,
      jumps = list(
        data = jumps,
        n_suspicious_jumps = n_jumps,
        threshold = max_displacement
      )
    ))
  } else {
    # Generate text report
    report <- character(0)

    # Header
    report <- c(report, "=" %R% 70)
    report <- c(report, "TRACKING DATA QUALITY REPORT")
    report <- c(report, "=" %R% 70)
    report <- c(report, "")

    # Overall statistics
    report <- c(report, "OVERALL STATISTICS")
    report <- c(report, "-" %R% 70)
    report <- c(report, sprintf("Total frames: %d", quality$overall$total_frames))
    report <- c(report, sprintf("Duration: %.2f seconds (%.1f fps)",
                               quality$overall$duration_seconds,
                               quality$overall$fps))
    report <- c(report, sprintf("Body parts: %s",
                               paste(quality$overall$body_parts, collapse = ", ")))
    report <- c(report, "")

    # Likelihood statistics
    if (nrow(quality$likelihood) > 0) {
      report <- c(report, "LIKELIHOOD STATISTICS")
      report <- c(report, "-" %R% 70)
      for (i in 1:nrow(quality$likelihood)) {
        row <- quality$likelihood[i, ]
        report <- c(report, sprintf(
          "  %s: mean=%.3f, median=%.3f, min=%.3f, Q25=%.3f, Q75=%.3f",
          row$body_part, row$mean_likelihood, row$median_likelihood,
          row$min_likelihood, row$q25, row$q75
        ))
      }
      report <- c(report, "")
    }

    # Missing data
    report <- c(report, "MISSING DATA")
    report <- c(report, "-" %R% 70)
    for (i in 1:nrow(quality$missing_data)) {
      row <- quality$missing_data[i, ]
      report <- c(report, sprintf(
        "  %s: %d missing (%.1f%%)",
        row$body_part, row$n_missing, row$pct_missing
      ))
    }

    if (nrow(missing$longest_gaps) > 0) {
      report <- c(report, "")
      report <- c(report, "  Longest gaps:")
      for (i in 1:nrow(missing$longest_gaps)) {
        row <- missing$longest_gaps[i, ]
        report <- c(report, sprintf(
          "    %s: %d frames (frames %d-%d)",
          row$body_part, row$gap_length, row$start_frame, row$end_frame
        ))
      }
    }
    report <- c(report, "")

    # Outliers
    report <- c(report, "OUTLIER DETECTION (IQR method)")
    report <- c(report, "-" %R% 70)
    report <- c(report, sprintf("Total outliers detected: %d", n_outliers))

    outlier_summary <- aggregate(is_outlier ~ body_part, data = outliers, FUN = sum)
    for (i in 1:nrow(outlier_summary)) {
      report <- c(report, sprintf(
        "  %s: %d outliers",
        outlier_summary$body_part[i], outlier_summary$is_outlier[i]
      ))
    }
    report <- c(report, "")

    # Suspicious jumps
    report <- c(report, "SUSPICIOUS JUMPS")
    report <- c(report, "-" %R% 70)
    report <- c(report, sprintf("Auto-calculated threshold: %.2f pixels", max_displacement))
    report <- c(report, sprintf("Total suspicious jumps: %d", n_jumps))

    if (n_jumps > 0) {
      jump_summary <- aggregate(is_suspicious_jump ~ body_part, data = jumps, FUN = sum)
      for (i in 1:nrow(jump_summary)) {
        report <- c(report, sprintf(
          "  %s: %d jumps",
          jump_summary$body_part[i], jump_summary$is_suspicious_jump[i]
        ))
      }
    }
    report <- c(report, "")

    # Recommendations
    if (length(quality$recommendations) > 0) {
      report <- c(report, "RECOMMENDATIONS")
      report <- c(report, "-" %R% 70)
      for (rec in quality$recommendations) {
        report <- c(report, paste0("  * ", rec))
      }
      report <- c(report, "")
    }

    # Footer
    report <- c(report, "=" %R% 70)

    return(report)
  }
}

#' Helper function to repeat string
#' @keywords internal
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}

#' Print method for quality_report objects
#'
#' @param x A quality_report object
#' @param ... Additional arguments (ignored)
#' @export
print.quality_report <- function(x, ...) {
  cat("Quality Report\n")
  cat("==============\n\n")

  cat("Overall:\n")
  cat(sprintf("  Frames: %d (%.1f sec @ %.1f fps)\n",
              x$overall$total_frames,
              x$overall$duration_seconds,
              x$overall$fps))
  cat(sprintf("  Body parts: %s\n",
              paste(x$overall$body_parts, collapse = ", ")))
  cat("\n")

  if (nrow(x$likelihood) > 0) {
    cat("Likelihood Statistics:\n")
    print(x$likelihood, row.names = FALSE)
    cat("\n")
  }

  cat("Missing Data:\n")
  print(x$missing_data, row.names = FALSE)
  cat("\n")

  if (length(x$recommendations) > 0) {
    cat("Recommendations:\n")
    for (rec in x$recommendations) {
      cat(sprintf("  * %s\n", rec))
    }
  }

  invisible(x)
}

#' Print method for missing_data_summary objects
#'
#' @param x A missing_data_summary object
#' @param ... Additional arguments (ignored)
#' @export
print.missing_data_summary <- function(x, ...) {
  cat("Missing Data Summary\n")
  cat("====================\n\n")

  cat("Per-body-part statistics:\n")
  print(x$summary, row.names = FALSE)
  cat("\n")

  if (nrow(x$gap_distribution) > 0) {
    cat("Gap length distribution:\n")
    print(head(x$gap_distribution, 10), row.names = FALSE)
    if (nrow(x$gap_distribution) > 10) {
      cat(sprintf("  ... and %d more gap lengths\n",
                  nrow(x$gap_distribution) - 10))
    }
    cat("\n")
  }

  if (nrow(x$longest_gaps) > 0) {
    cat("Longest gaps:\n")
    print(x$longest_gaps, row.names = FALSE)
  }

  invisible(x)
}
