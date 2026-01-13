#' LD (Light/Dark Box) Data Loading Functions
#'
#' Functions for loading and preparing LD behavioral paradigm data.
#'
#' @name ld_load
NULL

#' Load LD data from Ethovision Excel file
#'
#' Loads Light/Dark box data with automatic zone extraction for multi-arena
#' experiments. Extracts "light floor" and "door area" zones for each animal.
#' Each animal is identified by the mouse ID in the user-defined variable (row 35).
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param body_part Character. Body part for zone analysis (default: "Center-point")
#'   Options: "Center-point", "Nose-point", "Tail-point"
#'
#' @return A named list where each element contains data for one animal:
#'   \describe{
#'     \item{data}{Data frame with columns:
#'       \itemize{
#'         \item frame: Frame number
#'         \item time: Time in seconds
#'         \item x_center, y_center: Center-point coordinates (cm)
#'         \item x_nose, y_nose: Nose-point coordinates (cm)
#'         \item x_tail, y_tail: Tail-point coordinates (cm)
#'         \item zone_light_floor: Binary (0/1) for light zone
#'         \item zone_door_area: Binary (0/1) for door/transition zone
#'       }
#'     }
#'     \item{animal_id}{Character. Animal ID from user-defined variable}
#'     \item{arena_id}{Numeric. Arena number where animal was tracked}
#'     \item{subject_id}{Numeric. Subject number}
#'     \item{metadata}{List of experimental metadata including animal_id}
#'     \item{fps}{Frames per second}
#'   }
#'
#' @examples
#' \dontrun{
#' # Load LD data
#' ld_data <- load_ld_data("LD_20251001.xlsx")
#'
#' # Access animal ID7687
#' animal <- ld_data[["ID7687"]]
#'
#' # Check which arena the animal was in
#' print(animal$arena_id)  # e.g., 1
#'
#' # Check zone occupancy
#' mean(animal$data$zone_light_floor)  # Proportion of time in light
#' }
#'
#' @export
load_ld_data <- function(file_path, fps = 25, body_part = "Center-point") {
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
    paradigm = "ld",
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
    df <- standardize_ld_columns(df)

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

#' Standardize LD data column names
#'
#' Ensures consistent column naming across different Ethovision exports.
#'
#' @param df Data frame. Raw Ethovision data with zone columns
#'
#' @return Data frame with standardized column names
#'
#' @keywords internal
standardize_ld_columns <- function(df) {
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
    y_tail = c("Y tail", "Y Tail", "y tail", "Y-tail", "Y.tail")
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
    warning("No zone columns found in data. Expected zone_light_floor and zone_door_area.",
            call. = FALSE)
  }

  # Add frame number if not present
  if (!"frame" %in% colnames(df)) {
    df$frame <- seq_len(nrow(df)) - 1  # 0-indexed
  }

  # Reorder columns for convenience
  priority_cols <- c("frame", "time", "x_center", "y_center",
                     "x_nose", "y_nose", "x_tail", "y_tail")
  priority_cols <- priority_cols[priority_cols %in% colnames(df)]
  zone_cols <- grep("^zone_", colnames(df), value = TRUE)
  other_cols <- setdiff(colnames(df), c(priority_cols, zone_cols))

  df <- df[, c(priority_cols, zone_cols, other_cols)]

  return(df)
}

#' Validate LD data structure
#'
#' Checks that LD data has required columns and valid zone data.
#'
#' @param ld_data List. Output from load_ld_data()
#'
#' @return Logical. TRUE if valid, FALSE otherwise (with warnings)
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' if (validate_ld_data(ld_data)) {
#'   # Proceed with analysis
#' }
#' }
#'
#' @export
validate_ld_data <- function(ld_data) {
  if (!is.list(ld_data) || length(ld_data) == 0) {
    warning("ld_data must be a non-empty list", call. = FALSE)
    return(FALSE)
  }

  all_valid <- TRUE

  for (animal_name in names(ld_data)) {
    animal_data <- ld_data[[animal_name]]

    # Check structure
    if (!"data" %in% names(animal_data)) {
      warning("Animal ", animal_name, " missing 'data' element", call. = FALSE)
      all_valid <- FALSE
      next
    }

    df <- animal_data$data

    # Check required columns
    required_cols <- c("time", "x_center", "y_center")
    missing_cols <- setdiff(required_cols, colnames(df))
    if (length(missing_cols) > 0) {
      warning("Animal ", animal_name, " missing required columns: ",
              paste(missing_cols, collapse = ", "), call. = FALSE)
      all_valid <- FALSE
    }

    # Check for zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)
    if (length(zone_cols) == 0) {
      warning("Animal ", animal_name, " has no zone columns", call. = FALSE)
      all_valid <- FALSE
    }

    # Check zone column values (should be 0 or 1)
    for (zone_col in zone_cols) {
      zone_vals <- df[[zone_col]]
      unique_vals <- unique(zone_vals[!is.na(zone_vals)])
      if (!all(unique_vals %in% c(0, 1))) {
        warning("Animal ", animal_name, " zone column ", zone_col,
                " has non-binary values: ", paste(unique_vals, collapse = ", "),
                call. = FALSE)
        all_valid <- FALSE
      }
    }

    # Check for missing data
    if (any(is.na(df$x_center)) || any(is.na(df$y_center))) {
      n_missing <- sum(is.na(df$x_center) | is.na(df$y_center))
      pct_missing <- round(n_missing / nrow(df) * 100, 2)
      warning("Animal ", animal_name, " has ", n_missing, " frames (",
              pct_missing, "%) with missing coordinates", call. = FALSE)
    }
  }

  return(all_valid)
}

#' Get summary of LD data
#'
#' Provides quick summary statistics for loaded LD data.
#'
#' @param ld_data List. Output from load_ld_data()
#'
#' @return Data frame with summary information for each animal
#'
#' @examples
#' \dontrun{
#' ld_data <- load_ld_data("data.xlsx")
#' summary <- summarize_ld_data(ld_data)
#' print(summary)
#' }
#'
#' @export
summarize_ld_data <- function(ld_data) {
  summary_list <- list()

  for (animal_name in names(ld_data)) {
    animal_data <- ld_data[[animal_name]]
    df <- animal_data$data

    # Find zone columns
    zone_cols <- grep("^zone_", colnames(df), value = TRUE)

    # Calculate basic stats
    summary_list[[animal_name]] <- data.frame(
      animal_id = animal_name,
      arena_id = ifelse(is.null(animal_data$arena_id), NA, animal_data$arena_id),
      subject_id = ifelse(is.null(animal_data$subject_id), NA, animal_data$subject_id),
      n_frames = nrow(df),
      duration_sec = max(df$time, na.rm = TRUE),
      fps = animal_data$fps,
      n_zones = length(zone_cols),
      zone_columns = paste(zone_cols, collapse = ", "),
      pct_missing_coords = round(sum(is.na(df$x_center) | is.na(df$y_center)) / nrow(df) * 100, 2),
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  return(summary_df)
}
