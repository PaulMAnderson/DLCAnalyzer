#' OFT (Open Field Test) Analysis Functions
#'
#' Functions for analyzing Open Field Test behavioral metrics using zone data.
#' Reuses zone calculation functions from LD analysis (calculate_zone_time, etc.)
#'
#' @name oft_analysis
NULL

#' Analyze OFT behavioral metrics
#'
#' Comprehensive analysis of Open Field Test behavior using zone membership data.
#' Calculates anxiety-like behavior metrics including center vs periphery time,
#' locomotor activity, and thigmotaxis.
#'
#' @param df Data frame. OFT tracking data with zone columns (from load_oft_data)
#' @param fps Numeric. Frames per second (default: 25)
#' @param center_zone Character. Name of center zone column (default: "zone_center")
#' @param periphery_zone Character. Name of periphery zone column
#'   (default: "zone_periphery", will be inferred if missing)
#' @param wall_zone Character. Name of wall zone column for thigmotaxis
#'   (default: "zone_wall", optional)
#' @param body_part Character. Body part to use for distance ("center", "nose", "tail")
#'   (default: "center")
#'
#' @return A list with OFT metrics:
#'   \describe{
#'     \item{time_in_center_sec}{Numeric. Time in center zone (seconds)}
#'     \item{time_in_periphery_sec}{Numeric. Time in periphery zone (seconds)}
#'     \item{pct_time_in_center}{Numeric. Percentage of time in center}
#'     \item{pct_time_in_periphery}{Numeric. Percentage of time in periphery}
#'     \item{entries_to_center}{Integer. Number of center zone entries}
#'     \item{latency_to_center_sec}{Numeric. Latency to first center entry}
#'     \item{distance_in_center_cm}{Numeric. Distance traveled in center}
#'     \item{distance_in_periphery_cm}{Numeric. Distance traveled in periphery}
#'     \item{total_distance_cm}{Numeric. Total distance traveled}
#'     \item{avg_velocity_cm_s}{Numeric. Average velocity (cm/s)}
#'     \item{time_near_wall_sec}{Numeric. Time near walls (if available)}
#'     \item{thigmotaxis_index}{Numeric. Ratio of wall time to total time (if available)}
#'     \item{total_duration_sec}{Numeric. Total trial duration}
#'   }
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' results <- analyze_oft(oft_data$Arena_1$data, fps = 25)
#' print(results$pct_time_in_center)
#' }
#'
#' @export
analyze_oft <- function(df, fps = 25, center_zone = "zone_center",
                        periphery_zone = "zone_periphery", wall_zone = "zone_wall",
                        body_part = "center") {
  # Validate inputs
  if (!is.data.frame(df)) {
    stop("df must be a data frame", call. = FALSE)
  }

  if (!center_zone %in% colnames(df)) {
    stop("Center zone column '", center_zone, "' not found in data", call. = FALSE)
  }

  # Infer periphery zone if not specified or missing
  if (!periphery_zone %in% colnames(df)) {
    # Periphery is when NOT in center zone
    df$zone_periphery_inferred <- ifelse(df[[center_zone]] == 0, 1, 0)
    periphery_zone <- "zone_periphery_inferred"
    message("Periphery zone inferred as NOT in center")
  }

  # Check if wall zone exists for thigmotaxis calculation
  has_wall_zone <- wall_zone %in% colnames(df)

  # Get coordinate columns based on body part
  x_col <- paste0("x_", body_part)
  y_col <- paste0("y_", body_part)

  if (!x_col %in% colnames(df) || !y_col %in% colnames(df)) {
    stop("Coordinate columns '", x_col, "' and '", y_col, "' not found", call. = FALSE)
  }

  # Extract vectors for analysis
  center_vec <- df[[center_zone]]
  periphery_vec <- df[[periphery_zone]]
  x <- df[[x_col]]
  y <- df[[y_col]]

  # Calculate total duration
  total_duration_sec <- max(df$time, na.rm = TRUE) - min(df$time, na.rm = TRUE)

  # Time in zones (requires calculate_zone_time from LD analysis)
  if (!exists("calculate_zone_time")) {
    stop("Required function 'calculate_zone_time' not found. ",
         "Please ensure LD analysis functions are loaded.", call. = FALSE)
  }

  time_in_center_sec <- calculate_zone_time(center_vec, fps)
  time_in_periphery_sec <- calculate_zone_time(periphery_vec, fps)

  # Percentages
  pct_time_in_center <- (time_in_center_sec / total_duration_sec) * 100
  pct_time_in_periphery <- (time_in_periphery_sec / total_duration_sec) * 100

  # Entries to center (requires detect_zone_entries)
  if (!exists("detect_zone_entries")) {
    stop("Required function 'detect_zone_entries' not found.", call. = FALSE)
  }

  entries_to_center <- detect_zone_entries(center_vec)

  # Latency to first center entry (requires calculate_zone_latency)
  if (!exists("calculate_zone_latency")) {
    stop("Required function 'calculate_zone_latency' not found.", call. = FALSE)
  }

  latency_to_center_sec <- calculate_zone_latency(center_vec, fps)

  # Distance calculations (requires calculate_distance_in_zone)
  if (!exists("calculate_distance_in_zone")) {
    stop("Required function 'calculate_distance_in_zone' not found.", call. = FALSE)
  }

  distance_in_center_cm <- calculate_distance_in_zone(x, y, center_vec)
  distance_in_periphery_cm <- calculate_distance_in_zone(x, y, periphery_vec)

  # Total distance - use Ethovision's pre-computed if available
  if ("distance" %in% colnames(df)) {
    total_distance_cm <- sum(df$distance, na.rm = TRUE)
  } else {
    # Calculate from coordinates
    dx <- diff(x)
    dy <- diff(y)
    distances <- sqrt(dx^2 + dy^2)
    total_distance_cm <- sum(distances, na.rm = TRUE)
  }

  # Average velocity - use Ethovision's pre-computed if available
  if ("velocity" %in% colnames(df)) {
    avg_velocity_cm_s <- mean(df$velocity, na.rm = TRUE)
  } else {
    # Calculate from total distance and duration
    avg_velocity_cm_s <- total_distance_cm / total_duration_sec
  }

  # Thigmotaxis (wall-hugging behavior) - only if wall zone available
  time_near_wall_sec <- NA
  thigmotaxis_index <- NA

  if (has_wall_zone) {
    wall_vec <- df[[wall_zone]]
    time_near_wall_sec <- calculate_zone_time(wall_vec, fps)
    thigmotaxis_index <- time_near_wall_sec / total_duration_sec
  }

  # Compile results
  results <- list(
    # Time metrics
    time_in_center_sec = time_in_center_sec,
    time_in_periphery_sec = time_in_periphery_sec,
    pct_time_in_center = pct_time_in_center,
    pct_time_in_periphery = pct_time_in_periphery,

    # Entry and latency metrics
    entries_to_center = entries_to_center,
    latency_to_center_sec = latency_to_center_sec,

    # Distance metrics
    distance_in_center_cm = distance_in_center_cm,
    distance_in_periphery_cm = distance_in_periphery_cm,
    total_distance_cm = total_distance_cm,
    avg_velocity_cm_s = avg_velocity_cm_s,

    # Thigmotaxis (wall-hugging)
    time_near_wall_sec = time_near_wall_sec,
    thigmotaxis_index = thigmotaxis_index,

    # Trial info
    total_duration_sec = total_duration_sec,
    n_frames = nrow(df),
    fps = fps
  )

  return(results)
}

#' Batch analyze multiple OFT arenas
#'
#' Analyzes all arenas from load_oft_data() output.
#'
#' @param oft_data List. Output from load_oft_data()
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return Data frame with one row per arena containing all OFT metrics
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' batch_results <- analyze_oft_batch(oft_data)
#' print(batch_results[, c("arena_name", "pct_time_in_center", "entries_to_center")])
#' }
#'
#' @export
analyze_oft_batch <- function(oft_data, fps = 25) {
  # Validate input
  if (!exists("validate_oft_data")) {
    stop("Required function 'validate_oft_data' not found.", call. = FALSE)
  }

  validate_oft_data(oft_data)

  # Analyze each arena
  results_list <- lapply(names(oft_data), function(arena_name) {
    arena <- oft_data[[arena_name]]

    # Run analysis
    metrics <- analyze_oft(arena$data, fps = fps)

    # Add arena identifiers
    metrics$arena_name <- arena_name
    metrics$arena_id <- arena$arena_id
    metrics$subject_id <- arena$subject_id

    # Convert to data frame row
    as.data.frame(metrics, stringsAsFactors = FALSE)
  })

  # Combine into single data frame
  results_df <- do.call(rbind, results_list)

  # Reorder columns for readability
  col_order <- c("arena_name", "arena_id", "subject_id",
                 "time_in_center_sec", "time_in_periphery_sec",
                 "pct_time_in_center", "pct_time_in_periphery",
                 "entries_to_center", "latency_to_center_sec",
                 "distance_in_center_cm", "distance_in_periphery_cm",
                 "total_distance_cm", "avg_velocity_cm_s",
                 "time_near_wall_sec", "thigmotaxis_index",
                 "total_duration_sec", "n_frames", "fps")

  # Only include columns that exist
  col_order <- col_order[col_order %in% colnames(results_df)]
  results_df <- results_df[, col_order]

  return(results_df)
}

#' Export OFT analysis results to CSV
#'
#' Saves OFT analysis results to a CSV file with proper formatting.
#'
#' @param results Data frame. Output from analyze_oft_batch()
#' @param output_file Character. Path to output CSV file
#' @param round_digits Integer. Number of decimal places (default: 2)
#'
#' @return Invisibly returns the results data frame
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' results <- analyze_oft_batch(oft_data)
#' export_oft_results(results, "oft_results.csv")
#' }
#'
#' @export
export_oft_results <- function(results, output_file, round_digits = 2) {
  # Validate inputs
  if (!is.data.frame(results)) {
    stop("results must be a data frame", call. = FALSE)
  }

  if (!is.character(output_file) || length(output_file) != 1) {
    stop("output_file must be a single character string", call. = FALSE)
  }

  # Create output directory if it doesn't exist
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Round numeric columns
  results_rounded <- results
  numeric_cols <- sapply(results_rounded, is.numeric)
  results_rounded[numeric_cols] <- lapply(results_rounded[numeric_cols],
                                          round, digits = round_digits)

  # Write to CSV
  write.csv(results_rounded, output_file, row.names = FALSE)

  message("OFT results exported to: ", output_file)

  invisible(results)
}

#' Calculate thigmotaxis index
#'
#' Calculates a measure of wall-hugging behavior (thigmotaxis).
#' This is an anxiety-like behavior in rodents.
#'
#' @param df Data frame. OFT tracking data with wall zone column
#' @param wall_zone_cols Character vector. Names of wall zone columns
#'   (default: automatically detects columns matching "zone_wall")
#' @param fps Numeric. Frames per second (default: 25)
#'
#' @return Numeric. Thigmotaxis index (0-1), where higher values indicate
#'   more time spent near walls
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("data.xlsx")
#' thigmo <- calculate_thigmotaxis_index(oft_data$Arena_1$data)
#' }
#'
#' @export
calculate_thigmotaxis_index <- function(df, wall_zone_cols = NULL, fps = 25) {
  # Auto-detect wall zone columns if not specified
  if (is.null(wall_zone_cols)) {
    wall_zone_cols <- grep("zone_wall", colnames(df), value = TRUE)
  }

  if (length(wall_zone_cols) == 0) {
    warning("No wall zone columns found. Cannot calculate thigmotaxis index.",
            call. = FALSE)
    return(NA_real_)
  }

  # Combine all wall zones (in case there are multiple wall segments)
  if (length(wall_zone_cols) == 1) {
    wall_vec <- df[[wall_zone_cols[1]]]
  } else {
    # Animal is near wall if in ANY wall zone
    wall_vec <- apply(df[, wall_zone_cols], 1, function(row) {
      ifelse(any(row == 1, na.rm = TRUE), 1, 0)
    })
  }

  # Calculate proportion of time near walls
  if (!exists("calculate_zone_time")) {
    stop("Required function 'calculate_zone_time' not found.", call. = FALSE)
  }

  time_near_wall <- calculate_zone_time(wall_vec, fps)
  total_duration <- max(df$time, na.rm = TRUE) - min(df$time, na.rm = TRUE)

  thigmotaxis_index <- time_near_wall / total_duration

  return(thigmotaxis_index)
}
