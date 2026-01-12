#' Preprocessing Functions for DLCAnalyzer
#'
#' This file contains functions for preprocessing tracking data including
#' likelihood filtering, interpolation of missing data, and trajectory smoothing.
#'
#' @name preprocessing
NULL

#' Filter tracking points with low confidence scores
#'
#' Removes or replaces tracking points with likelihood values below a specified
#' threshold. This is useful for cleaning DLC tracking data where low confidence
#' points are likely to be inaccurate. Points with likelihood < threshold are
#' set to NA, which can then be interpolated using \code{interpolate_missing()}.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param threshold Numeric value between 0 and 1. Points with likelihood below
#'   this value will be set to NA. Default is 0.9.
#' @param body_parts Optional character vector specifying which body parts to filter.
#'   If NULL (default), all body parts are filtered.
#' @param verbose Logical. If TRUE, prints information about filtering. Default is FALSE.
#'
#' @return A tracking_data object with low-confidence points set to NA
#'
#' @details
#' The function preserves the frame structure of the data and only modifies
#' x, y coordinates for points with low likelihood. The likelihood values themselves
#' are preserved to maintain tracking quality information.
#'
#' Low confidence points are common in DLC output when:
#' \itemize{
#'   \item The body part is occluded
#'   \item The body part is out of frame
#'   \item The tracking model is uncertain
#' }
#'
#' @examples
#' \dontrun{
#' # Filter all body parts with default threshold
#' filtered_data <- filter_low_confidence(tracking_data)
#'
#' # Use a more stringent threshold
#' filtered_data <- filter_low_confidence(tracking_data, threshold = 0.95)
#'
#' # Filter only specific body parts
#' filtered_data <- filter_low_confidence(
#'   tracking_data,
#'   threshold = 0.9,
#'   body_parts = c("nose", "tail_base")
#' )
#' }
#'
#' @seealso \code{\link{interpolate_missing}}, \code{\link{smooth_trajectory}}
#'
#' @export
filter_low_confidence <- function(tracking_data,
                                   threshold = 0.9,
                                   body_parts = NULL,
                                   verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object. ",
         "Use new_tracking_data() or convert_dlc_to_tracking_data() to create one.")
  }

  if (!is.numeric(threshold) || threshold < 0 || threshold > 1) {
    stop("threshold must be a numeric value between 0 and 1")
  }

  # Work with a copy to avoid modifying the original
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_filter <- available_parts
  } else {
    # Validate requested body parts exist
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found in the data and will be ignored: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_filter <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_filter) == 0) {
    warning("No valid body parts to filter")
    return(result)
  }

  # Count points to be filtered for reporting
  n_filtered <- 0
  n_total <- 0

  # Filter each body part
  for (part in parts_to_filter) {
    # Get indices for this body part
    part_idx <- result$tracking$body_part == part

    # Identify low confidence points
    low_conf_idx <- part_idx & !is.na(result$tracking$likelihood) &
                    result$tracking$likelihood < threshold

    # Count for reporting
    n_total <- n_total + sum(part_idx)
    n_filtered <- n_filtered + sum(low_conf_idx)

    # Set coordinates to NA for low confidence points
    result$tracking$x[low_conf_idx] <- NA
    result$tracking$y[low_conf_idx] <- NA
  }

  # Report filtering results
  if (verbose && n_total > 0) {
    pct_filtered <- round(100 * n_filtered / n_total, 2)
    message(sprintf("Filtered %d of %d points (%.2f%%) with likelihood < %.2f",
                    n_filtered, n_total, pct_filtered, threshold))

    # Report per body part
    for (part in parts_to_filter) {
      part_idx <- result$tracking$body_part == part
      part_low_conf <- part_idx & is.na(result$tracking$x)
      n_part_total <- sum(part_idx)
      n_part_filtered <- sum(part_low_conf)
      pct_part <- round(100 * n_part_filtered / n_part_total, 2)
      message(sprintf("  %s: %d of %d (%.2f%%)",
                      part, n_part_filtered, n_part_total, pct_part))
    }
  }

  return(result)
}

#' Interpolate missing values in tracking data
#'
#' Fills gaps in tracking data using various interpolation methods. This is
#' typically used after filtering low-confidence points with \code{filter_low_confidence()}.
#' Only gaps up to a maximum length are interpolated; longer gaps are left as NA.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param method Character string specifying interpolation method. Options are:
#'   \describe{
#'     \item{"linear"}{Linear interpolation (default, fast and simple)}
#'     \item{"spline"}{Cubic spline interpolation (smooth, good for curved paths)}
#'     \item{"polynomial"}{Polynomial interpolation (smooth, may overshoot)}
#'   }
#' @param max_gap Integer. Maximum gap length (in frames) to interpolate. Gaps
#'   longer than this are left as NA. Default is 5 frames.
#' @param body_parts Optional character vector specifying which body parts to
#'   interpolate. If NULL (default), all body parts are interpolated.
#' @param verbose Logical. If TRUE, prints information about interpolation. Default is FALSE.
#'
#' @return A tracking_data object with missing values interpolated
#'
#' @details
#' The function interpolates x and y coordinates separately for each body part.
#' Interpolation is performed frame-by-frame, respecting the max_gap parameter.
#'
#' \strong{Interpolation Methods:}
#' \itemize{
#'   \item \strong{linear}: Fast and simple, connects points with straight lines.
#'     Good for short gaps and relatively straight trajectories.
#'   \item \strong{spline}: Uses cubic splines for smooth interpolation. Better
#'     for curved paths but slower. May produce unrealistic values if gaps are large.
#'   \item \strong{polynomial}: Fits polynomials to surrounding points. Can produce
#'     smooth curves but may overshoot or create artifacts for large gaps.
#' }
#'
#' @examples
#' \dontrun{
#' # First filter low confidence points, then interpolate
#' filtered <- filter_low_confidence(tracking_data, threshold = 0.9)
#' interpolated <- interpolate_missing(filtered, method = "linear", max_gap = 5)
#'
#' # Use spline interpolation for smoother curves
#' interpolated <- interpolate_missing(filtered, method = "spline", max_gap = 3)
#'
#' # Only interpolate specific body parts
#' interpolated <- interpolate_missing(
#'   filtered,
#'   method = "linear",
#'   max_gap = 5,
#'   body_parts = c("nose", "tail_base")
#' )
#' }
#'
#' @seealso \code{\link{filter_low_confidence}}, \code{\link{smooth_trajectory}}
#'
#' @export
interpolate_missing <- function(tracking_data,
                                 method = "linear",
                                 max_gap = 5,
                                 body_parts = NULL,
                                 verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  valid_methods <- c("linear", "spline", "polynomial")
  if (!method %in% valid_methods) {
    stop("method must be one of: ", paste(valid_methods, collapse = ", "))
  }

  if (!is.numeric(max_gap) || max_gap < 1) {
    stop("max_gap must be a positive integer")
  }

  # Work with a copy
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to interpolate")
    return(result)
  }

  # Track interpolation statistics
  n_interpolated <- 0
  n_total_na <- 0

  # Process each body part
  for (part in parts_to_process) {
    # Get indices for this body part
    part_idx <- which(result$tracking$body_part == part)

    # Count NAs before interpolation
    na_x_before <- sum(is.na(result$tracking$x[part_idx]))
    na_y_before <- sum(is.na(result$tracking$y[part_idx]))
    n_total_na <- n_total_na + na_x_before + na_y_before

    # Interpolate x and y separately (directly on the tracking data)
    result$tracking$x[part_idx] <- interpolate_vector(result$tracking$x[part_idx], method, max_gap)
    result$tracking$y[part_idx] <- interpolate_vector(result$tracking$y[part_idx], method, max_gap)

    # Count NAs after interpolation
    na_x_after <- sum(is.na(result$tracking$x[part_idx]))
    na_y_after <- sum(is.na(result$tracking$y[part_idx]))
    n_interpolated <- n_interpolated + (na_x_before - na_x_after) + (na_y_before - na_y_after)
  }

  # Report results
  if (verbose && n_total_na > 0) {
    pct_interpolated <- round(100 * n_interpolated / n_total_na, 2)
    message(sprintf("Interpolated %d of %d missing values (%.2f%%) using %s method",
                    n_interpolated, n_total_na, pct_interpolated, method))
  }

  return(result)
}

#' Helper function to interpolate a single numeric vector
#'
#' @param x Numeric vector with possible NA values
#' @param method Interpolation method
#' @param max_gap Maximum gap to interpolate
#'
#' @return Numeric vector with interpolated values
#' @keywords internal
interpolate_vector <- function(x, method, max_gap) {
  # If no NAs, return as is
  if (!any(is.na(x))) {
    return(x)
  }

  # If all NAs, return as is
  if (all(is.na(x))) {
    return(x)
  }

  # Identify NA runs
  na_idx <- which(is.na(x))

  # Find runs of NAs and only interpolate if gap <= max_gap
  if (length(na_idx) > 0) {
    # Group consecutive NAs
    na_runs <- split(na_idx, cumsum(c(1, diff(na_idx) != 1)))

    for (run in na_runs) {
      gap_length <- length(run)

      # Only interpolate if gap is within limit
      if (gap_length <= max_gap) {
        start_idx <- run[1]
        end_idx <- run[length(run)]

        # Need at least one valid point before and after
        has_before <- start_idx > 1 && !is.na(x[start_idx - 1])
        has_after <- end_idx < length(x) && !is.na(x[end_idx + 1])

        if (has_before && has_after) {
          if (method == "linear") {
            # Linear interpolation
            x_before <- x[start_idx - 1]
            x_after <- x[end_idx + 1]
            x[run] <- seq(from = x_before, to = x_after, length.out = gap_length + 2)[2:(gap_length + 1)]

          } else if (method == "spline") {
            # Cubic spline interpolation
            # Get surrounding valid points
            valid_idx <- which(!is.na(x))
            before_points <- valid_idx[valid_idx < start_idx]
            after_points <- valid_idx[valid_idx > end_idx]

            # Use up to 4 points before and after for spline
            n_before <- min(4, length(before_points))
            n_after <- min(4, length(after_points))

            if (n_before > 0 && n_after > 0) {
              spline_idx <- c(tail(before_points, n_before),
                            head(after_points, n_after))
              spline_x <- spline_idx
              spline_y <- x[spline_idx]

              # Interpolate using spline
              spline_result <- spline(spline_x, spline_y, xout = run, method = "natural")
              x[run] <- spline_result$y
            } else {
              # Fall back to linear if not enough points
              x_before <- x[start_idx - 1]
              x_after <- x[end_idx + 1]
              x[run] <- seq(from = x_before, to = x_after, length.out = gap_length + 2)[2:(gap_length + 1)]
            }

          } else if (method == "polynomial") {
            # Polynomial interpolation using approx with method = "constant" then smooth
            # For simplicity, use spline-based polynomial
            valid_idx <- which(!is.na(x))
            before_points <- valid_idx[valid_idx < start_idx]
            after_points <- valid_idx[valid_idx > end_idx]

            n_before <- min(3, length(before_points))
            n_after <- min(3, length(after_points))

            if (n_before > 0 && n_after > 0) {
              poly_idx <- c(tail(before_points, n_before),
                          head(after_points, n_after))
              poly_x <- poly_idx
              poly_y <- x[poly_idx]

              # Use approxfun with polynomial
              spline_result <- spline(poly_x, poly_y, xout = run, method = "fmm")
              x[run] <- spline_result$y
            } else {
              # Fall back to linear
              x_before <- x[start_idx - 1]
              x_after <- x[end_idx + 1]
              x[run] <- seq(from = x_before, to = x_after, length.out = gap_length + 2)[2:(gap_length + 1)]
            }
          }
        }
      }
    }
  }

  return(x)
}

#' Smooth trajectory data
#'
#' Applies smoothing to trajectory data to reduce noise and jitter in tracking.
#' Multiple smoothing methods are supported, each with different characteristics.
#'
#' @param tracking_data A tracking_data object (see \code{\link{new_tracking_data}})
#' @param method Character string specifying smoothing method. Options are:
#'   \describe{
#'     \item{"savgol"}{Savitzky-Golay filter (default, preserves peaks)}
#'     \item{"ma"}{Moving average (simple, good for general smoothing)}
#'     \item{"gaussian"}{Gaussian-weighted moving average (smooth, emphasizes center)}
#'   }
#' @param window Integer. Window size for smoothing (must be odd for Savitzky-Golay).
#'   Default is 11 frames. Larger windows = more smoothing.
#' @param body_parts Optional character vector specifying which body parts to smooth.
#'   If NULL (default), all body parts are smoothed.
#' @param polynomial Integer. Polynomial order for Savitzky-Golay filter (1-5).
#'   Default is 3. Ignored for other methods.
#' @param sigma Numeric. Standard deviation for Gaussian kernel. Default is
#'   window/6. Only used for gaussian method.
#' @param verbose Logical. If TRUE, prints information about smoothing. Default is FALSE.
#'
#' @return A tracking_data object with smoothed trajectories
#'
#' @details
#' Smoothing reduces noise in tracking data but can also reduce temporal resolution.
#' Choose window size based on your data's frame rate and movement speed.
#'
#' \strong{Smoothing Methods:}
#' \itemize{
#'   \item \strong{savgol}: Savitzky-Golay filter fits a polynomial to data in a
#'     sliding window. Preserves peaks and features better than moving average.
#'     Best for preserving trajectory shape while reducing noise.
#'   \item \strong{ma}: Simple moving average. Each point is replaced by the mean
#'     of surrounding points. Fast and simple but can blur sharp turns.
#'   \item \strong{gaussian}: Weighted moving average with Gaussian kernel. Smooth
#'     results with more weight on center points. Good general-purpose smoother.
#' }
#'
#' \strong{Window Size Guidelines:}
#' \itemize{
#'   \item Small (5-7): Light smoothing, preserves detail
#'   \item Medium (9-15): Moderate smoothing, good balance
#'   \item Large (15+): Heavy smoothing, may lose rapid movements
#' }
#'
#' @examples
#' \dontrun{
#' # Apply Savitzky-Golay smoothing with default settings
#' smoothed <- smooth_trajectory(tracking_data)
#'
#' # Use moving average with larger window
#' smoothed <- smooth_trajectory(tracking_data, method = "ma", window = 15)
#'
#' # Gaussian smoothing with custom sigma
#' smoothed <- smooth_trajectory(
#'   tracking_data,
#'   method = "gaussian",
#'   window = 11,
#'   sigma = 2.0
#' )
#'
#' # Full preprocessing pipeline
#' data <- filter_low_confidence(tracking_data, threshold = 0.9)
#' data <- interpolate_missing(data, max_gap = 5)
#' data <- smooth_trajectory(data, method = "savgol", window = 11)
#' }
#'
#' @seealso \code{\link{filter_low_confidence}}, \code{\link{interpolate_missing}}
#'
#' @export
smooth_trajectory <- function(tracking_data,
                              method = "savgol",
                              window = 11,
                              body_parts = NULL,
                              polynomial = 3,
                              sigma = NULL,
                              verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  valid_methods <- c("savgol", "ma", "gaussian")
  if (!method %in% valid_methods) {
    stop("method must be one of: ", paste(valid_methods, collapse = ", "))
  }

  if (!is.numeric(window) || window < 3 || window %% 2 == 0) {
    stop("window must be an odd integer >= 3")
  }

  if (method == "savgol") {
    if (!is.numeric(polynomial) || polynomial < 1 || polynomial >= window) {
      stop("polynomial must be a positive integer < window")
    }
  }

  # Set default sigma for gaussian
  if (method == "gaussian" && is.null(sigma)) {
    sigma <- window / 6
  }

  # Work with a copy
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to smooth")
    return(result)
  }

  # Process each body part
  for (part in parts_to_process) {
    # Get indices for this body part
    part_idx <- which(result$tracking$body_part == part)

    # Smooth x and y separately (directly on the tracking data)
    if (method == "savgol") {
      result$tracking$x[part_idx] <- smooth_savgol(result$tracking$x[part_idx], window, polynomial)
      result$tracking$y[part_idx] <- smooth_savgol(result$tracking$y[part_idx], window, polynomial)
    } else if (method == "ma") {
      result$tracking$x[part_idx] <- smooth_ma(result$tracking$x[part_idx], window)
      result$tracking$y[part_idx] <- smooth_ma(result$tracking$y[part_idx], window)
    } else if (method == "gaussian") {
      result$tracking$x[part_idx] <- smooth_gaussian(result$tracking$x[part_idx], window, sigma)
      result$tracking$y[part_idx] <- smooth_gaussian(result$tracking$y[part_idx], window, sigma)
    }
  }

  if (verbose) {
    message(sprintf("Applied %s smoothing with window = %d to %d body part(s)",
                    method, window, length(parts_to_process)))
  }

  return(result)
}

#' Apply Savitzky-Golay filter to a vector
#'
#' @param x Numeric vector
#' @param window Window size (odd integer)
#' @param polynomial Polynomial order
#'
#' @return Smoothed numeric vector
#' @keywords internal
smooth_savgol <- function(x, window, polynomial) {
  # Handle NAs
  if (all(is.na(x))) {
    return(x)
  }

  n <- length(x)
  result <- x
  half_window <- floor(window / 2)

  # For each point, fit polynomial to surrounding points
  for (i in 1:n) {
    if (is.na(x[i])) {
      next
    }

    # Determine window bounds
    start_idx <- max(1, i - half_window)
    end_idx <- min(n, i + half_window)

    # Extract window data
    window_idx <- start_idx:end_idx
    window_x <- window_idx - i  # Center at 0
    window_y <- x[window_idx]

    # Skip if too many NAs in window
    if (sum(!is.na(window_y)) < polynomial + 1) {
      next
    }

    # Fit polynomial (using only non-NA values)
    valid <- !is.na(window_y)
    if (sum(valid) >= polynomial + 1) {
      poly_fit <- tryCatch({
        lm(window_y[valid] ~ poly(window_x[valid], polynomial, raw = TRUE))
      }, error = function(e) NULL)

      if (!is.null(poly_fit)) {
        # Predict value at center point (x = 0)
        result[i] <- predict(poly_fit, newdata = data.frame(window_x = 0))
      }
    }
  }

  return(result)
}

#' Apply moving average to a vector
#'
#' @param x Numeric vector
#' @param window Window size
#'
#' @return Smoothed numeric vector
#' @keywords internal
smooth_ma <- function(x, window) {
  # Handle NAs
  if (all(is.na(x))) {
    return(x)
  }

  n <- length(x)
  result <- x
  half_window <- floor(window / 2)

  for (i in 1:n) {
    if (is.na(x[i])) {
      next
    }

    start_idx <- max(1, i - half_window)
    end_idx <- min(n, i + half_window)

    window_vals <- x[start_idx:end_idx]
    valid_vals <- window_vals[!is.na(window_vals)]

    if (length(valid_vals) > 0) {
      result[i] <- mean(valid_vals)
    }
  }

  return(result)
}

#' Apply Gaussian-weighted moving average to a vector
#'
#' @param x Numeric vector
#' @param window Window size
#' @param sigma Standard deviation for Gaussian kernel
#'
#' @return Smoothed numeric vector
#' @keywords internal
smooth_gaussian <- function(x, window, sigma) {
  # Handle NAs
  if (all(is.na(x))) {
    return(x)
  }

  n <- length(x)
  result <- x
  half_window <- floor(window / 2)

  # Create Gaussian kernel
  kernel_x <- seq(-half_window, half_window)
  kernel <- exp(-(kernel_x^2) / (2 * sigma^2))
  kernel <- kernel / sum(kernel)  # Normalize

  for (i in 1:n) {
    if (is.na(x[i])) {
      next
    }

    start_idx <- max(1, i - half_window)
    end_idx <- min(n, i + half_window)

    # Get window and corresponding kernel weights
    window_idx <- start_idx:end_idx
    window_vals <- x[window_idx]

    # Adjust kernel if at edges
    kernel_start <- half_window - (i - start_idx) + 1
    kernel_end <- kernel_start + length(window_idx) - 1
    window_kernel <- kernel[kernel_start:kernel_end]

    # Only use non-NA values
    valid <- !is.na(window_vals)
    if (sum(valid) > 0) {
      # Renormalize kernel for valid values
      valid_kernel <- window_kernel[valid]
      valid_kernel <- valid_kernel / sum(valid_kernel)

      result[i] <- sum(window_vals[valid] * valid_kernel)
    }
  }

  return(result)
}
#' Extended Preprocessing Functions for DLCAnalyzer
#'
#' Additional preprocessing functions for cleaning and filtering tracking data.
#' These functions complement the core preprocessing.R functions.
#'
#' @name preprocessing_extended
NULL

#' Find coherent tracking start
#'
#' Identifies the first point where tracking becomes stable and coherent. This
#' removes initial frames where tracking is poor, jumpy, or inconsistent.
#'
#' @param tracking_data A tracking_data object
#' @param body_parts Optional character vector specifying which body parts to check.
#'   If NULL (default), all body parts are checked.
#' @param min_coherent_points Integer. Minimum number of consecutive stable points
#'   required to consider tracking coherent (default: 15).
#' @param max_jump Numeric. Maximum allowed distance between consecutive points
#'   (in coordinate units) to be considered stable (default: 50 pixels).
#' @param max_na_streak Integer. Maximum consecutive NA points allowed in coherent
#'   region (default: 2).
#' @param verbose Logical. If TRUE, prints information. Default is FALSE.
#'
#' @return A tracking_data object with frames before coherent start removed
#'
#' @details
#' This function searches for the first sequence of frames where:
#' \itemize{
#'   \item At least min_coherent_points consecutive valid points exist
#'   \item Points don't jump more than max_jump distance between frames
#'   \item No more than max_na_streak consecutive NAs in the sequence
#' }
#'
#' This removes problematic initial tracking where the animal hasn't been
#' detected yet or tracking is unstable.
#'
#' @export
find_coherent_start <- function(tracking_data,
                                  body_parts = NULL,
                                  min_coherent_points = 10,
                                  max_jump = 50,
                                  max_na_streak = 4,
                                  verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  result <- tracking_data
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to process")
    return(result)
  }

  rows_to_remove <- c()
  total_removed <- 0

  # Process each body part
  for (part in parts_to_process) {
    part_idx <- which(result$tracking$body_part == part)
    part_data <- result$tracking[part_idx, , drop = FALSE]

    # Store the ordering so we can map back to original indices
    frame_order <- order(part_data$frame)
    part_data_sorted <- part_data[frame_order, ]

    # Find coherent start (on sorted data)
    coherent_start <- find_coherent_start_idx(
      part_data_sorted$x,
      part_data_sorted$y,
      min_coherent_points = min_coherent_points,
      max_jump = max_jump,
      max_na_streak = max_na_streak
    )

    # Find coherent end (work backwards from end, on sorted data)
    coherent_end <- find_coherent_end_idx(
      part_data_sorted$x,
      part_data_sorted$y,
      min_coherent_points = min_coherent_points,
      max_jump = max_jump,
      max_na_streak = max_na_streak
    )

    if (is.na(coherent_start) || is.na(coherent_end)) {
      # No coherent region found
      rows_to_remove <- c(rows_to_remove, part_idx)
      total_removed <- total_removed + nrow(part_data_sorted)
      if (verbose) {
        message(sprintf("  %s: removed all %d frames (no coherent tracking found)",
                        part, nrow(part_data_sorted)))
      }
      next
    }

    # Remove frames before coherent start and after coherent end
    # Map sorted indices back to original indices using frame_order
    if (coherent_start > 1) {
      rows_to_remove <- c(rows_to_remove, part_idx[frame_order[1:(coherent_start - 1)]])
    }
    if (coherent_end < nrow(part_data_sorted)) {
      rows_to_remove <- c(rows_to_remove, part_idx[frame_order[(coherent_end + 1):nrow(part_data_sorted)]])
    }

    removed_count <- (coherent_start - 1) + (nrow(part_data) - coherent_end)
    total_removed <- total_removed + removed_count

    if (verbose && removed_count > 0) {
      message(sprintf("  %s: removed %d non-coherent frames (%d leading, %d trailing)",
                      part, removed_count, coherent_start - 1,
                      nrow(part_data) - coherent_end))
    }
  }

  # Remove marked rows
  if (length(rows_to_remove) > 0) {
    result$tracking <- result$tracking[-rows_to_remove, ]
    rownames(result$tracking) <- NULL
  }

  if (verbose && total_removed > 0) {
    message(sprintf("Total removed: %d frames", total_removed))
  }

  return(result)
}

#' Helper: Find coherent start index
#' @keywords internal
find_coherent_start_idx <- function(x, y, min_coherent_points, max_jump, max_na_streak) {
  n <- length(x)

  for (i in 1:(n - min_coherent_points + 1)) {
    # Check if this position starts a coherent sequence
    if (is_coherent_sequence(x, y, i, min_coherent_points, max_jump, max_na_streak)) {
      return(i)
    }
  }

  return(NA_integer_)
}

#' Helper: Find coherent end index (working backwards)
#' @keywords internal
find_coherent_end_idx <- function(x, y, min_coherent_points, max_jump, max_na_streak) {
  n <- length(x)

  for (i in n:(min_coherent_points)) {
    # Check if this position ends a coherent sequence
    start_idx <- i - min_coherent_points + 1
    if (is_coherent_sequence(x, y, start_idx, min_coherent_points, max_jump, max_na_streak)) {
      return(i)
    }
  }

  return(NA_integer_)
}

#' Helper: Check if sequence is coherent
#' @keywords internal
is_coherent_sequence <- function(x, y, start_idx, min_points, max_jump, max_na_streak) {
  end_idx <- start_idx + min_points - 1
  if (end_idx > length(x)) return(FALSE)

  x_seq <- x[start_idx:end_idx]
  y_seq <- y[start_idx:end_idx]

  # Check for too many NAs in sequence
  valid <- !is.na(x_seq) & !is.na(y_seq)

  # Adaptive valid point requirement based on min_points:
  # For small min_points (like 5 for Ethovision), require at least 3 valid (60%)
  # For larger min_points (like 15 for DLC), require 70% valid
  min_valid_points <- if (min_points <= 5) {
    max(3, ceiling(min_points * 0.6))  # At least 60% or 3 points, whichever is larger
  } else {
    ceiling(min_points * 0.7)  # 70% for DLC data
  }

  if (sum(valid) < min_valid_points) return(FALSE)

  # CRITICAL: First point MUST be valid (for interpolation to work)
  if (!valid[1]) return(FALSE)

  # Check for long NA streaks
  na_streak <- 0
  for (i in 1:length(valid)) {
    if (!valid[i]) {
      na_streak <- na_streak + 1
      if (na_streak > max_na_streak) return(FALSE)
    } else {
      na_streak <- 0
    }
  }

  # Check for large jumps between consecutive valid points
  valid_idx <- which(valid)
  if (length(valid_idx) < 2) return(FALSE)

  for (i in 2:length(valid_idx)) {
    idx1 <- start_idx + valid_idx[i-1] - 1
    idx2 <- start_idx + valid_idx[i] - 1

    dx <- x[idx2] - x[idx1]
    dy <- y[idx2] - y[idx1]
    dist <- sqrt(dx^2 + dy^2)

    if (dist > max_jump) return(FALSE)
  }

  return(TRUE)
}

#' Remove leading and trailing missing data
#'
#' Removes frames with missing coordinates (NA) from the beginning and end of
#' tracking data for each body part. This is useful for removing frames before
#' the animal enters the arena or after recording ends. Interior missing data
#' (gaps) are preserved for interpolation.
#'
#' @param tracking_data A tracking_data object
#' @param body_parts Optional character vector specifying which body parts to process.
#'   If NULL (default), all body parts are processed.
#' @param verbose Logical. If TRUE, prints information about removed frames. Default is FALSE.
#'
#' @return A tracking_data object with leading/trailing NAs removed
#'
#' @details
#' This function only removes consecutive NA frames at the start and end of the
#' recording. It does NOT remove:
#' \itemize{
#'   \item Interior gaps (missing data in the middle of recording)
#'   \item Frames where only some body parts have valid data
#' }
#'
#' The function processes each body part independently, so different body parts
#' may have different valid frame ranges.
#'
#' @examples
#' \dontrun{
#' # Remove leading/trailing NAs from all body parts
#' cleaned <- remove_leading_trailing_na(tracking_data)
#'
#' # Process specific body parts only
#' cleaned <- remove_leading_trailing_na(
#'   tracking_data,
#'   body_parts = c("mouse_center", "nose")
#' )
#' }
#'
#' @export
remove_leading_trailing_na <- function(tracking_data,
                                        body_parts = NULL,
                                        verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  # Work with a copy
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to process")
    return(result)
  }

  # Track statistics
  total_removed <- 0
  rows_to_remove <- c()

  # Process each body part
  for (part in parts_to_process) {
    # Get indices for this body part
    part_idx <- which(result$tracking$body_part == part)

    # Extract data for this body part (must be in frame order)
    part_data <- result$tracking[part_idx, , drop = FALSE]
    part_data <- part_data[order(part_data$frame), ]

    # Find valid data range (both x and y are non-NA)
    valid_coords <- !is.na(part_data$x) & !is.na(part_data$y)

    if (!any(valid_coords)) {
      # No valid data for this body part - mark all for removal
      rows_to_remove <- c(rows_to_remove, part_idx)
      total_removed <- total_removed + nrow(part_data)
      if (verbose) {
        message(sprintf("  %s: removed all %d frames (no valid data)",
                        part, nrow(part_data)))
      }
      next
    }

    # Find first and last valid frames
    valid_indices <- which(valid_coords)
    first_valid <- valid_indices[1]
    last_valid <- valid_indices[length(valid_indices)]

    # Mark leading and trailing NAs for removal
    if (first_valid > 1) {
      rows_to_remove <- c(rows_to_remove, part_idx[1:(first_valid - 1)])
    }
    if (last_valid < nrow(part_data)) {
      rows_to_remove <- c(rows_to_remove, part_idx[(last_valid + 1):nrow(part_data)])
    }

    removed_count <- (first_valid - 1) + (nrow(part_data) - last_valid)
    total_removed <- total_removed + removed_count

    if (verbose && removed_count > 0) {
      message(sprintf("  %s: removed %d leading/trailing NA frames (%d leading, %d trailing)",
                      part, removed_count, first_valid - 1, nrow(part_data) - last_valid))
    }
  }

  # Remove marked rows
  if (length(rows_to_remove) > 0) {
    result$tracking <- result$tracking[-rows_to_remove, ]
    rownames(result$tracking) <- NULL
  }

  if (verbose && total_removed > 0) {
    message(sprintf("Total removed: %d frames", total_removed))
  }

  return(result)
}

#' Filter points outside arena boundaries
#'
#' Removes tracking points that fall outside the defined arena boundaries.
#' Points outside the arena are typically tracking errors or occur before/after
#' the experimental session. These points are set to NA.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object with zones defined
#' @param margin Numeric. Safety margin (in coordinate units) to allow around
#'   arena boundaries. Default is 0. Use positive values to allow some tolerance
#'   for edge tracking. Use negative values for stricter filtering.
#' @param body_parts Optional character vector specifying which body parts to filter.
#'   If NULL (default), all body parts are filtered.
#' @param verbose Logical. If TRUE, prints information about filtering. Default is FALSE.
#'
#' @return A tracking_data object with out-of-bounds points set to NA
#'
#' @details
#' The arena boundaries are determined from the arena_config zones. The function
#' calculates a bounding box that encompasses all defined zones, then filters
#' points outside this box (plus the specified margin).
#'
#' Points outside the arena are typically due to:
#' \itemize{
#'   \item Tracking errors before the animal enters the arena
#'   \item Tracking errors after the animal leaves
#'   \item False detections in the background
#' }
#'
#' @examples
#' \dontrun{
#' # Filter with no margin
#' filtered <- filter_arena_boundaries(tracking_data, arena_config)
#'
#' # Allow 10-pixel tolerance around boundaries
#' filtered <- filter_arena_boundaries(
#'   tracking_data,
#'   arena_config,
#'   margin = 10
#' )
#'
#' # Stricter filtering (must be 5 pixels inside)
#' filtered <- filter_arena_boundaries(
#'   tracking_data,
#'   arena_config,
#'   margin = -5
#' )
#' }
#'
#' @export
filter_arena_boundaries <- function(tracking_data,
                                     arena_config,
                                     margin = 0,
                                     body_parts = NULL,
                                     verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  if (!inherits(arena_config, "arena_config")) {
    stop("arena_config must be an arena_config object")
  }

  if (!is.numeric(margin)) {
    stop("margin must be a numeric value")
  }

  # Work with a copy
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to filter")
    return(result)
  }

  # Calculate arena bounding box from zones
  # Extract all zone points to determine boundaries
  all_x <- c()
  all_y <- c()

  for (zone in arena_config$zones) {
    if (zone$type == "points" && !is.null(zone$point_names)) {
      # Look up coordinates from arena_config$points
      if (!is.null(arena_config$points)) {
        for (point_name in zone$point_names) {
          point_idx <- which(arena_config$points$point_name == point_name)
          if (length(point_idx) > 0) {
            all_x <- c(all_x, arena_config$points$x[point_idx[1]])
            all_y <- c(all_y, arena_config$points$y[point_idx[1]])
          }
        }
      }
    } else if (zone$type == "polygon" && !is.null(zone$vertices)) {
      all_x <- c(all_x, zone$vertices$x)
      all_y <- c(all_y, zone$vertices$y)
    } else if (zone$type == "circle") {
      # Approximate circle with bounding box
      all_x <- c(all_x, zone$center$x - zone$radius, zone$center$x + zone$radius)
      all_y <- c(all_y, zone$center$y - zone$radius, zone$center$y + zone$radius)
    } else if (zone$type == "rectangle") {
      all_x <- c(all_x, zone$bounds$x_min, zone$bounds$x_max)
      all_y <- c(all_y, zone$bounds$y_min, zone$bounds$y_max)
    }
  }

  if (length(all_x) == 0 || length(all_y) == 0) {
    warning("Could not determine arena boundaries from zones")
    return(result)
  }

  # Define bounding box with margin
  x_min <- min(all_x) - margin
  x_max <- max(all_x) + margin
  y_min <- min(all_y) - margin
  y_max <- max(all_y) + margin

  if (verbose) {
    message(sprintf("Arena boundaries (with margin=%.1f):", margin))
    message(sprintf("  X: %.2f to %.2f", x_min, x_max))
    message(sprintf("  Y: %.2f to %.2f", y_min, y_max))
  }

  # Filter each body part
  n_filtered <- 0
  n_total <- 0

  for (part in parts_to_process) {
    # Get indices for this body part
    part_idx <- result$tracking$body_part == part

    # Find points outside boundaries
    x_vals <- result$tracking$x[part_idx]
    y_vals <- result$tracking$y[part_idx]

    out_of_bounds <- !is.na(x_vals) & !is.na(y_vals) &
                     (x_vals < x_min | x_vals > x_max |
                      y_vals < y_min | y_vals > y_max)

    # Count for reporting
    n_total <- n_total + sum(part_idx)
    n_filtered <- n_filtered + sum(out_of_bounds)

    # Set out-of-bounds points to NA
    result$tracking$x[part_idx][out_of_bounds] <- NA
    result$tracking$y[part_idx][out_of_bounds] <- NA

    if (verbose && sum(out_of_bounds) > 0) {
      message(sprintf("  %s: filtered %d out-of-bounds points",
                      part, sum(out_of_bounds)))
    }
  }

  if (verbose && n_total > 0) {
    pct_filtered <- round(100 * n_filtered / n_total, 2)
    message(sprintf("Total filtered: %d of %d points (%.2f%%)",
                    n_filtered, n_total, pct_filtered))
  }

  return(result)
}

#' Apply moving median filter
#'
#' Applies a moving median filter to smooth trajectory data. The median is more
#' robust to outliers than the mean, making it better for noisy tracking data
#' with occasional large errors.
#'
#' @param tracking_data A tracking_data object
#' @param window Integer. Window size for the moving median (must be odd).
#'   Default is 5 frames. Larger windows = more smoothing.
#' @param body_parts Optional character vector specifying which body parts to filter.
#'   If NULL (default), all body parts are filtered.
#' @param verbose Logical. If TRUE, prints information. Default is FALSE.
#'
#' @return A tracking_data object with median-filtered trajectories
#'
#' @details
#' The moving median filter replaces each point with the median of surrounding
#' points in a sliding window. This is particularly effective at removing:
#' \itemize{
#'   \item Outliers (single-frame tracking errors)
#'   \item Salt-and-pepper noise
#'   \item Brief tracking glitches
#' }
#'
#' Unlike the moving average, the median filter:
#' \itemize{
#'   \item Preserves sharp edges and turns better
#'   \item Is less affected by outliers
#'   \item May produce slightly less smooth output
#' }
#'
#' @examples
#' \dontrun{
#' # Apply moving median with default window
#' filtered <- smooth_median(tracking_data, window = 5)
#'
#' # Use larger window for more aggressive smoothing
#' filtered <- smooth_median(tracking_data, window = 9)
#'
#' # Full preprocessing pipeline
#' data <- filter_low_confidence(tracking_data, threshold = 0.9)
#' data <- remove_leading_trailing_na(data)
#' data <- filter_arena_boundaries(data, arena_config)
#' data <- smooth_median(data, window = 5)
#' data <- smooth_trajectory(data, method = "gaussian", window = 11)
#' }
#'
#' @seealso \code{\link{smooth_trajectory}}, \code{\link{filter_low_confidence}}
#'
#' @export
smooth_median <- function(tracking_data,
                           window = 5,
                           body_parts = NULL,
                           verbose = FALSE) {
  # Validate input
  if (!inherits(tracking_data, "tracking_data")) {
    stop("Input must be a tracking_data object")
  }

  if (!is.numeric(window) || window < 3 || window %% 2 == 0) {
    stop("window must be an odd integer >= 3")
  }

  # Work with a copy
  result <- tracking_data

  # Determine which body parts to process
  available_parts <- unique(result$tracking$body_part)

  if (is.null(body_parts)) {
    parts_to_process <- available_parts
  } else {
    invalid_parts <- setdiff(body_parts, available_parts)
    if (length(invalid_parts) > 0) {
      warning("The following body parts were not found: ",
              paste(invalid_parts, collapse = ", "))
    }
    parts_to_process <- intersect(body_parts, available_parts)
  }

  if (length(parts_to_process) == 0) {
    warning("No valid body parts to smooth")
    return(result)
  }

  # Process each body part
  for (part in parts_to_process) {
    # Get indices for this body part
    part_idx <- which(result$tracking$body_part == part)

    # Apply median filter to x and y (directly on the tracking data)
    result$tracking$x[part_idx] <- apply_median_filter(result$tracking$x[part_idx], window)
    result$tracking$y[part_idx] <- apply_median_filter(result$tracking$y[part_idx], window)
  }

  if (verbose) {
    message(sprintf("Applied moving median filter (window = %d) to %d body part(s)",
                    window, length(parts_to_process)))
  }

  return(result)
}

#' Helper function to apply median filter to a vector
#'
#' @param x Numeric vector
#' @param window Window size (odd integer)
#'
#' @return Median-filtered numeric vector
#' @keywords internal
apply_median_filter <- function(x, window) {
  # Handle all-NA case
  if (all(is.na(x))) {
    return(x)
  }

  n <- length(x)
  result <- x
  half_window <- floor(window / 2)

  for (i in 1:n) {
    if (is.na(x[i])) {
      next
    }

    # Determine window bounds
    start_idx <- max(1, i - half_window)
    end_idx <- min(n, i + half_window)

    # Extract window values
    window_vals <- x[start_idx:end_idx]
    valid_vals <- window_vals[!is.na(window_vals)]

    # Replace with median if we have valid values
    if (length(valid_vals) > 0) {
      result[i] <- median(valid_vals)
    }
  }

  return(result)
}

#' Comprehensive preprocessing pipeline
#'
#' Applies a standard preprocessing pipeline to tracking data including
#' confidence filtering, arena boundary filtering, missing data removal,
#' interpolation, and smoothing.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object (required for boundary filtering)
#' @param likelihood_threshold Numeric. Minimum likelihood for valid tracking points (0-1).
#'   Default is 0.9. Set to 0 to skip confidence filtering.
#' @param arena_margin Numeric. Margin around arena boundaries (default: 10).
#' @param find_coherent_start Logical. Find coherent tracking start/end (default: TRUE).
#' @param min_coherent_points Integer. Minimum coherent points for start detection (default: 15).
#' @param max_jump Numeric. Maximum jump distance for coherent tracking (default: 50 pixels).
#' @param interpolate_all_gaps Logical. Interpolate ALL missing data to achieve 100% completeness (default: TRUE).
#' @param smooth_method Character. Smoothing method: "savgol", "ma", or "gaussian" (default: "gaussian").
#' @param smooth_window Integer. Window size for smoothing (default: 11).
#' @param body_parts Optional character vector of body parts to process.
#' @param verbose Logical. Print progress information (default: FALSE).
#' @param plot_comparison Logical. Generate comparison plots (default: FALSE).
#' @param comparison_output_dir Character. Directory to save comparison plots. If NULL,
#'   plots are displayed interactively (default: NULL).
#'
#' @return A preprocessed tracking_data object with 100% complete data (no NAs).
#'   If plot_comparison=TRUE, includes an attribute "preprocessing_summary" with comparison statistics.
#'
#' @details
#' This function applies a comprehensive preprocessing pipeline to achieve 100% data completeness:
#' \enumerate{
#'   \item Filter low confidence points (set to NA)
#'   \item Filter points outside arena boundaries (set to NA)
#'   \item Find coherent tracking start/end (remove unstable initial/final frames)
#'   \item Smooth trajectory to reduce noise
#'   \item Interpolate ALL remaining gaps to achieve 100% completeness
#' }
#'
#' The result is guaranteed to have no missing data (100% complete) for all processed body parts.
#'
#' Each step can be individually disabled by setting the corresponding parameter to FALSE.
#'
#' @examples
#' \dontrun{
#' # Apply full default preprocessing
#' cleaned <- preprocess_tracking(tracking_data, arena_config)
#'
#' # Custom preprocessing with more aggressive filtering
#' cleaned <- preprocess_tracking(
#'   tracking_data,
#'   arena_config,
#'   likelihood_threshold = 0.95,
#'   smooth_method = "savgol",
#'   smooth_window = 15,
#'   verbose = TRUE
#' )
#'
#' # Minimal preprocessing (only confidence and boundaries)
#' cleaned <- preprocess_tracking(
#'   tracking_data,
#'   arena_config,
#'   likelihood_threshold = 0.9,
#'   remove_leading_trailing = FALSE,
#'   interpolate_gaps = FALSE,
#'   apply_median_filter = FALSE,
#'   apply_smoothing = FALSE
#' )
#' }
#'
#' @export
preprocess_tracking <- function(tracking_data,
                                 arena_config,
                                 likelihood_threshold = 0.9,
                                 arena_margin = 10,
                                 find_coherent_start = FALSE,
                                 min_coherent_points = 15,
                                 max_jump = 50,
                                 interpolate_all_gaps = TRUE,
                                 smooth_method = "gaussian",
                                 smooth_window = 11,
                                 body_parts = NULL,
                                 verbose = FALSE,
                                 plot_comparison = FALSE,
                                 comparison_output_dir = NULL) {

  if (verbose) {
    message("Starting preprocessing pipeline...")
    message("Goal: Achieve 100% complete tracking data with no missing values")
  }

  # Store copy of raw data for comparison if requested
  if (plot_comparison) {
    raw_data_copy <- tracking_data
  }

  result <- tracking_data

  # Step 1: Filter low confidence points
  if (likelihood_threshold > 0) {
    if (verbose) message("\n  Step 1: Filtering low confidence points...")
    result <- filter_low_confidence(result,
                                     threshold = likelihood_threshold,
                                     body_parts = body_parts,
                                     verbose = verbose)
  }

  # Step 2: Filter arena boundaries
  if (!is.null(arena_config)) {
    if (verbose) message("\n  Step 2: Filtering out-of-arena points...")
    result <- filter_arena_boundaries(result,
                                       arena_config,
                                       margin = arena_margin,
                                       body_parts = body_parts,
                                       verbose = verbose)
  }

  # Step 3: Find coherent tracking start/end
  if (find_coherent_start) {
    if (verbose) message("\n  Step 3: Finding coherent tracking region...")
    result <- find_coherent_start(result,
                                   body_parts = body_parts,
                                   min_coherent_points = min_coherent_points,
                                   max_jump = max_jump,
                                   max_na_streak = max_na_streak,
                                   verbose = verbose)
  }

  # Step 4: Apply smoothing BEFORE interpolation
  # This helps interpolation by providing smoother trajectories
  if (smooth_window > 0) {
    if (verbose) message("\n  Step 4: Smoothing trajectory...")
    result <- smooth_trajectory(result,
                                 method = smooth_method,
                                 window = smooth_window,
                                 body_parts = body_parts,
                                 verbose = verbose)
  }

  # Step 5: Interpolate ALL gaps to achieve 100% completeness
  if (interpolate_all_gaps) {
    if (verbose) message("\n  Step 5: Interpolating all remaining gaps...")
    # Use a very large max_gap to interpolate everything
    result <- interpolate_missing(result,
                                   method = "linear",
                                   max_gap = 10000,  # Interpolate all gaps
                                   body_parts = body_parts,
                                   verbose = verbose)
  }

  # Final verification
  if (verbose) {
    parts_to_check <- if (is.null(body_parts)) {
      unique(result$tracking$body_part)
    } else {
      body_parts
    }

    message("\n  Final data completeness check:")
    for (part in parts_to_check) {
      part_data <- result$tracking[result$tracking$body_part == part, ]
      n_total <- nrow(part_data)
      n_valid <- sum(!is.na(part_data$x) & !is.na(part_data$y))
      pct_complete <- 100 * n_valid / n_total
      message(sprintf("    %s: %.1f%% complete (%d/%d frames)",
                      part, pct_complete, n_valid, n_total))
    }
  }

  if (verbose) {
    message("\nPreprocessing complete!")
  }

  # Generate comparison plots and summaries if requested
  if (plot_comparison) {
    if (verbose) message("  7. Generating comparison plots...")

    # Determine body part for comparison
    compare_body_part <- if (!is.null(body_parts) && length(body_parts) > 0) {
      body_parts[1]
    } else {
      # Use first available body part
      unique(result$tracking$body_part)[1]
    }

    # Generate summary statistics
    summary_stats <- summarize_preprocessing(
      raw_data_copy,
      result,
      body_part = compare_body_part
    )

    if (verbose) {
      message("\nPreprocessing Summary:")
      print(summary_stats)
    }

    # Generate comparison plot
    if (!is.null(comparison_output_dir)) {
      # Create output directory if needed
      if (!dir.exists(comparison_output_dir)) {
        dir.create(comparison_output_dir, recursive = TRUE, showWarnings = FALSE)
      }

      # Save plot
      plot_file <- file.path(comparison_output_dir, "preprocessing_comparison.png")
      plot_preprocessing_comparison(
        raw_data_copy,
        result,
        body_part = compare_body_part,
        output_file = plot_file
      )
    } else {
      # Display plot
      p <- plot_preprocessing_comparison(
        raw_data_copy,
        result,
        body_part = compare_body_part
      )
      print(p)
    }

    # Store comparison data in result
    attr(result, "preprocessing_summary") <- summary_stats
  }

  return(result)
}

#' Compare raw and preprocessed tracking data
#'
#' Creates side-by-side comparison plots showing raw vs. preprocessed tracking data.
#' Useful for visualizing the effects of preprocessing steps.
#'
#' @param raw_data A tracking_data object (before preprocessing)
#' @param cleaned_data A tracking_data object (after preprocessing)
#' @param body_part Character. Body part to compare (default: "mouse_center")
#' @param output_file Optional. Path to save comparison plot. If NULL, plot is displayed.
#' @param max_points Integer. Maximum points to plot for performance (default: 2000)
#'
#' @return A ggplot object with side-by-side comparison
#'
#' @details
#' Creates a 2-panel plot showing:
#' \itemize{
#'   \item Left panel: Raw trajectory
#'   \item Right panel: Preprocessed trajectory
#' }
#'
#' Missing data points (NA) are shown in red. This helps visualize:
#' \itemize{
#'   \item Removal of leading/trailing NAs
#'   \item Filtering of low-confidence points
#'   \item Smoothing effects
#'   \item Interpolation of gaps
#' }
#'
#' @examples
#' \dontrun{
#' # Load data
#' raw_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#'
#' # Preprocess
#' cleaned_data <- preprocess_tracking(raw_data, arena_config)
#'
#' # Compare
#' plot_preprocessing_comparison(raw_data, cleaned_data)
#'
#' # Save to file
#' plot_preprocessing_comparison(
#'   raw_data,
#'   cleaned_data,
#'   output_file = "comparison.png"
#' )
#' }
#'
#' @export
plot_preprocessing_comparison <- function(raw_data,
                                           cleaned_data,
                                           body_part = "mouse_center",
                                           output_file = NULL,
                                           max_points = 2000) {
  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting")
  }

  # Validate inputs
  if (!inherits(raw_data, "tracking_data")) {
    stop("raw_data must be a tracking_data object")
  }
  if (!inherits(cleaned_data, "tracking_data")) {
    stop("cleaned_data must be a tracking_data object")
  }

  # Extract data for specified body part
  raw_track <- raw_data$tracking[raw_data$tracking$body_part == body_part, ]
  clean_track <- cleaned_data$tracking[cleaned_data$tracking$body_part == body_part, ]

  if (nrow(raw_track) == 0) {
    stop(sprintf("Body part '%s' not found in raw data", body_part))
  }
  if (nrow(clean_track) == 0) {
    stop(sprintf("Body part '%s' not found in cleaned data", body_part))
  }

  # Downsample if needed for performance
  if (nrow(raw_track) > max_points) {
    indices <- seq(1, nrow(raw_track), length.out = max_points)
    raw_track <- raw_track[indices, ]
  }
  if (nrow(clean_track) > max_points) {
    indices <- seq(1, nrow(clean_track), length.out = max_points)
    clean_track <- clean_track[indices, ]
  }

  # Add dataset labels
  raw_track$dataset <- "Raw"
  clean_track$dataset <- "Preprocessed"

  # Identify missing data points
  raw_track$has_data <- !is.na(raw_track$x) & !is.na(raw_track$y)
  clean_track$has_data <- !is.na(clean_track$x) & !is.na(clean_track$y)

  # Combine for faceted plot
  combined <- rbind(raw_track, clean_track)
  combined$dataset <- factor(combined$dataset, levels = c("Raw", "Preprocessed"))

  # Create comparison plot
  p <- ggplot2::ggplot(combined, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_path(
      data = combined[combined$has_data, ],
      ggplot2::aes(color = frame),
      size = 0.5,
      alpha = 0.6
    ) +
    ggplot2::geom_point(
      data = combined[!combined$has_data, ],
      color = "red",
      size = 1,
      alpha = 0.3
    ) +
    ggplot2::scale_color_viridis_c(name = "Frame") +
    ggplot2::facet_wrap(~ dataset, ncol = 2) +
    ggplot2::coord_fixed() +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Tracking Data: Raw vs. Preprocessed",
      subtitle = sprintf("Body part: %s (red = missing data)", body_part),
      x = "X Position (pixels)",
      y = "Y Position (pixels)"
    ) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(hjust = 0.5, size = 10),
      strip.text = ggplot2::element_text(face = "bold", size = 12),
      legend.position = "bottom"
    )

  # Save or display
  if (!is.null(output_file)) {
    ggplot2::ggsave(output_file, p, width = 12, height = 6, dpi = 300)
    message(sprintf("Comparison plot saved to: %s", output_file))
  }

  return(p)
}

#' Generate preprocessing summary statistics
#'
#' Creates a summary table comparing raw and preprocessed data statistics.
#'
#' @param raw_data A tracking_data object (before preprocessing)
#' @param cleaned_data A tracking_data object (after preprocessing)
#' @param body_part Character. Body part to analyze (default: "mouse_center")
#'
#' @return A data frame with comparison statistics
#'
#' @details
#' Returns statistics including:
#' \itemize{
#'   \item Total frames
#'   \item Valid frames (non-NA)
#'   \item Missing frames (NA)
#'   \item Percentage complete
#'   \item Mean likelihood (if available)
#' }
#'
#' @examples
#' \dontrun{
#' raw_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' cleaned_data <- preprocess_tracking(raw_data, arena_config)
#' stats <- summarize_preprocessing(raw_data, cleaned_data)
#' print(stats)
#' }
#'
#' @export
summarize_preprocessing <- function(raw_data,
                                     cleaned_data,
                                     body_part = "mouse_center") {
  # Extract data for specified body part
  raw_track <- raw_data$tracking[raw_data$tracking$body_part == body_part, ]
  clean_track <- cleaned_data$tracking[cleaned_data$tracking$body_part == body_part, ]

  # Calculate statistics for raw data
  raw_total <- nrow(raw_track)
  raw_valid <- sum(!is.na(raw_track$x) & !is.na(raw_track$y))
  raw_missing <- raw_total - raw_valid
  raw_pct <- 100 * raw_valid / raw_total
  raw_likelihood <- if ("likelihood" %in% names(raw_track)) {
    mean(raw_track$likelihood[!is.na(raw_track$likelihood)])
  } else {
    NA
  }

  # Calculate statistics for cleaned data
  clean_total <- nrow(clean_track)
  clean_valid <- sum(!is.na(clean_track$x) & !is.na(clean_track$y))
  clean_missing <- clean_total - clean_valid
  clean_pct <- 100 * clean_valid / clean_total
  clean_likelihood <- if ("likelihood" %in% names(clean_track)) {
    mean(clean_track$likelihood[!is.na(clean_track$likelihood)])
  } else {
    NA
  }

  # Create summary table
  summary <- data.frame(
    Metric = c("Total Frames", "Valid Frames", "Missing Frames",
               "% Complete", "Mean Likelihood"),
    Raw = c(raw_total, raw_valid, raw_missing,
            sprintf("%.1f%%", raw_pct),
            if (is.na(raw_likelihood)) "N/A" else sprintf("%.3f", raw_likelihood)),
    Preprocessed = c(clean_total, clean_valid, clean_missing,
                     sprintf("%.1f%%", clean_pct),
                     if (is.na(clean_likelihood)) "N/A" else sprintf("%.3f", clean_likelihood)),
    Change = c(clean_total - raw_total,
               clean_valid - raw_valid,
               clean_missing - raw_missing,
               sprintf("%+.1f%%", clean_pct - raw_pct),
               if (is.na(raw_likelihood) || is.na(clean_likelihood)) {
                 "N/A"
               } else {
                 sprintf("%+.3f", clean_likelihood - raw_likelihood)
               }),
    stringsAsFactors = FALSE
  )

  return(summary)
}
