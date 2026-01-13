#' OFT (Open Field Test) Data Loading Functions
#'
#' Functions for loading and preparing OFT behavioral paradigm data.
#'
#' @name oft_load
NULL

#' Load OFT data from Ethovision Excel file
#'
#' Loads Open Field Test data with automatic zone extraction for multi-arena
#' experiments. Extracts "center", "floor", and "wall" zones for each arena.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param body_part Character. Body part for zone analysis (default: "Center-point")
#'   Options: "Center-point", "Nose-point", "Tail-point"
#'
#' @return A named list where each element contains data for one arena:
#'   \describe{
#'     \item{data}{Data frame with columns:
#'       \itemize{
#'         \item frame: Frame number
#'         \item time: Time in seconds
#'         \item x_center, y_center: Center-point coordinates (cm)
#'         \item x_nose, y_nose: Nose-point coordinates (cm)
#'         \item x_tail, y_tail: Tail-point coordinates (cm)
#'         \item distance: Distance moved (cm)
#'         \item velocity: Velocity (cm/s)
#'         \item zone_center: Binary (0/1) for center zone
#'         \item zone_floor: Binary (0/1) for floor zone
#'         \item zone_wall: Binary (0/1) for wall zone
#'       }
#'     }
#'     \item{arena_id}{Numeric. Arena number}
#'     \item{subject_id}{Numeric. Subject number}
#'     \item{metadata}{List of experimental metadata}
#'     \item{fps}{Frames per second}
#'   }
#'
#' @examples
#' \dontrun{
#' # Load OFT data
#' oft_data <- load_oft_data("OFT_20251001.xlsx")
#'
#' # Access arena 1
#' arena1 <- oft_data[["Arena_1"]]
#'
#' # Check zone occupancy
#' mean(arena1$data$zone_center)  # Proportion of time in center
#' }
#'
#' @export
load_oft_data <- function(file_path, fps = 25, body_part = "Center-point") {
  # Check for required functions from R/common/io.R
  if (!exists("read_ethovision_excel_multi_enhanced")) {
    stop("This function requires R/common/io.R to be loaded. ",
         "Please ensure the package is properly installed.", call. = FALSE)
  }

  # Read all sheets with zone extraction
  raw_data <- read_ethovision_excel_multi_enhanced(
    file_path,
    fps = fps,
    skip_control = TRUE,
    paradigm = "oft",
    body_part = body_part,
    include_zones = TRUE
  )

  # Process each animal (tracked in different arenas)
  results <- list()

  for (sheet_name in names(raw_data)) {
    sheet_data <- raw_data[[sheet_name]]

    # Extract tracking data
    df <- sheet_data$data

    # Standardize column names
    df <- standardize_oft_columns(df)

    # Create result structure
    animal_result <- list(
      data = df,
      animal_id = sheet_data$animal_id,
      arena_id = sheet_data$arena_id,
      subject_id = sheet_data$subject_id,
      metadata = sheet_data$metadata,
      fps = fps,
      n_frames = nrow(df),
      sheet_name = sheet_name
    )

    # Use animal_id as primary identifier, fall back to arena_id if not available
    if (!is.na(sheet_data$animal_id) && sheet_data$animal_id != "") {
      result_name <- as.character(sheet_data$animal_id)
    } else if (!is.na(sheet_data$arena_id)) {
      result_name <- paste0("Arena_", sheet_data$arena_id)
    } else {
      result_name <- sheet_name
    }

    results[[result_name]] <- animal_result
  }

  return(results)
}

#' Standardize OFT data column names
#'
#' Ensures consistent column naming across different Ethovision exports.
#' Also creates derived zone columns for easier analysis.
#'
#' @param df Data frame. Raw Ethovision data with zone columns
#'
#' @return Data frame with standardized column names and derived zones
#'
#' @keywords internal
standardize_oft_columns <- function(df) {
  # Get original column names
  orig_cols <- colnames(df)

  # Map common Ethovision column names to standardized names
  # Handle variations with different whitespace/capitalization
  # R converts spaces to dots when reading, so include both versions
  col_mapping <- list(
    time = c("Trial time", "Recording time", "trial time", "recording time",
             "Trial.time", "Recording.time"),
    x_center = c("X center", "X Center", "x center", "X centre", "X-center",
                 "X.center", "X.Centre"),
    y_center = c("Y center", "Y Center", "y center", "Y centre", "Y-center",
                 "Y.center", "Y.Centre"),
    x_nose = c("X nose", "X Nose", "x nose", "X-nose", "X.nose"),
    y_nose = c("Y nose", "Y Nose", "y nose", "Y-nose", "Y.nose"),
    x_tail = c("X tail", "X Tail", "x tail", "X-tail", "X.tail"),
    y_tail = c("Y tail", "Y Tail", "y tail", "Y-tail", "Y.tail"),
    distance = c("Distance moved", "Distance Moved", "distance moved",
                 "Distance.moved"),
    velocity = c("Velocity", "velocity")
  )

  # Rename columns
  new_names <- orig_cols
  for (std_name in names(col_mapping)) {
    patterns <- col_mapping[[std_name]]
    for (pattern in patterns) {
      matching_idx <- which(orig_cols == pattern)
      if (length(matching_idx) > 0) {
        new_names[matching_idx[1]] <- std_name
        break
      }
    }
  }

  colnames(df) <- new_names

  # Ensure zone columns are present
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)
  if (length(zone_cols) == 0) {
    warning("No zone columns found in data. Expected zone_center, zone_floor, zone_wall.",
            call. = FALSE)
  }

  # Create derived zone columns if needed
  # Periphery = in floor but NOT in center
  if ("zone_floor" %in% colnames(df) && "zone_center" %in% colnames(df)) {
    df$zone_periphery <- ifelse(
      df$zone_floor == 1 & df$zone_center == 0,
      1,
      0
    )
  } else if ("zone_floor" %in% colnames(df)) {
    # If only floor zone exists, periphery = floor - center
    # But we need center, so warn
    warning("zone_center not found. Cannot calculate zone_periphery.", call. = FALSE)
  }

  return(df)
}

#' Validate OFT data structure
#'
#' Checks that OFT data contains required columns and valid values.
#'
#' @param oft_data List. Output from load_oft_data()
#'
#' @return Invisibly returns TRUE if valid, otherwise stops with error
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("OFT_20251001.xlsx")
#' validate_oft_data(oft_data)
#' }
#'
#' @export
validate_oft_data <- function(oft_data) {
  # Check input type
  if (!is.list(oft_data)) {
    stop("oft_data must be a list (output from load_oft_data)", call. = FALSE)
  }

  if (length(oft_data) == 0) {
    stop("oft_data is empty", call. = FALSE)
  }

  # Required columns
  required_cols <- c("time", "x_center", "y_center")
  required_zone_cols <- c("zone_center")  # Minimum zone requirement

  # Check each arena
  for (arena_name in names(oft_data)) {
    arena <- oft_data[[arena_name]]

    # Check structure
    if (!is.list(arena) || is.null(arena$data)) {
      stop("Arena '", arena_name, "' missing 'data' component", call. = FALSE)
    }

    df <- arena$data

    # Check required columns
    missing_cols <- setdiff(required_cols, colnames(df))
    if (length(missing_cols) > 0) {
      stop("Arena '", arena_name, "' missing required columns: ",
           paste(missing_cols, collapse = ", "), call. = FALSE)
    }

    # Check zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)
    if (length(zone_cols) == 0) {
      warning("Arena '", arena_name, "' has no zone columns", call. = FALSE)
    }

    missing_zone_cols <- setdiff(required_zone_cols, colnames(df))
    if (length(missing_zone_cols) > 0) {
      warning("Arena '", arena_name, "' missing recommended zone columns: ",
              paste(missing_zone_cols, collapse = ", "), call. = FALSE)
    }

    # Check data validity
    if (nrow(df) == 0) {
      warning("Arena '", arena_name, "' has no data rows", call. = FALSE)
    }

    # Check for excessive missing coordinates
    na_x <- sum(is.na(df$x_center))
    na_y <- sum(is.na(df$y_center))
    na_pct <- max(na_x, na_y) / nrow(df) * 100

    if (na_pct > 50) {
      warning("Arena '", arena_name, "' has ", round(na_pct, 1),
              "% missing coordinates", call. = FALSE)
    }
  }

  invisible(TRUE)
}

#' Summarize OFT data
#'
#' Provides a quick summary of loaded OFT data including arena counts,
#' duration, and data quality metrics.
#'
#' @param oft_data List. Output from load_oft_data()
#'
#' @return Data frame with summary statistics for each arena
#'
#' @examples
#' \dontrun{
#' oft_data <- load_oft_data("OFT_20251001.xlsx")
#' summary <- summarize_oft_data(oft_data)
#' print(summary)
#' }
#'
#' @export
summarize_oft_data <- function(oft_data) {
  # Validate input
  validate_oft_data(oft_data)

  # Extract summary for each arena
  summaries <- lapply(names(oft_data), function(arena_name) {
    arena <- oft_data[[arena_name]]
    df <- arena$data

    # Calculate metrics
    n_frames <- nrow(df)
    duration_sec <- max(df$time, na.rm = TRUE) - min(df$time, na.rm = TRUE)
    duration_min <- duration_sec / 60

    na_coords <- sum(is.na(df$x_center) | is.na(df$y_center))
    pct_missing <- (na_coords / n_frames) * 100

    # Count zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)
    n_zones <- length(zone_cols)

    # Time in center (if available)
    time_in_center <- NA
    if ("zone_center" %in% colnames(df)) {
      time_in_center <- sum(df$zone_center, na.rm = TRUE) / arena$fps
    }

    data.frame(
      arena_name = arena_name,
      arena_id = arena$arena_id,
      subject_id = arena$subject_id,
      n_frames = n_frames,
      duration_sec = round(duration_sec, 2),
      duration_min = round(duration_min, 2),
      fps = arena$fps,
      n_zones = n_zones,
      pct_missing_coords = round(pct_missing, 2),
      time_in_center_sec = round(time_in_center, 2),
      stringsAsFactors = FALSE
    )
  })

  # Combine into data frame
  result <- do.call(rbind, summaries)
  return(result)
}

#' Get available zone names for an OFT arena
#'
#' Helper function to list all zone columns present in the data.
#'
#' @param arena_data List. Single arena data structure from load_oft_data()
#'
#' @return Character vector of zone column names
#'
#' @keywords internal
get_oft_zone_names <- function(arena_data) {
  if (is.null(arena_data$data)) {
    stop("Invalid arena_data: missing 'data' component", call. = FALSE)
  }

  zone_cols <- grep("^zone_", colnames(arena_data$data), value = TRUE)
  return(zone_cols)
}
