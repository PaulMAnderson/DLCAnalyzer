#' Zone Analysis Functions
#'
#' Functions for classifying tracking points into zones and calculating zone occupancy.
#' These functions integrate with the arena configuration system to analyze time
#' spent in different regions of the arena.
#'
#' @name zone_analysis
NULL

#' Classify tracking points by zone
#'
#' For each tracking point in the dataset, determines which zone(s) it belongs to.
#' Uses the existing zone geometry system to perform point-in-zone testing.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item frame: Frame number
#'     \item body_part: Body part name
#'     \item x: X coordinate
#'     \item y: Y coordinate
#'     \item zone_id: Zone identifier (NA if point is not in any zone)
#'   }
#'   Note: If a point is in multiple overlapping zones, multiple rows are returned
#'   for that point (one per zone).
#'
#' @examples
#' \dontrun{
#' # Load tracking data and arena configuration
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#'
#' # Classify all points
#' classifications <- classify_points_by_zone(tracking_data, arena)
#'
#' # Classify only one body part
#' nose_zones <- classify_points_by_zone(tracking_data, arena, body_part = "nose")
#' }
#'
#' @export
classify_points_by_zone <- function(tracking_data, arena_config, body_part = NULL) {
  # Validate inputs
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena_config)) {
    stop("arena_config must be an arena_config object", call. = FALSE)
  }

  if (is.null(arena_config$zones) || length(arena_config$zones) == 0) {
    stop("arena_config has no zones defined", call. = FALSE)
  }

  # Filter to specific body part if requested
  tracking_df <- tracking_data$tracking

  if (!is.null(body_part)) {
    if (!body_part %in% unique(tracking_df$body_part)) {
      stop("Body part '", body_part, "' not found in tracking data", call. = FALSE)
    }
    tracking_df <- tracking_df[tracking_df$body_part == body_part, ]
  }

  # Create all zone geometries
  zone_geometries <- create_all_zone_geometries(arena_config)

  # Initialize results list
  results_list <- list()

  # For each zone, identify which points are inside
  for (zone_id in names(zone_geometries)) {
    geometry <- zone_geometries[[zone_id]]

    # Test all points against this zone
    in_zone <- point_in_zone(tracking_df$x, tracking_df$y, geometry)

    # Create data frame for points in this zone
    if (any(in_zone, na.rm = TRUE)) {
      zone_data <- data.frame(
        frame = tracking_df$frame[in_zone],
        body_part = tracking_df$body_part[in_zone],
        x = tracking_df$x[in_zone],
        y = tracking_df$y[in_zone],
        zone_id = zone_id,
        stringsAsFactors = FALSE
      )

      results_list[[zone_id]] <- zone_data
    }
  }

  # Combine all zone classifications
  if (length(results_list) == 0) {
    # No points in any zone - return empty data frame with correct structure
    result <- data.frame(
      frame = integer(0),
      body_part = character(0),
      x = numeric(0),
      y = numeric(0),
      zone_id = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    result <- do.call(rbind, results_list)
    rownames(result) <- NULL
  }

  # Add rows for points NOT in any zone
  # First, find which frame/body_part combinations are classified
  if (nrow(result) > 0) {
    classified_points <- paste(result$frame, result$body_part, sep = "_")
  } else {
    classified_points <- character(0)
  }

  all_points <- paste(tracking_df$frame, tracking_df$body_part, sep = "_")
  unclassified_idx <- which(!all_points %in% classified_points)

  if (length(unclassified_idx) > 0) {
    unclassified_data <- data.frame(
      frame = tracking_df$frame[unclassified_idx],
      body_part = tracking_df$body_part[unclassified_idx],
      x = tracking_df$x[unclassified_idx],
      y = tracking_df$y[unclassified_idx],
      zone_id = NA_character_,
      stringsAsFactors = FALSE
    )

    result <- rbind(result, unclassified_data)
  }

  # Sort by frame and body part
  result <- result[order(result$frame, result$body_part), ]
  rownames(result) <- NULL

  return(result)
}

#' Calculate zone occupancy
#'
#' Calculates the total time and percentage of time spent in each zone.
#' Uses the frame rate from tracking metadata to convert frames to time.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item zone_id: Zone identifier
#'     \item n_frames: Number of frames in zone
#'     \item time_seconds: Total time in zone (seconds)
#'     \item percentage: Percentage of total time spent in zone
#'   }
#'   If body_part is NULL, also includes:
#'   \itemize{
#'     \item body_part: Body part name
#'   }
#'
#' @examples
#' \dontrun{
#' # Load tracking data and arena configuration
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#'
#' # Calculate occupancy for all body parts
#' occupancy <- calculate_zone_occupancy(tracking_data, arena)
#'
#' # Calculate occupancy for specific body part
#' nose_occupancy <- calculate_zone_occupancy(tracking_data, arena, body_part = "nose")
#' }
#'
#' @export
calculate_zone_occupancy <- function(tracking_data, arena_config, body_part = NULL) {
  # Validate inputs
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena_config)) {
    stop("arena_config must be an arena_config object", call. = FALSE)
  }

  # Get fps from metadata
  fps <- tracking_data$metadata$fps
  if (is.null(fps) || !is.numeric(fps) || fps <= 0) {
    stop("tracking_data metadata must contain valid fps (frames per second)", call. = FALSE)
  }

  # Classify points by zone
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  # Handle case where no points were classified
  if (nrow(classifications) == 0) {
    return(data.frame(
      zone_id = character(0),
      n_frames = integer(0),
      time_seconds = numeric(0),
      percentage = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Determine if we're analyzing multiple body parts
  analyze_multiple_bp <- is.null(body_part)

  if (analyze_multiple_bp) {
    # Group by zone_id and body_part
    grouping_vars <- c("zone_id", "body_part")
  } else {
    # Group by zone_id only
    grouping_vars <- "zone_id"
  }

  # Calculate occupancy for each zone
  # Remove NA zone_id for counting (but keep for calculating total)
  classifications_valid <- classifications[!is.na(classifications$zone_id), ]

  if (nrow(classifications_valid) == 0) {
    # All points are outside zones
    return(data.frame(
      zone_id = character(0),
      n_frames = integer(0),
      time_seconds = numeric(0),
      percentage = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Count frames per zone (handling overlapping zones properly)
  # If a point is in multiple zones, it's counted in each
  # But for percentage, we use total unique frames

  if (analyze_multiple_bp) {
    # For each body part separately
    occupancy_list <- list()

    for (bp in unique(classifications_valid$body_part)) {
      bp_data <- classifications_valid[classifications_valid$body_part == bp, ]

      # Count frames per zone
      zone_counts <- table(bp_data$zone_id)

      # Get total frames for this body part (unique frames)
      bp_all <- classifications[classifications$body_part == bp, ]
      total_frames <- length(unique(bp_all$frame))

      # Create summary
      for (zone_id in names(zone_counts)) {
        n_frames <- as.integer(zone_counts[zone_id])
        time_seconds <- n_frames / fps
        percentage <- (n_frames / total_frames) * 100

        occupancy_list[[paste(bp, zone_id, sep = "_")]] <- data.frame(
          body_part = bp,
          zone_id = zone_id,
          n_frames = n_frames,
          time_seconds = time_seconds,
          percentage = percentage,
          stringsAsFactors = FALSE
        )
      }
    }

    occupancy <- do.call(rbind, occupancy_list)
    rownames(occupancy) <- NULL

    # Reorder columns
    occupancy <- occupancy[, c("body_part", "zone_id", "n_frames", "time_seconds", "percentage")]

  } else {
    # Single body part analysis
    zone_counts <- table(classifications_valid$zone_id)

    # Total frames (unique)
    total_frames <- length(unique(classifications$frame))

    # Create summary data frame
    occupancy <- data.frame(
      zone_id = names(zone_counts),
      n_frames = as.integer(zone_counts),
      stringsAsFactors = FALSE
    )

    occupancy$time_seconds <- occupancy$n_frames / fps
    occupancy$percentage <- (occupancy$n_frames / total_frames) * 100
  }

  # Sort by zone_id (and body_part if present)
  if (analyze_multiple_bp) {
    occupancy <- occupancy[order(occupancy$body_part, occupancy$zone_id), ]
  } else {
    occupancy <- occupancy[order(occupancy$zone_id), ]
  }

  rownames(occupancy) <- NULL

  return(occupancy)
}
