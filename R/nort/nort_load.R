#' NORT (Novel Object Recognition Test) Data Loading Functions
#'
#' Functions for loading and preparing NORT behavioral paradigm data.
#'
#' @name nort_load
NULL

#' Load NORT data from Ethovision Excel file
#'
#' Loads Novel Object Recognition Test data with automatic zone extraction for
#' multi-arena experiments. Extracts "object left", "object right", "center",
#' and "floor" zones for each arena. NORT requires dual body part tracking:
#' nose-point for object exploration and center-point for locomotion metrics.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param novel_side Character. Which side is novel: "left" or "right" (default: "left")
#'   This parameter is used to properly label exploration metrics in downstream analysis
#'
#' @return A named list where each element contains data for one arena:
#'   \describe{
#'     \item{data}{Data frame with columns:
#'       \itemize{
#'         \item frame: Frame number
#'         \item time: Time in seconds
#'         \item x_center, y_center: Center-point coordinates (cm) for locomotion
#'         \item x_nose, y_nose: Nose-point coordinates (cm) for object interaction
#'         \item x_tail, y_tail: Tail-point coordinates (cm)
#'         \item zone_round_object_left: Binary (0/1) for left object zone (nose-point)
#'         \item zone_round_object_right: Binary (0/1) for right object zone (nose-point)
#'         \item zone_center: Binary (0/1) for center zone (center-point)
#'         \item zone_floor: Binary (0/1) for floor zone (center-point)
#'       }
#'     }
#'     \item{arena_id}{Numeric. Arena number}
#'     \item{subject_id}{Numeric. Subject number}
#'     \item{metadata}{List of experimental metadata}
#'     \item{fps}{Frames per second}
#'     \item{novel_side}{Character. Which side is novel ("left" or "right")}
#'   }
#'
#' @examples
#' \dontrun{
#' # Load NORT test phase data (novel on left side)
#' nort_data <- load_nort_data("NORT_test_20251003.xlsx", novel_side = "left")
#'
#' # Access arena 1
#' arena1 <- nort_data[["Arena_1"]]
#'
#' # Check object exploration (nose-point zones)
#' sum(arena1$data$zone_round_object_left) / arena1$fps  # Time at left object
#' }
#'
#' @export
load_nort_data <- function(file_path, fps = 25, novel_side = "left") {
  # Validate novel_side parameter
  novel_side <- tolower(novel_side)
  if (!novel_side %in% c("left", "right", "neither")) {
    stop("novel_side must be 'left', 'right', or 'neither', got: ", novel_side, call. = FALSE)
  }

  # Check for required functions from R/common/io.R
  if (!exists("read_ethovision_excel_multi_enhanced")) {
    stop("This function requires R/common/io.R to be loaded. ",
         "Please ensure the package is properly installed.", call. = FALSE)
  }

  # First, read with nose-point to get object zones
  raw_data_nose <- read_ethovision_excel_multi_enhanced(
    file_path,
    fps = fps,
    skip_control = TRUE,
    paradigm = "nort",
    body_part = "Nose-point",
    include_zones = TRUE
  )

  # Also read with center-point to get locomotion zones
  raw_data_center <- read_ethovision_excel_multi_enhanced(
    file_path,
    fps = fps,
    skip_control = TRUE,
    paradigm = NULL,  # Don't filter - we want center/floor zones
    body_part = "Center-point",
    include_zones = TRUE
  )

  # Process each arena
  results <- list()

  for (sheet_name in names(raw_data_nose)) {
    sheet_data_nose <- raw_data_nose[[sheet_name]]
    sheet_data_center <- raw_data_center[[sheet_name]]

    # Extract tracking data (use nose data as base)
    df <- sheet_data_nose$data

    # Add center-point zone columns
    center_zone_cols <- grep("^zone_", colnames(sheet_data_center$data), value = TRUE)
    center_zone_cols <- center_zone_cols[grepl("center|floor", center_zone_cols, ignore.case = TRUE)]

    for (zcol in center_zone_cols) {
      if (zcol %in% colnames(sheet_data_center$data)) {
        # Rename to avoid conflicts - add _centerpoint suffix if needed
        new_col_name <- zcol
        if (zcol %in% colnames(df) && !identical(df[[zcol]], sheet_data_center$data[[zcol]])) {
          new_col_name <- paste0(zcol, "_centerpoint")
        }
        df[[new_col_name]] <- sheet_data_center$data[[zcol]]
      }
    }

    # Standardize column names
    df <- standardize_nort_columns(df)

    # Create result structure
    arena_result <- list(
      data = df,
      arena_id = sheet_data_nose$arena_id,
      subject_id = sheet_data_nose$subject_id,
      metadata = sheet_data_nose$metadata,
      fps = fps,
      n_frames = nrow(df),
      sheet_name = sheet_name,
      novel_side = novel_side
    )

    # Use arena_id as name if available
    if (!is.na(sheet_data_nose$arena_id)) {
      result_name <- paste0("Arena_", sheet_data_nose$arena_id)
    } else {
      result_name <- sheet_name
    }

    results[[result_name]] <- arena_result
  }

  return(results)
}

#' Load paired habituation and test phase NORT data
#'
#' Loads both habituation and test phase files for NORT experiments.
#' Habituation phase typically has 2 identical objects (or empty arena),
#' while test phase has 1 familiar and 1 novel object.
#'
#' @param hab_file Character. Path to habituation phase file
#' @param test_file Character. Path to test phase file
#' @param fps Numeric. Frames per second (default: 25)
#' @param novel_side Character. Which side is novel in test phase: "left" or "right"
#'
#' @return A list with two elements:
#'   \describe{
#'     \item{habituation}{Output from load_nort_data() for habituation phase}
#'     \item{test}{Output from load_nort_data() for test phase}
#'   }
#'
#' @examples
#' \dontrun{
#' paired_data <- load_nort_paired_data(
#'   hab_file = "NORT_hab_D1_20251001.xlsx",
#'   test_file = "NORT_test_D3_20251003.xlsx",
#'   novel_side = "left"
#' )
#'
#' # Access habituation arena 1
#' hab_arena1 <- paired_data$habituation[["Arena_1"]]
#'
#' # Access test arena 1
#' test_arena1 <- paired_data$test[["Arena_1"]]
#' }
#'
#' @export
load_nort_paired_data <- function(hab_file, test_file, fps = 25, novel_side = "left") {
  message("Loading habituation phase...")
  hab_data <- load_nort_data(hab_file, fps = fps, novel_side = "neither")

  message("Loading test phase...")
  test_data <- load_nort_data(test_file, fps = fps, novel_side = novel_side)

  result <- list(
    habituation = hab_data,
    test = test_data
  )

  return(result)
}

#' Standardize NORT data column names
#'
#' Ensures consistent column naming across different Ethovision exports.
#' Handles dual body parts (nose-point for exploration, center-point for locomotion).
#'
#' @param df Data frame. Raw Ethovision data with zone columns
#'
#' @return Data frame with standardized column names
#'
#' @keywords internal
standardize_nort_columns <- function(df) {
  # Get original column names
  orig_cols <- colnames(df)

  # Map common Ethovision column names to standardized names
  # Handle variations with different whitespace/capitalization
  # R converts spaces to dots when reading, so include both versions
  col_mapping <- list(
    time = c("Trial time", "Recording time", "trial time", "recording time",
             "Trial.time", "Recording.time"),
    # Center-point coordinates (for locomotion)
    x_center = c("X center", "X Center", "x center", "X centre", "X-center",
                 "X.center", "X.Centre"),
    y_center = c("Y center", "Y Center", "y center", "Y centre", "Y-center",
                 "Y.center", "Y.Centre"),
    # Nose-point coordinates (for object exploration)
    x_nose = c("X nose", "X Nose", "x nose", "X-nose", "X.nose"),
    y_nose = c("Y nose", "Y Nose", "y nose", "Y-nose", "Y.nose"),
    # Tail-point coordinates
    x_tail = c("X tail", "X Tail", "x tail", "X-tail", "X.tail"),
    y_tail = c("Y tail", "Y Tail", "y tail", "Y-tail", "Y.tail"),
    # Distance and velocity (may be for different body parts)
    distance = c("Distance moved", "Distance Moved", "distance moved",
                 "Distance.moved", "Distance moved 2(Center-point)"),
    velocity = c("Velocity", "velocity", "Velocity 2(Center-point)")
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
    warning("No zone columns found in data. Expected zone_round_object_left, ",
            "zone_round_object_right, zone_center, zone_floor.", call. = FALSE)
  }

  # Check for object zones specifically
  object_zones <- grep("object", zone_cols, value = TRUE, ignore.case = TRUE)
  if (length(object_zones) == 0) {
    warning("No object zone columns found. NORT analysis requires object zones.",
            call. = FALSE)
  }

  # Add frame number if not present
  if (!"frame" %in% colnames(df)) {
    df$frame <- seq_len(nrow(df)) - 1  # 0-indexed
  }

  # Reorder columns for convenience
  # Priority: frame, time, nose coords (exploration), center coords (locomotion), zones
  priority_cols <- c("frame", "time",
                     "x_nose", "y_nose",
                     "x_center", "y_center",
                     "x_tail", "y_tail",
                     "distance", "velocity")
  priority_cols <- priority_cols[priority_cols %in% colnames(df)]
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)
  other_cols <- setdiff(colnames(df), c(priority_cols, zone_cols))

  df <- df[, c(priority_cols, zone_cols, other_cols)]

  return(df)
}

#' Validate NORT data structure
#'
#' Checks that NORT data has required columns and valid zone data.
#' NORT requires both nose-point (for object exploration) and center-point
#' (for locomotion) coordinates.
#'
#' @param nort_data List. Output from load_nort_data()
#'
#' @return Logical. TRUE if valid, FALSE otherwise (with warnings)
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx", novel_side = "left")
#' if (validate_nort_data(nort_data)) {
#'   # Proceed with analysis
#' }
#' }
#'
#' @export
validate_nort_data <- function(nort_data) {
  if (!is.list(nort_data) || length(nort_data) == 0) {
    warning("nort_data must be a non-empty list", call. = FALSE)
    return(FALSE)
  }

  all_valid <- TRUE

  for (arena_name in names(nort_data)) {
    arena_data <- nort_data[[arena_name]]

    # Check structure
    if (!"data" %in% names(arena_data)) {
      warning("Arena ", arena_name, " missing 'data' element", call. = FALSE)
      all_valid <- FALSE
      next
    }

    df <- arena_data$data

    # Check required columns for NORT
    # Need BOTH nose-point (exploration) and center-point (locomotion)
    required_cols <- c("time", "x_nose", "y_nose", "x_center", "y_center")
    missing_cols <- setdiff(required_cols, colnames(df))
    if (length(missing_cols) > 0) {
      warning("Arena ", arena_name, " missing required columns: ",
              paste(missing_cols, collapse = ", "),
              "\nNORT requires both nose-point and center-point coordinates",
              call. = FALSE)
      all_valid <- FALSE
    }

    # Check for object zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)
    object_zones <- grep("object", zone_cols, value = TRUE, ignore.case = TRUE)

    if (length(object_zones) == 0) {
      warning("Arena ", arena_name, " has no object zone columns. ",
              "NORT requires zone_round_object_left and zone_round_object_right",
              call. = FALSE)
      all_valid <- FALSE
    } else if (length(object_zones) < 2) {
      warning("Arena ", arena_name, " has only ", length(object_zones),
              " object zone(s). Expected 2 (left and right)", call. = FALSE)
    }

    # Check zone column values (should be 0 or 1)
    for (zone_col in zone_cols) {
      zone_vals <- df[[zone_col]]
      unique_vals <- unique(zone_vals[!is.na(zone_vals)])
      if (!all(unique_vals %in% c(0, 1))) {
        warning("Arena ", arena_name, " zone column ", zone_col,
                " has non-binary values: ", paste(unique_vals, collapse = ", "),
                call. = FALSE)
        all_valid <- FALSE
      }
    }

    # Check for missing data in nose coordinates (critical for exploration)
    if (any(is.na(df$x_nose)) || any(is.na(df$y_nose))) {
      n_missing <- sum(is.na(df$x_nose) | is.na(df$y_nose))
      pct_missing <- round(n_missing / nrow(df) * 100, 2)
      warning("Arena ", arena_name, " has ", n_missing, " frames (",
              pct_missing, "%) with missing nose coordinates. ",
              "This will affect object exploration metrics.", call. = FALSE)
    }

    # Check for missing data in center coordinates (needed for locomotion)
    if (any(is.na(df$x_center)) || any(is.na(df$y_center))) {
      n_missing <- sum(is.na(df$x_center) | is.na(df$y_center))
      pct_missing <- round(n_missing / nrow(df) * 100, 2)
      warning("Arena ", arena_name, " has ", n_missing, " frames (",
              pct_missing, "%) with missing center coordinates. ",
              "This will affect locomotion metrics.", call. = FALSE)
    }

    # Validate novel_side if present
    if (!is.null(arena_data$novel_side)) {
      if (!arena_data$novel_side %in% c("left", "right", "neither")) {
        warning("Arena ", arena_name, " has invalid novel_side: ",
                arena_data$novel_side, call. = FALSE)
        all_valid <- FALSE
      }
    }
  }

  return(all_valid)
}

#' Get summary of NORT data
#'
#' Provides quick summary statistics for loaded NORT data, including
#' object exploration times.
#'
#' @param nort_data List. Output from load_nort_data()
#'
#' @return Data frame with summary information for each arena
#'
#' @examples
#' \dontrun{
#' nort_data <- load_nort_data("data.xlsx", novel_side = "left")
#' summary <- summarize_nort_data(nort_data)
#' print(summary)
#' }
#'
#' @export
summarize_nort_data <- function(nort_data) {
  summary_list <- list()

  for (arena_name in names(nort_data)) {
    arena_data <- nort_data[[arena_name]]
    df <- arena_data$data

    # Find zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)
    object_zones <- grep("object", zone_cols, value = TRUE, ignore.case = TRUE)

    # Calculate object exploration times
    left_time <- NA
    right_time <- NA

    left_col <- grep("left", object_zones, value = TRUE, ignore.case = TRUE)
    right_col <- grep("right", object_zones, value = TRUE, ignore.case = TRUE)

    if (length(left_col) > 0) {
      left_time <- sum(df[[left_col[1]]], na.rm = TRUE) / arena_data$fps
    }
    if (length(right_col) > 0) {
      right_time <- sum(df[[right_col[1]]], na.rm = TRUE) / arena_data$fps
    }

    total_exploration <- sum(left_time, right_time, na.rm = TRUE)

    # Calculate basic stats
    summary_list[[arena_name]] <- data.frame(
      arena = arena_name,
      arena_id = ifelse(is.null(arena_data$arena_id), NA, arena_data$arena_id),
      subject_id = ifelse(is.null(arena_data$subject_id), NA, arena_data$subject_id),
      n_frames = nrow(df),
      duration_sec = max(df$time, na.rm = TRUE),
      fps = arena_data$fps,
      novel_side = ifelse(is.null(arena_data$novel_side), NA, arena_data$novel_side),
      n_zones = length(zone_cols),
      n_object_zones = length(object_zones),
      left_object_time_sec = round(left_time, 2),
      right_object_time_sec = round(right_time, 2),
      total_exploration_sec = round(total_exploration, 2),
      pct_missing_nose = round(sum(is.na(df$x_nose) | is.na(df$y_nose)) / nrow(df) * 100, 2),
      pct_missing_center = round(sum(is.na(df$x_center) | is.na(df$y_center)) / nrow(df) * 100, 2),
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  return(summary_df)
}
