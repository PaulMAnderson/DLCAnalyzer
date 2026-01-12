#' NORT (Novel Object Recognition Test) Analysis Functions
#'
#' Functions for analyzing NORT behavioral metrics with memory discrimination indices.
#'
#' @name nort_analysis
NULL

#' Calculate Discrimination Index (DI)
#'
#' The Discrimination Index measures novelty preference in memory tasks.
#' DI = (Time_Novel - Time_Familiar) / (Time_Novel + Time_Familiar)
#'
#' @param novel_time Numeric. Time exploring novel object (seconds)
#' @param familiar_time Numeric. Time exploring familiar object (seconds)
#'
#' @return Numeric. Discrimination Index ranging from -1 to +1:
#'   \itemize{
#'     \item +1: Only explored novel object (perfect novelty preference)
#'     \item 0: Equal exploration (no preference)
#'     \item -1: Only explored familiar object (familiarity preference/neophobia)
#'     \item NA: No exploration of either object
#'   }
#'
#' Interpretation:
#'   \itemize{
#'     \item DI > 0.2: Intact memory (novelty preference)
#'     \item DI ~ 0: No discrimination
#'     \item DI < -0.1: Familiarity preference or neophobia
#'   }
#'
#' @examples
#' \dontrun{
#' di <- calculate_discrimination_index(novel_time = 15.2, familiar_time = 8.3)
#' # DI = 0.297 (novelty preference, intact memory)
#' }
#'
#' @export
calculate_discrimination_index <- function(novel_time, familiar_time) {
  total_time <- novel_time + familiar_time

  if (is.na(total_time) || total_time == 0) {
    return(NA_real_)
  }

  di <- (novel_time - familiar_time) / total_time

  return(di)
}

#' Calculate Preference Score
#'
#' Preference score as a percentage of time with novel object.
#' Preference = (Time_Novel / Total_Exploration) × 100
#'
#' @param novel_time Numeric. Time exploring novel object (seconds)
#' @param familiar_time Numeric. Time exploring familiar object (seconds)
#'
#' @return Numeric. Preference score as percentage (0-100):
#'   \itemize{
#'     \item 100: Only explored novel object
#'     \item 50: Equal exploration
#'     \item 0: Only explored familiar object
#'     \item NA: No exploration
#'   }
#'
#' @examples
#' \dontrun{
#' pref <- calculate_preference_score(novel_time = 15.2, familiar_time = 8.3)
#' # Preference = 64.7% (novelty preference)
#' }
#'
#' @export
calculate_preference_score <- function(novel_time, familiar_time) {
  total_time <- novel_time + familiar_time

  if (is.na(total_time) || total_time == 0) {
    return(NA_real_)
  }

  preference <- (novel_time / total_time) * 100

  return(preference)
}

#' Calculate Recognition Index
#'
#' Recognition index as ratio of novel exploration to total.
#' Similar to preference score but as a 0-1 ratio.
#'
#' @param novel_time Numeric. Time exploring novel object (seconds)
#' @param total_time Numeric. Total exploration time (seconds)
#'
#' @return Numeric. Recognition index (0-1)
#'
#' @export
calculate_recognition_index <- function(novel_time, total_time) {
  if (is.na(total_time) || total_time == 0) {
    return(NA_real_)
  }

  recognition <- novel_time / total_time

  return(recognition)
}

#' Check if NORT trial has valid exploration
#'
#' Determines if a trial meets minimum exploration criteria for valid analysis.
#'
#' @param total_exploration_time Numeric. Total exploration time (seconds)
#' @param min_threshold Numeric. Minimum required exploration (default: 10 seconds)
#'
#' @return Logical. TRUE if trial is valid, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' is_valid <- is_valid_nort_trial(total_exploration_time = 23.5, min_threshold = 10)
#' # TRUE - sufficient exploration
#'
#' is_valid <- is_valid_nort_trial(total_exploration_time = 5.2, min_threshold = 10)
#' # FALSE - insufficient exploration
#' }
#'
#' @export
is_valid_nort_trial <- function(total_exploration_time, min_threshold = 10) {
  if (is.na(total_exploration_time)) {
    return(FALSE)
  }

  return(total_exploration_time >= min_threshold)
}

#' Analyze NORT behavioral metrics
#'
#' Comprehensive analysis of Novel Object Recognition Test behavior including
#' discrimination index, preference scores, and exploration patterns.
#'
#' @param df Data frame. NORT tracking data with zone columns (from load_nort_data)
#' @param fps Numeric. Frames per second (default: 25)
#' @param novel_side Character. Which side is novel: "left" or "right" (default: "left")
#' @param body_part Character. Body part to use for distance ("center", "nose")
#'   (default: "center" for locomotion)
#' @param min_exploration Numeric. Minimum exploration time for valid trial (default: 10 sec)
#'
#' @return A list with NORT metrics:
#'   \describe{
#'     \item{novel_object_time_sec}{Numeric. Time exploring novel object}
#'     \item{familiar_object_time_sec}{Numeric. Time exploring familiar object}
#'     \item{total_exploration_sec}{Numeric. Total object exploration time}
#'     \item{discrimination_index}{Numeric. DI (-1 to +1)}
#'     \item{preference_score}{Numeric. Preference percentage (0-100)}
#'     \item{recognition_index}{Numeric. Recognition ratio (0-1)}
#'     \item{novel_entries}{Integer. Approaches to novel object}
#'     \item{familiar_entries}{Integer. Approaches to familiar object}
#'     \item{total_distance_cm}{Numeric. Total distance traveled}
#'     \item{avg_velocity_cm_s}{Numeric. Average velocity}
#'     \item{time_in_center_sec}{Numeric. Time in center zone}
#'     \item{is_valid_trial}{Logical. Meets minimum exploration criteria}
#'     \item{novel_side}{Character. Which side was novel}
#'     \item{total_duration_sec}{Numeric. Trial duration}
#'   }
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx", novel_side = "left")
#' results <- analyze_nort(nort_data$Arena_1$data, fps = 25, novel_side = "left")
#' print(results$discrimination_index)
#' }
#'
#' @export
analyze_nort <- function(df, fps = 25, novel_side = "left", body_part = "center",
                        min_exploration = 10) {
  # Validate inputs
  if (!is.data.frame(df)) {
    stop("df must be a data frame", call. = FALSE)
  }

  novel_side <- tolower(novel_side)
  if (!novel_side %in% c("left", "right")) {
    stop("novel_side must be 'left' or 'right'", call. = FALSE)
  }

  # Determine zone names based on novel side
  if (novel_side == "left") {
    novel_zone <- "zone_round_object_left"
    familiar_zone <- "zone_round_object_right"
  } else {
    novel_zone <- "zone_round_object_right"
    familiar_zone <- "zone_round_object_left"
  }

  # Check that object zones exist
  if (!novel_zone %in% colnames(df)) {
    stop("Novel object zone '", novel_zone, "' not found in data", call. = FALSE)
  }
  if (!familiar_zone %in% colnames(df)) {
    stop("Familiar object zone '", familiar_zone, "' not found in data", call. = FALSE)
  }

  # Source zone utility functions from ld_analysis if available
  if (!exists("calculate_zone_time")) {
    stop("This function requires zone utility functions from R/ld/ld_analysis.R. ",
         "Please ensure the package is properly installed.", call. = FALSE)
  }

  # Calculate object exploration times (using nose-point zones)
  novel_time <- calculate_zone_time(df[[novel_zone]], fps)
  familiar_time <- calculate_zone_time(df[[familiar_zone]], fps)
  total_exploration <- novel_time + familiar_time

  # Calculate memory discrimination indices
  di <- calculate_discrimination_index(novel_time, familiar_time)
  preference <- calculate_preference_score(novel_time, familiar_time)
  recognition <- calculate_recognition_index(novel_time, total_exploration)

  # Count approaches to objects
  novel_entries <- detect_zone_entries(df[[novel_zone]])
  familiar_entries <- detect_zone_entries(df[[familiar_zone]])

  # Calculate locomotor activity (using center-point coordinates)
  x_col <- paste0("x_", body_part)
  y_col <- paste0("y_", body_part)

  if (!x_col %in% colnames(df) || !y_col %in% colnames(df)) {
    warning("Coordinates for body part '", body_part, "' not found. ",
            "Locomotion metrics will be NA.", call. = FALSE)
    total_distance <- NA_real_
    avg_velocity <- NA_real_
  } else {
    x <- df[[x_col]]
    y <- df[[y_col]]

    # Calculate distance
    if (length(x) > 1) {
      dx <- diff(x)
      dy <- diff(y)
      distances <- sqrt(dx^2 + dy^2)
      total_distance <- sum(distances, na.rm = TRUE)
    } else {
      total_distance <- 0
    }

    # Calculate average velocity
    trial_duration <- max(df$time, na.rm = TRUE) - min(df$time, na.rm = TRUE)
    avg_velocity <- total_distance / trial_duration
  }

  # Time in center zone (using center-point zones)
  center_zone_col <- grep("^zone_center", colnames(df), value = TRUE)[1]
  if (!is.na(center_zone_col) && center_zone_col %in% colnames(df)) {
    time_in_center <- calculate_zone_time(df[[center_zone_col]], fps)
  } else {
    time_in_center <- NA_real_
  }

  # Check trial validity
  is_valid <- is_valid_nort_trial(total_exploration, min_threshold = min_exploration)

  if (!is_valid) {
    warning("Trial has low exploration time (", round(total_exploration, 2),
            " sec). Minimum recommended: ", min_exploration, " sec.",
            call. = FALSE)
  }

  # Package results
  results <- list(
    novel_object_time_sec = round(novel_time, 2),
    familiar_object_time_sec = round(familiar_time, 2),
    total_exploration_sec = round(total_exploration, 2),
    discrimination_index = round(di, 3),
    preference_score = round(preference, 2),
    recognition_index = round(recognition, 3),
    novel_entries = novel_entries,
    familiar_entries = familiar_entries,
    total_distance_cm = round(total_distance, 2),
    avg_velocity_cm_s = round(avg_velocity, 2),
    time_in_center_sec = round(time_in_center, 2),
    is_valid_trial = is_valid,
    novel_side = novel_side,
    total_duration_sec = round(max(df$time, na.rm = TRUE), 2)
  )

  return(results)
}

#' Analyze batch of NORT arenas
#'
#' Analyzes multiple arenas from NORT data and returns results as a data frame.
#'
#' @param nort_data List. Output from load_nort_data()
#' @param fps Numeric. Frames per second (default: 25)
#' @param novel_sides Character vector. Novel side for each arena ("left" or "right").
#'   If NULL, uses novel_side from each arena's metadata. If a single value, applies to all.
#' @param body_part Character. Body part for distance calculations (default: "center")
#' @param min_exploration Numeric. Minimum exploration time for valid trial (default: 10 sec)
#'
#' @return Data frame with one row per arena containing all NORT metrics
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx", novel_side = "left")
#' results <- analyze_nort_batch(nort_data, novel_sides = c("left", "left", "right", "left"))
#' print(results[, c("arena_name", "discrimination_index", "preference_score")])
#' }
#'
#' @export
analyze_nort_batch <- function(nort_data, fps = 25, novel_sides = NULL,
                               body_part = "center", min_exploration = 10) {
  if (!is.list(nort_data) || length(nort_data) == 0) {
    stop("nort_data must be a non-empty list from load_nort_data()", call. = FALSE)
  }

  arena_names <- names(nort_data)
  n_arenas <- length(arena_names)

  # Determine novel_sides for each arena
  if (is.null(novel_sides)) {
    # Use novel_side from metadata
    novel_sides <- sapply(arena_names, function(an) {
      ns <- nort_data[[an]]$novel_side
      if (is.null(ns)) "left" else ns
    })
  } else if (length(novel_sides) == 1) {
    # Single value - apply to all
    novel_sides <- rep(novel_sides, n_arenas)
  } else if (length(novel_sides) != n_arenas) {
    stop("novel_sides must be NULL, a single value, or have length equal to number of arenas (",
         n_arenas, ")", call. = FALSE)
  }

  # Analyze each arena
  results_list <- list()

  for (i in seq_along(arena_names)) {
    arena_name <- arena_names[i]
    arena_data <- nort_data[[arena_name]]
    novel_side <- novel_sides[i]

    message("Analyzing ", arena_name, " (novel side: ", novel_side, ")...")

    tryCatch({
      results <- analyze_nort(
        df = arena_data$data,
        fps = fps,
        novel_side = novel_side,
        body_part = body_part,
        min_exploration = min_exploration
      )

      # Add arena identification
      results$arena_name <- arena_name
      results$arena_id <- arena_data$arena_id
      results$subject_id <- arena_data$subject_id

      results_list[[arena_name]] <- results
    }, error = function(e) {
      warning("Error analyzing ", arena_name, ": ", e$message, call. = FALSE)
      results_list[[arena_name]] <<- NULL
    })
  }

  # Convert to data frame
  if (length(results_list) == 0) {
    stop("No arenas were successfully analyzed", call. = FALSE)
  }

  results_df <- do.call(rbind, lapply(results_list, as.data.frame, stringsAsFactors = FALSE))
  rownames(results_df) <- NULL

  # Reorder columns for readability
  priority_cols <- c("arena_name", "arena_id", "subject_id", "novel_side",
                     "discrimination_index", "preference_score", "recognition_index",
                     "novel_object_time_sec", "familiar_object_time_sec",
                     "total_exploration_sec", "is_valid_trial")
  priority_cols <- priority_cols[priority_cols %in% colnames(results_df)]
  other_cols <- setdiff(colnames(results_df), priority_cols)

  results_df <- results_df[, c(priority_cols, other_cols)]

  return(results_df)
}

#' Export NORT results to CSV
#'
#' Saves NORT analysis results to a CSV file.
#'
#' @param results Data frame. Output from analyze_nort_batch()
#' @param output_file Character. Path to output CSV file
#'
#' @return Invisible. Writes file to disk
#'
#' @examples
#' \dontrun{
#' results <- analyze_nort_batch(nort_data)
#' export_nort_results(results, "nort_results.csv")
#' }
#'
#' @export
export_nort_results <- function(results, output_file) {
  if (!is.data.frame(results)) {
    stop("results must be a data frame", call. = FALSE)
  }

  # Create output directory if needed
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Write CSV
  write.csv(results, output_file, row.names = FALSE)

  message("Results exported to: ", output_file)

  invisible(output_file)
}

#' Interpret NORT discrimination index
#'
#' Provides behavioral interpretation of discrimination index values.
#'
#' @param di Numeric. Discrimination index value
#'
#' @return Character. Interpretation string
#'
#' @examples
#' \dontrun{
#' interpret_nort_di(0.45)
#' # "Strong novelty preference - intact memory"
#'
#' interpret_nort_di(0.05)
#' # "Weak/no discrimination - impaired memory or no learning"
#' }
#'
#' @keywords internal
interpret_nort_di <- function(di) {
  if (is.na(di)) {
    return("No exploration - cannot assess memory")
  } else if (di > 0.3) {
    return("Strong novelty preference - intact memory")
  } else if (di > 0.1) {
    return("Moderate novelty preference - likely intact memory")
  } else if (di >= -0.1) {
    return("Weak/no discrimination - impaired memory or no learning")
  } else {
    return("Familiarity preference - possible neophobia or alternate strategy")
  }
}
