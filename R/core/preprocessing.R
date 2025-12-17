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
    part_idx <- result$tracking$body_part == part

    # Extract data for this body part (must be in frame order)
    part_data <- result$tracking[part_idx, , drop = FALSE]
    part_data <- part_data[order(part_data$frame), ]

    # Count NAs before interpolation
    na_x_before <- sum(is.na(part_data$x))
    na_y_before <- sum(is.na(part_data$y))
    n_total_na <- n_total_na + na_x_before + na_y_before

    # Interpolate x and y separately
    part_data$x <- interpolate_vector(part_data$x, method, max_gap)
    part_data$y <- interpolate_vector(part_data$y, method, max_gap)

    # Count NAs after interpolation
    na_x_after <- sum(is.na(part_data$x))
    na_y_after <- sum(is.na(part_data$y))
    n_interpolated <- n_interpolated + (na_x_before - na_x_after) + (na_y_before - na_y_after)

    # Put data back into result
    result$tracking[part_idx, ] <- part_data
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
    part_idx <- result$tracking$body_part == part

    # Extract data for this body part (must be in frame order)
    part_data <- result$tracking[part_idx, , drop = FALSE]
    part_data <- part_data[order(part_data$frame), ]

    # Smooth x and y separately
    if (method == "savgol") {
      part_data$x <- smooth_savgol(part_data$x, window, polynomial)
      part_data$y <- smooth_savgol(part_data$y, window, polynomial)
    } else if (method == "ma") {
      part_data$x <- smooth_ma(part_data$x, window)
      part_data$y <- smooth_ma(part_data$y, window)
    } else if (method == "gaussian") {
      part_data$x <- smooth_gaussian(part_data$x, window, sigma)
      part_data$y <- smooth_gaussian(part_data$y, window, sigma)
    }

    # Put data back into result
    result$tracking[part_idx, ] <- part_data
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
