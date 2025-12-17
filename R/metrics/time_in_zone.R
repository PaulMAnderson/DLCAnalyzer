#' Time in Zone Functions
#'
#' Functions for calculating zone entries, exits, latencies, and transitions.
#' These functions build on the zone classification system to analyze behavioral
#' patterns related to zone exploration.
#'
#' @name time_in_zone
NULL

#' Calculate zone entries
#'
#' Counts the number of times the animal enters each zone and calculates mean
#' duration of visits. An entry is defined as a transition from outside a zone
#' to inside the zone.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#' @param min_duration Numeric. Minimum duration (in seconds) for a visit to be counted
#'   as an entry. Visits shorter than this are ignored. Default is 0 (count all entries).
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item zone_id: Zone identifier
#'     \item n_entries: Number of entries into the zone
#'     \item mean_duration: Mean duration of visits (seconds)
#'     \item total_time: Total time spent in zone across all visits (seconds)
#'   }
#'   If body_part is NULL, also includes body_part column.
#'
#' @examples
#' \dontrun{
#' # Load tracking data and arena configuration
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#'
#' # Calculate all entries
#' entries <- calculate_zone_entries(tracking_data, arena)
#'
#' # Calculate entries with minimum duration filter (>= 1 second)
#' entries_filtered <- calculate_zone_entries(tracking_data, arena, min_duration = 1)
#' }
#'
#' @export
calculate_zone_entries <- function(tracking_data, arena_config, body_part = NULL,
                                    min_duration = 0) {
  # Validate inputs
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena_config)) {
    stop("arena_config must be an arena_config object", call. = FALSE)
  }

  if (!is.numeric(min_duration) || min_duration < 0) {
    stop("min_duration must be a non-negative number", call. = FALSE)
  }

  # Get fps from metadata
  fps <- tracking_data$metadata$fps
  if (is.null(fps) || !is.numeric(fps) || fps <= 0) {
    stop("tracking_data metadata must contain valid fps (frames per second)", call. = FALSE)
  }

  # Classify all points by zone
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  if (nrow(classifications) == 0) {
    return(data.frame(
      zone_id = character(0),
      n_entries = integer(0),
      mean_duration = numeric(0),
      total_time = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Determine if analyzing multiple body parts
  analyze_multiple_bp <- is.null(body_part)

  # Get unique body parts
  body_parts <- unique(classifications$body_part)

  # Initialize results list
  results_list <- list()

  for (bp in body_parts) {
    bp_data <- classifications[classifications$body_part == bp, ]

    # Sort by frame
    bp_data <- bp_data[order(bp_data$frame), ]

    # Get unique zones
    zones <- unique(bp_data$zone_id)
    zones <- zones[!is.na(zones)]  # Remove NA

    for (zone_id in zones) {
      # Create binary indicator: is point in this zone?
      bp_data$in_zone <- bp_data$zone_id == zone_id & !is.na(bp_data$zone_id)

      # Remove duplicate frames (can happen if point is in multiple zones)
      # For entries/exits, we consider a frame as "in zone" if it appears in that zone
      unique_frames <- !duplicated(bp_data$frame)
      bp_unique <- bp_data[unique_frames, ]

      # Detect entries: transition from FALSE to TRUE
      in_zone_vec <- bp_unique$in_zone
      n_frames <- length(in_zone_vec)

      if (n_frames < 2) {
        next  # Need at least 2 frames to detect transitions
      }

      # Find transitions using diff (compares consecutive elements)
      transitions <- diff(in_zone_vec)
      # Entry: FALSE -> TRUE (transition value = 1)
      # Exit: TRUE -> FALSE (transition value = -1)

      # diff(in_zone_vec) gives transitions[i] = in_zone_vec[i+1] - in_zone_vec[i]
      # So transition[i] == 1 means entry at frame i+1
      entry_indices <- which(transitions == 1) + 1
      exit_indices <- which(transitions == -1) + 1

      # Handle case where animal is in zone at start (frame 1)
      if (in_zone_vec[1]) {
        # Starts in zone - count as entry at frame 1
        entry_indices <- c(1, entry_indices)
      }

      # Handle case where animal is in zone at end
      if (in_zone_vec[n_frames]) {
        # Ends in zone - add an exit after last frame
        exit_indices <- c(exit_indices, n_frames + 1)
      }

      # Calculate visit durations
      if (length(entry_indices) == 0) {
        next  # No entries to this zone
      }

      visit_durations <- numeric(length(entry_indices))

      for (i in seq_along(entry_indices)) {
        entry_idx <- entry_indices[i]

        # Find corresponding exit
        exit_idx <- exit_indices[exit_indices > entry_idx][1]

        if (is.na(exit_idx)) {
          # No exit found (still in zone at end)
          exit_idx <- n_frames + 1
        }

        # Calculate duration in frames
        duration_frames <- exit_idx - entry_idx

        # Convert to seconds
        visit_durations[i] <- duration_frames / fps
      }

      # Apply minimum duration filter
      valid_visits <- visit_durations >= min_duration

      if (sum(valid_visits) == 0) {
        next  # No visits meet minimum duration
      }

      n_entries <- sum(valid_visits)
      total_time <- sum(visit_durations[valid_visits])
      mean_duration <- mean(visit_durations[valid_visits])

      # Store result
      result_row <- data.frame(
        zone_id = zone_id,
        n_entries = n_entries,
        mean_duration = mean_duration,
        total_time = total_time,
        stringsAsFactors = FALSE
      )

      if (analyze_multiple_bp) {
        result_row$body_part <- bp
        result_row <- result_row[, c("body_part", "zone_id", "n_entries", "mean_duration", "total_time")]
      }

      results_list[[paste(bp, zone_id, sep = "_")]] <- result_row
    }
  }

  if (length(results_list) == 0) {
    # No entries found
    if (analyze_multiple_bp) {
      return(data.frame(
        body_part = character(0),
        zone_id = character(0),
        n_entries = integer(0),
        mean_duration = numeric(0),
        total_time = numeric(0),
        stringsAsFactors = FALSE
      ))
    } else {
      return(data.frame(
        zone_id = character(0),
        n_entries = integer(0),
        mean_duration = numeric(0),
        total_time = numeric(0),
        stringsAsFactors = FALSE
      ))
    }
  }

  result <- do.call(rbind, results_list)
  rownames(result) <- NULL

  # Sort appropriately
  if (analyze_multiple_bp) {
    result <- result[order(result$body_part, result$zone_id), ]
  } else {
    result <- result[order(result$zone_id), ]
  }

  return(result)
}

#' Calculate zone exits
#'
#' Counts the number of times the animal exits each zone. An exit is defined as
#' a transition from inside a zone to outside the zone.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item zone_id: Zone identifier
#'     \item n_exits: Number of exits from the zone
#'   }
#'   If body_part is NULL, also includes body_part column.
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#' exits <- calculate_zone_exits(tracking_data, arena)
#' }
#'
#' @export
calculate_zone_exits <- function(tracking_data, arena_config, body_part = NULL) {
  # Validate inputs
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena_config)) {
    stop("arena_config must be an arena_config object", call. = FALSE)
  }

  # Classify all points by zone
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  if (nrow(classifications) == 0) {
    return(data.frame(
      zone_id = character(0),
      n_exits = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Determine if analyzing multiple body parts
  analyze_multiple_bp <- is.null(body_part)

  # Get unique body parts
  body_parts <- unique(classifications$body_part)

  # Initialize results list
  results_list <- list()

  for (bp in body_parts) {
    bp_data <- classifications[classifications$body_part == bp, ]

    # Sort by frame
    bp_data <- bp_data[order(bp_data$frame), ]

    # Get unique zones
    zones <- unique(bp_data$zone_id)
    zones <- zones[!is.na(zones)]  # Remove NA

    for (zone_id in zones) {
      # Create binary indicator
      bp_data$in_zone <- bp_data$zone_id == zone_id & !is.na(bp_data$zone_id)

      # Remove duplicate frames
      unique_frames <- !duplicated(bp_data$frame)
      bp_unique <- bp_data[unique_frames, ]

      # Detect exits: transition from TRUE to FALSE
      in_zone_vec <- bp_unique$in_zone
      n_frames <- length(in_zone_vec)

      if (n_frames < 2) {
        next
      }

      # Find transitions
      transitions <- diff(in_zone_vec)
      exit_indices <- which(transitions == -1)

      n_exits <- length(exit_indices)

      # Store result
      result_row <- data.frame(
        zone_id = zone_id,
        n_exits = n_exits,
        stringsAsFactors = FALSE
      )

      if (analyze_multiple_bp) {
        result_row$body_part <- bp
        result_row <- result_row[, c("body_part", "zone_id", "n_exits")]
      }

      results_list[[paste(bp, zone_id, sep = "_")]] <- result_row
    }
  }

  if (length(results_list) == 0) {
    if (analyze_multiple_bp) {
      return(data.frame(
        body_part = character(0),
        zone_id = character(0),
        n_exits = integer(0),
        stringsAsFactors = FALSE
      ))
    } else {
      return(data.frame(
        zone_id = character(0),
        n_exits = integer(0),
        stringsAsFactors = FALSE
      ))
    }
  }

  result <- do.call(rbind, results_list)
  rownames(result) <- NULL

  # Sort appropriately
  if (analyze_multiple_bp) {
    result <- result[order(result$body_part, result$zone_id), ]
  } else {
    result <- result[order(result$zone_id), ]
  }

  return(result)
}

#' Calculate zone entry latency
#'
#' Calculates the time from the start of tracking until the first entry into each zone.
#' Returns NA for zones that were never entered.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item zone_id: Zone identifier
#'     \item latency_seconds: Time to first entry (seconds), or NA if never entered
#'     \item first_entry_frame: Frame number of first entry, or NA if never entered
#'   }
#'   If body_part is NULL, also includes body_part column.
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#' latencies <- calculate_zone_latency(tracking_data, arena)
#' }
#'
#' @export
calculate_zone_latency <- function(tracking_data, arena_config, body_part = NULL) {
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

  # Classify all points by zone
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  if (nrow(classifications) == 0) {
    return(data.frame(
      zone_id = character(0),
      latency_seconds = numeric(0),
      first_entry_frame = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Determine if analyzing multiple body parts
  analyze_multiple_bp <- is.null(body_part)

  # Get all zone IDs from arena config
  all_zones <- sapply(arena_config$zones, function(z) z$id)

  # Get unique body parts
  body_parts <- unique(classifications$body_part)

  # Initialize results list
  results_list <- list()

  for (bp in body_parts) {
    bp_data <- classifications[classifications$body_part == bp, ]

    # Sort by frame
    bp_data <- bp_data[order(bp_data$frame), ]

    # For each zone in arena config
    for (zone_id in all_zones) {
      # Find first occurrence of this zone
      zone_frames <- bp_data$frame[bp_data$zone_id == zone_id & !is.na(bp_data$zone_id)]

      if (length(zone_frames) == 0) {
        # Never entered this zone
        latency_seconds <- NA_real_
        first_entry_frame <- NA_integer_
      } else {
        first_entry_frame <- min(zone_frames)
        latency_seconds <- first_entry_frame / fps
      }

      # Store result
      result_row <- data.frame(
        zone_id = zone_id,
        latency_seconds = latency_seconds,
        first_entry_frame = first_entry_frame,
        stringsAsFactors = FALSE
      )

      if (analyze_multiple_bp) {
        result_row$body_part <- bp
        result_row <- result_row[, c("body_part", "zone_id", "latency_seconds", "first_entry_frame")]
      }

      results_list[[paste(bp, zone_id, sep = "_")]] <- result_row
    }
  }

  result <- do.call(rbind, results_list)
  rownames(result) <- NULL

  # Sort appropriately
  if (analyze_multiple_bp) {
    result <- result[order(result$body_part, result$zone_id), ]
  } else {
    result <- result[order(result$zone_id), ]
  }

  return(result)
}

#' Calculate zone transitions
#'
#' Tracks all transitions between zones, creating a transition matrix showing
#' how many times the animal moved from one zone to another.
#'
#' @param tracking_data A tracking_data object
#' @param arena_config An arena_config object containing zone definitions
#' @param body_part Character. Specific body part to analyze (NULL analyzes all body parts)
#' @param min_duration Numeric. Minimum duration (in seconds) in a zone for it to count
#'   as a "visit". Brief entries (<min_duration) are ignored. Default is 0.
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item from_zone: Zone ID of origin (NA for points outside all zones)
#'     \item to_zone: Zone ID of destination (NA for points outside all zones)
#'     \item n_transitions: Number of transitions from from_zone to to_zone
#'   }
#'   If body_part is NULL, also includes body_part column.
#'
#' @examples
#' \dontrun{
#' tracking_data <- convert_dlc_to_tracking_data("data.csv", fps = 30)
#' arena <- load_arena_config("arena.yaml")
#'
#' # All transitions
#' transitions <- calculate_zone_transitions(tracking_data, arena)
#'
#' # Only transitions after staying >= 1 second
#' transitions_filtered <- calculate_zone_transitions(tracking_data, arena, min_duration = 1)
#' }
#'
#' @export
calculate_zone_transitions <- function(tracking_data, arena_config, body_part = NULL,
                                       min_duration = 0) {
  # Validate inputs
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena_config)) {
    stop("arena_config must be an arena_config object", call. = FALSE)
  }

  if (!is.numeric(min_duration) || min_duration < 0) {
    stop("min_duration must be a non-negative number", call. = FALSE)
  }

  # Get fps from metadata
  fps <- tracking_data$metadata$fps
  if (is.null(fps) || !is.numeric(fps) || fps <= 0) {
    stop("tracking_data metadata must contain valid fps (frames per second)", call. = FALSE)
  }

  # Classify all points by zone
  classifications <- classify_points_by_zone(tracking_data, arena_config, body_part)

  if (nrow(classifications) == 0) {
    return(data.frame(
      from_zone = character(0),
      to_zone = character(0),
      n_transitions = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Determine if analyzing multiple body parts
  analyze_multiple_bp <- is.null(body_part)

  # Get unique body parts
  body_parts <- unique(classifications$body_part)

  # Initialize results list
  results_list <- list()

  for (bp in body_parts) {
    bp_data <- classifications[classifications$body_part == bp, ]

    # Sort by frame
    bp_data <- bp_data[order(bp_data$frame), ]

    # Remove duplicate frames (keep first zone if in multiple)
    # For transitions, we use the first zone encountered at each frame
    unique_frames_idx <- !duplicated(bp_data$frame)
    bp_unique <- bp_data[unique_frames_idx, ]

    # If min_duration > 0, filter out brief visits
    if (min_duration > 0) {
      # Run-length encoding to find continuous stays in each zone
      zone_rle <- rle(as.character(bp_unique$zone_id))

      # Calculate duration of each run in seconds
      run_durations <- zone_rle$lengths / fps

      # Keep only runs meeting minimum duration
      keep_runs <- run_durations >= min_duration

      # Reconstruct filtered sequence
      filtered_zones <- rep(zone_rle$values[keep_runs],
                           times = zone_rle$lengths[keep_runs])

      if (length(filtered_zones) < 2) {
        next  # No valid transitions for this body part
      }

      # Detect transitions in filtered sequence
      from_zones <- filtered_zones[-length(filtered_zones)]
      to_zones <- filtered_zones[-1]

      # Only count transitions where zone actually changes
      # Handle NA comparisons: NA != NA should be TRUE (a transition)
      transitions_occurred <- !mapply(identical, from_zones, to_zones)
      from_zones <- from_zones[transitions_occurred]
      to_zones <- to_zones[transitions_occurred]

    } else {
      # No minimum duration filter
      # Detect all zone changes
      zone_sequence <- as.character(bp_unique$zone_id)

      if (length(zone_sequence) < 2) {
        next
      }

      from_zones <- zone_sequence[-length(zone_sequence)]
      to_zones <- zone_sequence[-1]

      # Only count transitions where zone changes
      # Handle NA comparisons properly
      transitions_occurred <- !mapply(identical, from_zones, to_zones)
      from_zones <- from_zones[transitions_occurred]
      to_zones <- to_zones[transitions_occurred]
    }

    if (length(from_zones) == 0) {
      next  # No transitions for this body part
    }

    # Count each unique transition manually to handle NA values properly
    # table() with useNA doesn't work well for indexing later
    for (i in seq_along(from_zones)) {
      from_z <- from_zones[i]
      to_z <- to_zones[i]

      # Create key for this transition (handle NA values)
      key <- paste(bp,
                  ifelse(is.na(from_z), "NA_from", from_z),
                  ifelse(is.na(to_z), "NA_to", to_z),
                  sep = "_")

      if (is.null(results_list[[key]])) {
        # First time seeing this transition
        result_row <- data.frame(
          from_zone = from_z,
          to_zone = to_z,
          n_transitions = 1L,
          stringsAsFactors = FALSE
        )

        if (analyze_multiple_bp) {
          result_row$body_part <- bp
          result_row <- result_row[, c("body_part", "from_zone", "to_zone", "n_transitions")]
        }

        results_list[[key]] <- result_row
      } else {
        # Increment count
        results_list[[key]]$n_transitions <- results_list[[key]]$n_transitions + 1L
      }
    }
  }

  if (length(results_list) == 0) {
    if (analyze_multiple_bp) {
      return(data.frame(
        body_part = character(0),
        from_zone = character(0),
        to_zone = character(0),
        n_transitions = integer(0),
        stringsAsFactors = FALSE
      ))
    } else {
      return(data.frame(
        from_zone = character(0),
        to_zone = character(0),
        n_transitions = integer(0),
        stringsAsFactors = FALSE
      ))
    }
  }

  result <- do.call(rbind, results_list)
  rownames(result) <- NULL

  # Sort appropriately
  if (analyze_multiple_bp) {
    result <- result[order(result$body_part, result$from_zone, result$to_zone), ]
  } else {
    result <- result[order(result$from_zone, result$to_zone), ]
  }

  return(result)
}
