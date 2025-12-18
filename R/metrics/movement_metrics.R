# R/metrics/movement_metrics.R
# Functions for calculating distance, velocity, and acceleration metrics

#' Calculate distance traveled
#'
#' Calculates the total distance traveled by an animal based on tracking data
#'
#' @param tracking_data tracking_data object
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param scale_factor Scale factor to convert pixels to cm (default: NULL, uses pixels)
#' @param by_zone Logical, calculate distance per zone (default: FALSE)
#' @param arena_config arena_config object, required if by_zone = TRUE
#'
#' @return Data frame with distance metrics or numeric value for total distance
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' total_dist <- calculate_distance_traveled(tracking_data)
#' dist_cm <- calculate_distance_traveled(tracking_data, scale_factor = 10)
#' }
calculate_distance_traveled <- function(tracking_data, body_part = "mouse_center",
                                       scale_factor = NULL, by_zone = FALSE,
                                       arena_config = NULL) {
  # Validate inputs
  if (!inherits(tracking_data, "tracking_data")) {
    stop("tracking_data must be a tracking_data object")
  }

  if (by_zone && is.null(arena_config)) {
    stop("arena_config must be provided when by_zone = TRUE")
  }

  # Extract tracking data for specified body part
  track_df <- tracking_data$tracking
  if (!body_part %in% track_df$body_part) {
    stop(sprintf("Body part '%s' not found in tracking data", body_part))
  }

  # Filter to body part and sort by frame
  track_df <- track_df[track_df$body_part == body_part, ]
  track_df <- track_df[order(track_df$frame), ]

  # Remove NA values
  valid_idx <- !is.na(track_df$x) & !is.na(track_df$y)
  track_df <- track_df[valid_idx, ]

  if (nrow(track_df) < 2) {
    warning("Insufficient valid tracking data points")
    return(0)
  }

  # Calculate distances between consecutive points
  dx <- diff(track_df$x)
  dy <- diff(track_df$y)
  distances <- sqrt(dx^2 + dy^2)

  # Apply scale factor if provided
  if (!is.null(scale_factor)) {
    distances <- distances / scale_factor
  }

  # Calculate by zone if requested
  if (by_zone) {
    # Classify points by zone
    classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

    # Calculate distance for each zone
    # Distance at frame i belongs to the zone at frame i
    zone_distances <- data.frame(
      frame = track_df$frame[-1],  # Exclude first frame (no distance)
      distance = distances,
      zone = classifications$zone[match(track_df$frame[-1], classifications$frame)]
    )

    # Sum by zone
    result <- aggregate(distance ~ zone, data = zone_distances, FUN = sum)
    colnames(result) <- c("zone_id", "total_distance")

    # Add units
    result$units <- if (!is.null(scale_factor)) "cm" else "pixels"

    return(result)
  } else {
    # Return total distance
    total_distance <- sum(distances)
    return(total_distance)
  }
}


#' Calculate velocity
#'
#' Calculates instantaneous velocity for each frame
#'
#' @param tracking_data tracking_data object
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param scale_factor Scale factor to convert pixels to cm (default: NULL)
#' @param smooth Logical, apply smoothing to velocity (default: TRUE)
#' @param smooth_window Window size for smoothing (default: 5)
#'
#' @return Data frame with columns: frame, time, velocity, velocity_x, velocity_y
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' velocity <- calculate_velocity(tracking_data, scale_factor = 10)
#' }
calculate_velocity <- function(tracking_data, body_part = "mouse_center",
                               scale_factor = NULL, smooth = TRUE,
                               smooth_window = 5) {
  # Validate inputs
  if (!inherits(tracking_data, "tracking_data")) {
    stop("tracking_data must be a tracking_data object")
  }

  # Extract tracking data for specified body part
  track_df <- tracking_data$tracking
  if (!body_part %in% track_df$body_part) {
    stop(sprintf("Body part '%s' not found in tracking data", body_part))
  }

  # Get FPS
  fps <- tracking_data$metadata$fps
  if (is.null(fps) || fps <= 0) {
    stop("Invalid or missing FPS in tracking_data metadata")
  }

  # Filter to body part and sort by frame
  track_df <- track_df[track_df$body_part == body_part, ]
  track_df <- track_df[order(track_df$frame), ]

  # Handle NA values
  valid_idx <- !is.na(track_df$x) & !is.na(track_df$y)

  # Calculate velocities
  # Initialize with NA
  velocity_x <- rep(NA, nrow(track_df))
  velocity_y <- rep(NA, nrow(track_df))
  velocity <- rep(NA, nrow(track_df))

  # Calculate for valid consecutive pairs
  for (i in 2:nrow(track_df)) {
    if (valid_idx[i] && valid_idx[i-1]) {
      # Calculate displacement
      dx <- track_df$x[i] - track_df$x[i-1]
      dy <- track_df$y[i] - track_df$y[i-1]

      # Calculate time difference
      dt <- (track_df$frame[i] - track_df$frame[i-1]) / fps

      if (dt > 0) {
        # Calculate velocity components
        velocity_x[i] <- dx / dt
        velocity_y[i] <- dy / dt

        # Calculate magnitude
        velocity[i] <- sqrt(velocity_x[i]^2 + velocity_y[i]^2)
      }
    }
  }

  # Apply scale factor if provided
  if (!is.null(scale_factor)) {
    velocity_x <- velocity_x / scale_factor
    velocity_y <- velocity_y / scale_factor
    velocity <- velocity / scale_factor
  }

  # Apply smoothing if requested
  if (smooth && smooth_window > 1) {
    velocity <- smooth_signal(velocity, window = smooth_window)
    velocity_x <- smooth_signal(velocity_x, window = smooth_window)
    velocity_y <- smooth_signal(velocity_y, window = smooth_window)
  }

  # Create result data frame
  result <- data.frame(
    frame = track_df$frame,
    time = track_df$time,
    velocity = velocity,
    velocity_x = velocity_x,
    velocity_y = velocity_y,
    stringsAsFactors = FALSE
  )

  # Add units as attribute
  units <- if (!is.null(scale_factor)) "cm/s" else "pixels/s"
  attr(result, "units") <- units

  return(result)
}


#' Calculate acceleration
#'
#' Calculates instantaneous acceleration for each frame
#'
#' @param tracking_data tracking_data object
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param scale_factor Scale factor to convert pixels to cm (default: NULL)
#' @param smooth Logical, apply smoothing (default: TRUE)
#' @param smooth_window Window size for smoothing (default: 5)
#'
#' @return Data frame with columns: frame, time, acceleration, acceleration_x, acceleration_y
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' accel <- calculate_acceleration(tracking_data, scale_factor = 10)
#' }
calculate_acceleration <- function(tracking_data, body_part = "mouse_center",
                                  scale_factor = NULL, smooth = TRUE,
                                  smooth_window = 5) {
  # First calculate velocity
  vel <- calculate_velocity(tracking_data, body_part, scale_factor,
                           smooth = smooth, smooth_window = smooth_window)

  # Get FPS
  fps <- tracking_data$metadata$fps

  # Calculate acceleration as derivative of velocity
  acceleration_x <- rep(NA, nrow(vel))
  acceleration_y <- rep(NA, nrow(vel))
  acceleration <- rep(NA, nrow(vel))

  for (i in 2:nrow(vel)) {
    if (!is.na(vel$velocity[i]) && !is.na(vel$velocity[i-1])) {
      # Time difference
      dt <- (vel$frame[i] - vel$frame[i-1]) / fps

      if (dt > 0) {
        # Calculate acceleration components
        acceleration_x[i] <- (vel$velocity_x[i] - vel$velocity_x[i-1]) / dt
        acceleration_y[i] <- (vel$velocity_y[i] - vel$velocity_y[i-1]) / dt

        # Calculate magnitude
        acceleration[i] <- sqrt(acceleration_x[i]^2 + acceleration_y[i]^2)
      }
    }
  }

  # Create result data frame
  result <- data.frame(
    frame = vel$frame,
    time = vel$time,
    acceleration = acceleration,
    acceleration_x = acceleration_x,
    acceleration_y = acceleration_y,
    stringsAsFactors = FALSE
  )

  # Add units as attribute
  units <- if (!is.null(scale_factor)) "cm/s^2" else "pixels/s^2"
  attr(result, "units") <- units

  return(result)
}


#' Calculate movement summary statistics
#'
#' Calculates comprehensive movement statistics
#'
#' @param tracking_data tracking_data object
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param scale_factor Scale factor to convert pixels to cm (default: NULL)
#'
#' @return Data frame with summary statistics
#'
#' @export
calculate_movement_summary <- function(tracking_data, body_part = "mouse_center",
                                      scale_factor = NULL) {
  # Calculate distance
  total_distance <- calculate_distance_traveled(tracking_data, body_part, scale_factor)

  # Calculate velocity
  vel <- calculate_velocity(tracking_data, body_part, scale_factor, smooth = TRUE)

  # Calculate basic statistics
  duration <- max(vel$time, na.rm = TRUE) - min(vel$time, na.rm = TRUE)
  mean_velocity <- mean(vel$velocity, na.rm = TRUE)
  max_velocity <- max(vel$velocity, na.rm = TRUE)
  median_velocity <- median(vel$velocity, na.rm = TRUE)

  # Calculate percentage of time moving (velocity > threshold)
  # Use 1 pixel/frame or 0.1 cm/frame as threshold
  movement_threshold <- if (!is.null(scale_factor)) 0.1 else 1.0
  pct_moving <- 100 * sum(vel$velocity > movement_threshold, na.rm = TRUE) / sum(!is.na(vel$velocity))

  # Create summary
  units_dist <- if (!is.null(scale_factor)) "cm" else "pixels"
  units_vel <- if (!is.null(scale_factor)) "cm/s" else "pixels/s"

  summary_df <- data.frame(
    total_distance = total_distance,
    distance_units = units_dist,
    mean_velocity = mean_velocity,
    median_velocity = median_velocity,
    max_velocity = max_velocity,
    velocity_units = units_vel,
    duration_seconds = duration,
    percent_time_moving = pct_moving,
    stringsAsFactors = FALSE
  )

  return(summary_df)
}


#' Detect movement bouts
#'
#' Identifies bouts of movement and immobility
#'
#' @param tracking_data tracking_data object
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param velocity_threshold Velocity threshold for movement (default: 1.0 pixel/s)
#' @param min_bout_duration Minimum bout duration in seconds (default: 0.5)
#' @param scale_factor Scale factor to convert pixels to cm (default: NULL)
#'
#' @return Data frame with bout information
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' bouts <- detect_movement_bouts(tracking_data, velocity_threshold = 2.0)
#' }
detect_movement_bouts <- function(tracking_data, body_part = "mouse_center",
                                  velocity_threshold = 1.0,
                                  min_bout_duration = 0.5,
                                  scale_factor = NULL) {
  # Calculate velocity
  vel <- calculate_velocity(tracking_data, body_part, scale_factor, smooth = TRUE)

  # Get FPS
  fps <- tracking_data$metadata$fps

  # Classify as moving or not
  is_moving <- vel$velocity > velocity_threshold
  is_moving[is.na(is_moving)] <- FALSE

  # Find transitions
  # Add FALSE at start to detect first bout
  is_moving_padded <- c(FALSE, is_moving, FALSE)
  transitions <- diff(as.integer(is_moving_padded))

  # Find bout starts (transitions from 0 to 1)
  bout_starts <- which(transitions == 1)

  # Find bout ends (transitions from 1 to 0)
  bout_ends <- which(transitions == -1) - 1

  if (length(bout_starts) == 0) {
    # No movement detected
    return(data.frame(
      bout_id = integer(0),
      bout_type = character(0),
      start_frame = integer(0),
      end_frame = integer(0),
      start_time = numeric(0),
      end_time = numeric(0),
      duration = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Create bout data frame
  bouts <- data.frame(
    bout_id = seq_along(bout_starts),
    bout_type = "movement",
    start_frame = vel$frame[bout_starts],
    end_frame = vel$frame[bout_ends],
    start_time = vel$time[bout_starts],
    end_time = vel$time[bout_ends],
    stringsAsFactors = FALSE
  )

  bouts$duration <- bouts$end_time - bouts$start_time

  # Filter by minimum duration
  bouts <- bouts[bouts$duration >= min_bout_duration, ]

  # Reset bout IDs
  bouts$bout_id <- seq_len(nrow(bouts))

  return(bouts)
}


#' Smooth signal using moving average
#'
#' Internal helper function to smooth a signal
#'
#' @param x Numeric vector
#' @param window Window size for moving average
#'
#' @return Smoothed vector
#'
#' @keywords internal
smooth_signal <- function(x, window = 5) {
  if (window <= 1 || length(x) < window) {
    return(x)
  }

  # Use moving average
  n <- length(x)
  smoothed <- rep(NA, n)

  half_window <- floor(window / 2)

  for (i in seq_along(x)) {
    if (is.na(x[i])) {
      smoothed[i] <- NA
    } else {
      # Define window bounds
      start_idx <- max(1, i - half_window)
      end_idx <- min(n, i + half_window)

      # Calculate mean of non-NA values in window
      window_vals <- x[start_idx:end_idx]
      smoothed[i] <- mean(window_vals, na.rm = TRUE)
    }
  }

  return(smoothed)
}
