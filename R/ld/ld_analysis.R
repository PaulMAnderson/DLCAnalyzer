#' LD (Light/Dark Box) Analysis Functions
#'
#' Functions for analyzing Light/Dark box behavioral metrics using zone data.
#'
#' @name ld_analysis
NULL

#' Calculate time in zone
#'
#' Calculates total time spent in a zone from binary zone vector.
#'
#' @param zone_vector Numeric vector. Binary (0/1) zone membership
#' @param fps Numeric. Frames per second
#'
#' @return Numeric. Time in seconds
#'
#' @examples
#' \dontrun{
#' zone_data <- c(0, 0, 1, 1, 1, 0, 1)
#' time_in_zone <- calculate_zone_time(zone_data, fps = 25)
#' }
#'
#' @export
calculate_zone_time <- function(zone_vector, fps) {
  if (!is.numeric(zone_vector) || !is.numeric(fps) || fps <= 0) {
    stop("zone_vector must be numeric and fps must be positive", call. = FALSE)
  }

  # Count frames where zone == 1
  frames_in_zone <- sum(zone_vector == 1, na.rm = TRUE)

  # Convert to seconds
  time_seconds <- frames_in_zone / fps

  return(time_seconds)
}

#' Detect zone entries
#'
#' Counts the number of entries into a zone (transitions from 0 to 1).
#'
#' @param zone_vector Numeric vector. Binary (0/1) zone membership
#'
#' @return Integer. Number of entries
#'
#' @examples
#' \dontrun{
#' zone_data <- c(0, 0, 1, 1, 1, 0, 1, 1, 0)
#' entries <- detect_zone_entries(zone_data)  # Returns 2
#' }
#'
#' @export
detect_zone_entries <- function(zone_vector) {
  if (!is.numeric(zone_vector)) {
    stop("zone_vector must be numeric", call. = FALSE)
  }

  if (length(zone_vector) < 2) {
    return(0)
  }

  # Calculate difference between consecutive frames
  # Entry occurs when diff == 1 (transition from 0 to 1)
  transitions <- diff(zone_vector)
  entries <- sum(transitions == 1, na.rm = TRUE)

  return(as.integer(entries))
}

#' Calculate latency to first zone entry
#'
#' Time until first entry into a zone.
#'
#' @param zone_vector Numeric vector. Binary (0/1) zone membership
#' @param fps Numeric. Frames per second
#'
#' @return Numeric. Latency in seconds (NA if never entered)
#'
#' @examples
#' \dontrun{
#' zone_data <- c(0, 0, 0, 1, 1, 0)
#' latency <- calculate_zone_latency(zone_data, fps = 25)
#' }
#'
#' @export
calculate_zone_latency <- function(zone_vector, fps) {
  if (!is.numeric(zone_vector) || !is.numeric(fps) || fps <= 0) {
    stop("zone_vector must be numeric and fps must be positive", call. = FALSE)
  }

  # Find first frame where zone == 1
  first_entry_frame <- which(zone_vector == 1)[1]

  if (is.na(first_entry_frame)) {
    # Never entered zone
    return(NA_real_)
  }

  # Convert to seconds (0-indexed frames)
  latency_seconds <- (first_entry_frame - 1) / fps

  return(latency_seconds)
}

#' Calculate distance traveled in zone
#'
#' Calculates total distance traveled while in a specific zone.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#' @param zone_vector Numeric vector. Binary (0/1) zone membership
#'
#' @return Numeric. Distance in same units as coordinates (typically cm)
#'
#' @examples
#' \dontrun{
#' x <- c(10, 11, 12, 13, 14)
#' y <- c(20, 21, 22, 21, 20)
#' zone <- c(1, 1, 1, 0, 0)
#' dist <- calculate_distance_in_zone(x, y, zone)
#' }
#'
#' @export
calculate_distance_in_zone <- function(x, y, zone_vector) {
  if (length(x) != length(y) || length(x) != length(zone_vector)) {
    stop("x, y, and zone_vector must have the same length", call. = FALSE)
  }

  if (length(x) < 2) {
    return(0)
  }

  # Calculate distance between consecutive points
  dx <- diff(x)
  dy <- diff(y)
  distances <- sqrt(dx^2 + dy^2)

  # Only count distance when in zone
  # Use zone_vector[2:length] to align with distances (which are between points)
  in_zone <- zone_vector[-1] == 1

  total_distance <- sum(distances[in_zone], na.rm = TRUE)

  return(total_distance)
}

#' Analyze LD behavioral metrics
#'
#' Comprehensive analysis of Light/Dark box behavior using zone membership data.
#'
#' @param df Data frame. LD tracking data with zone columns (from load_ld_data)
#' @param fps Numeric. Frames per second (default: 25)
#' @param light_zone Character. Name of light zone column (default: "zone_light_floor")
#' @param dark_zone Character. Name of dark zone column (optional, inferred if NULL)
#' @param body_part Character. Body part to use for distance ("center", "nose", "tail")
#'   (default: "center")
#'
#' @return A list with LD metrics:
#'   \describe{
#'     \item{time_in_light_sec}{Numeric. Time in light zone (seconds)}
#'     \item{time_in_dark_sec}{Numeric. Time in dark zone (seconds)}
#'     \item{pct_time_in_light}{Numeric. Percentage of time in light}
#'     \item{pct_time_in_dark}{Numeric. Percentage of time in dark}
#'     \item{entries_to_light}{Integer. Number of light zone entries}
#'     \item{entries_to_dark}{Integer. Number of dark zone entries}
#'     \item{latency_to_light_sec}{Numeric. Latency to first light entry}
#'     \item{latency_to_dark_sec}{Numeric. Latency to first dark entry}
#'     \item{distance_in_light_cm}{Numeric. Distance traveled in light}
#'     \item{distance_in_dark_cm}{Numeric. Distance traveled in dark}
#'     \item{total_distance_cm}{Numeric. Total distance traveled}
#'     \item{transitions}{Integer. Total zone transitions}
#'     \item{total_duration_sec}{Numeric. Total trial duration}
#'   }
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' results <- analyze_ld(ld_data$Arena_1$data, fps = 25)
#' print(results$pct_time_in_light)
#' }
#'
#' @export
analyze_ld <- function(df, fps = 25, light_zone = "zone_light_floor",
                      dark_zone = NULL, body_part = "center") {
  # Validate inputs
  if (!is.data.frame(df)) {
    stop("df must be a data frame", call. = FALSE)
  }

  if (!light_zone %in% colnames(df)) {
    stop("Light zone column '", light_zone, "' not found in data", call. = FALSE)
  }

  # Infer dark zone if not specified
  if (is.null(dark_zone)) {
    # Dark zone is when NOT in light zone
    df$zone_dark_inferred <- ifelse(df[[light_zone]] == 0, 1, 0)
    dark_zone <- "zone_dark_inferred"
  } else if (!dark_zone %in% colnames(df)) {
    stop("Dark zone column '", dark_zone, "' not found in data", call. = FALSE)
  }

  # Get coordinate columns
  x_col <- paste0("x_", body_part)
  y_col <- paste0("y_", body_part)

  if (!x_col %in% colnames(df) || !y_col %in% colnames(df)) {
    stop("Coordinate columns for body part '", body_part, "' not found", call. = FALSE)
  }

  x <- df[[x_col]]
  y <- df[[y_col]]

  # Extract zone vectors
  light_vec <- df[[light_zone]]
  dark_vec <- df[[dark_zone]]

  # Calculate time metrics
  time_in_light <- calculate_zone_time(light_vec, fps)
  time_in_dark <- calculate_zone_time(dark_vec, fps)
  total_duration <- nrow(df) / fps

  # Calculate entry metrics
  entries_light <- detect_zone_entries(light_vec)
  entries_dark <- detect_zone_entries(dark_vec)

  # Calculate latency metrics
  latency_light <- calculate_zone_latency(light_vec, fps)
  latency_dark <- calculate_zone_latency(dark_vec, fps)

  # Calculate distance metrics
  distance_light <- calculate_distance_in_zone(x, y, light_vec)
  distance_dark <- calculate_distance_in_zone(x, y, dark_vec)

  # Total distance
  dx <- diff(x)
  dy <- diff(y)
  total_distance <- sum(sqrt(dx^2 + dy^2), na.rm = TRUE)

  # Count total transitions (light<->dark)
  # Transition occurs when light zone status changes
  transitions <- sum(abs(diff(light_vec)), na.rm = TRUE)

  # Compile results
  results <- list(
    # Time metrics
    time_in_light_sec = time_in_light,
    time_in_dark_sec = time_in_dark,
    pct_time_in_light = (time_in_light / total_duration) * 100,
    pct_time_in_dark = (time_in_dark / total_duration) * 100,

    # Entry metrics
    entries_to_light = entries_light,
    entries_to_dark = entries_dark,

    # Latency metrics
    latency_to_light_sec = latency_light,
    latency_to_dark_sec = latency_dark,

    # Distance metrics
    distance_in_light_cm = distance_light,
    distance_in_dark_cm = distance_dark,
    total_distance_cm = total_distance,

    # Transition metrics
    transitions = as.integer(transitions),

    # Duration
    total_duration_sec = total_duration,

    # Metadata
    fps = fps,
    body_part = body_part,
    light_zone_column = light_zone,
    dark_zone_column = dark_zone
  )

  return(results)
}

#' Analyze all arenas in LD dataset
#'
#' Runs analyze_ld() on all arenas and compiles results.
#'
#' @param ld_data List. Output from load_ld_data()
#' @param fps Numeric. Frames per second (default: 25)
#' @param body_part Character. Body part to use (default: "center")
#'
#' @return A data frame with one row per arena containing all metrics
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' results <- analyze_ld_batch(ld_data)
#' print(results)
#' }
#'
#' @export
analyze_ld_batch <- function(ld_data, fps = 25, body_part = "center") {
  if (!is.list(ld_data) || length(ld_data) == 0) {
    stop("ld_data must be a non-empty list", call. = FALSE)
  }

  results_list <- list()

  for (arena_name in names(ld_data)) {
    arena_data <- ld_data[[arena_name]]
    df <- arena_data$data

    # Run analysis
    tryCatch({
      metrics <- analyze_ld(df, fps = fps, body_part = body_part)

      # Add arena identification
      metrics$arena_name <- arena_name
      metrics$arena_id <- arena_data$arena_id
      metrics$subject_id <- arena_data$subject_id

      results_list[[arena_name]] <- metrics
    }, error = function(e) {
      warning("Failed to analyze ", arena_name, ": ", conditionMessage(e),
              call. = FALSE)
    })
  }

  # Convert to data frame
  if (length(results_list) == 0) {
    stop("No arenas were successfully analyzed", call. = FALSE)
  }

  results_df <- do.call(rbind, lapply(results_list, function(x) {
    # Convert list to data frame row
    as.data.frame(x, stringsAsFactors = FALSE)
  }))

  rownames(results_df) <- NULL

  # Reorder columns for readability
  priority_cols <- c("arena_name", "arena_id", "subject_id",
                     "time_in_light_sec", "time_in_dark_sec",
                     "pct_time_in_light", "pct_time_in_dark",
                     "entries_to_light", "latency_to_light_sec",
                     "total_distance_cm")
  priority_cols <- priority_cols[priority_cols %in% colnames(results_df)]
  other_cols <- setdiff(colnames(results_df), priority_cols)

  results_df <- results_df[, c(priority_cols, other_cols)]

  return(results_df)
}

#' Export LD results to CSV
#'
#' Saves LD analysis results to a CSV file.
#'
#' @param results Data frame. Output from analyze_ld_batch()
#' @param output_file Character. Path for output CSV file
#' @param overwrite Logical. Overwrite existing file (default: FALSE)
#'
#' @return Invisibly returns the file path
#'
#' @examples
#' \dontrun{
#' results <- analyze_ld_batch(ld_data)
#' export_ld_results(results, "ld_results.csv")
#' }
#'
#' @export
export_ld_results <- function(results, output_file, overwrite = FALSE) {
  if (!is.data.frame(results)) {
    stop("results must be a data frame", call. = FALSE)
  }

  if (file.exists(output_file) && !overwrite) {
    stop("File already exists: ", output_file, ". Set overwrite=TRUE to replace.",
         call. = FALSE)
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
