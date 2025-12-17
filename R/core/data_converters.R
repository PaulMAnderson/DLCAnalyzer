#' Data Format Converters for DLCAnalyzer
#'
#' Functions to convert external data formats to the internal tracking_data format.
#'
#' @name data_converters
NULL

#' Convert DeepLabCut data to tracking_data format
#'
#' Converts DLC CSV files to the standardized tracking_data S3 class format.
#' This is the main entry point for loading DLC data into DLCAnalyzer.
#'
#' @param dlc_file Character. Path to the DLC CSV file
#' @param config List. Optional configuration with arena and body part information
#' @param fps Numeric. Frames per second (default: 30)
#' @param subject_id Character. Subject identifier (default: extracted from filename)
#' @param session_id Character. Session identifier (default: NULL)
#' @param paradigm Character. Behavioral paradigm (default: "unknown")
#' @param reference_point_names Character vector. Names of points that are maze/arena
#'   reference points rather than animal body parts (default: NULL)
#' @param units Character. Measurement units (default: "pixels")
#'
#' @return A tracking_data S3 object
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' data <- convert_dlc_to_tracking_data(
#'   "path/to/dlc_output.csv",
#'   fps = 30,
#'   subject_id = "mouse_01",
#'   paradigm = "open_field"
#' )
#'
#' # With reference points for arena calibration
#' data <- convert_dlc_to_tracking_data(
#'   "path/to/epm_data.csv",
#'   fps = 30,
#'   subject_id = "mouse_02",
#'   paradigm = "elevated_plus_maze",
#'   reference_point_names = c("tl", "tr", "bl", "br", "lt", "lb", "rt", "rb",
#'                              "ctl", "ctr", "cbl", "cbr")
#' )
#' }
#'
#' @seealso \code{\link{new_tracking_data}}, \code{\link{read_dlc_csv}}
#'
#' @export
convert_dlc_to_tracking_data <- function(dlc_file,
                                         config = list(),
                                         fps = 30,
                                         subject_id = NULL,
                                         session_id = NULL,
                                         paradigm = "unknown",
                                         reference_point_names = NULL,
                                         units = "pixels") {

  # Load DLC file
  dlc_raw <- read_dlc_csv(dlc_file, fps = fps)

  # Parse into long format
  tracking_df <- parse_dlc_data(dlc_raw)

  # Extract subject_id from filename if not provided
  if (is.null(subject_id)) {
    subject_id <- extract_subject_id_from_filename(dlc_raw$filename)
  }

  # Separate reference points from body parts if specified
  all_bodyparts <- unique(tracking_df$body_part)

  if (!is.null(reference_point_names)) {
    # Identify which are reference points
    reference_points_present <- intersect(reference_point_names, all_bodyparts)
    body_parts_only <- setdiff(all_bodyparts, reference_point_names)

    # Extract reference point data
    ref_point_data <- tracking_df[tracking_df$body_part %in% reference_points_present, ]

    # Keep only body parts in main tracking data
    tracking_df <- tracking_df[tracking_df$body_part %in% body_parts_only, ]

    # Create reference points data frame (average position across all frames)
    if (nrow(ref_point_data) > 0) {
      reference_points_df <- aggregate(
        cbind(x, y, likelihood) ~ body_part,
        data = ref_point_data,
        FUN = function(x) median(x, na.rm = TRUE)
      )
      names(reference_points_df)[1] <- "point_name"
    } else {
      reference_points_df <- NULL
    }
  } else {
    reference_points_df <- NULL
  }

  # Infer arena dimensions from data range
  arena_dims <- infer_arena_dimensions(tracking_df)

  # Build metadata
  metadata <- list(
    source = "deeplabcut",
    fps = fps,
    subject_id = subject_id,
    session_id = session_id,
    paradigm = paradigm,
    timestamp = Sys.time(),
    original_file = dlc_file,
    units = units,
    scorer = dlc_raw$scorer[1]
  )

  # Build arena information
  arena <- list(
    dimensions = list(
      width = arena_dims$width,
      height = arena_dims$height,
      units = units
    ),
    reference_points = reference_points_df,
    zones = NULL  # To be defined by paradigm-specific functions
  )

  # Create tracking_data object
  tracking_data_obj <- new_tracking_data(
    metadata = metadata,
    tracking = tracking_df,
    arena = arena,
    config = config
  )

  # Validate before returning
  validate_tracking_data(tracking_data_obj)

  return(tracking_data_obj)
}

#' Load tracking data from file (auto-detect format)
#'
#' Convenience function that auto-detects the file format and loads it
#' into tracking_data format.
#'
#' @param file_path Character. Path to tracking data file
#' @param source_type Character. Data source type ("deeplabcut", "ethovision", "custom").
#'   If NULL, will attempt to auto-detect (default: NULL)
#' @param ... Additional arguments passed to format-specific converters
#'
#' @return A tracking_data S3 object
#'
#' @examples
#' \dontrun{
#' # Auto-detect format
#' data <- load_tracking_data("data.csv", fps = 30)
#'
#' # Explicitly specify format
#' data <- load_tracking_data("data.csv", source_type = "deeplabcut", fps = 30)
#' }
#'
#' @export
load_tracking_data <- function(file_path, source_type = NULL, ...) {
  # Validate file exists
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path,
         "\nPlease check the file path and try again.", call. = FALSE)
  }

  # Auto-detect source type if not specified
  if (is.null(source_type)) {
    source_type <- detect_source_type(file_path)

    if (is.null(source_type)) {
      stop("Could not auto-detect data source type for: ", file_path,
           "\nPlease specify source_type explicitly.",
           "\nSupported types: deeplabcut, ethovision, custom",
           call. = FALSE)
    }

    message("Auto-detected source type: ", source_type)
  }

  # Load based on source type
  tracking_data <- switch(source_type,
    deeplabcut = convert_dlc_to_tracking_data(file_path, ...),
    dlc = convert_dlc_to_tracking_data(file_path, ...),
    ethovision = stop("Ethovision converter not yet implemented", call. = FALSE),
    custom = stop("Custom CSV converter not yet implemented", call. = FALSE),
    stop("Unknown source_type: ", source_type,
         "\nSupported types: deeplabcut, ethovision, custom",
         call. = FALSE)
  )

  return(tracking_data)
}

#' Detect data source type from file
#'
#' Attempts to automatically determine the tracking data source type
#' based on file structure.
#'
#' @param file_path Character. Path to file
#'
#' @return Character. Detected source type, or NULL if unable to detect
#'
#' @keywords internal
detect_source_type <- function(file_path) {
  # Check if it's a DLC file
  if (is_dlc_csv(file_path)) {
    return("deeplabcut")
  }

  # Add checks for other formats here in future
  # if (is_ethovision_file(file_path)) {
  #   return("ethovision")
  # }

  return(NULL)
}

#' Infer arena dimensions from tracking data
#'
#' Estimates arena dimensions based on the range of coordinates in the data.
#' Adds a small buffer to ensure all points are within bounds.
#'
#' @param tracking_df Data frame with x and y coordinates
#'
#' @return List with width and height
#'
#' @keywords internal
infer_arena_dimensions <- function(tracking_df) {
  x_range <- range(tracking_df$x, na.rm = TRUE)
  y_range <- range(tracking_df$y, na.rm = TRUE)

  # Add 10% buffer
  x_buffer <- (x_range[2] - x_range[1]) * 0.1
  y_buffer <- (y_range[2] - y_range[1]) * 0.1

  width <- ceiling(x_range[2] + x_buffer)
  height <- ceiling(y_range[2] + y_buffer)

  list(width = width, height = height)
}

#' Extract subject ID from filename
#'
#' Attempts to extract a subject identifier from the filename using
#' common naming patterns.
#'
#' @param filename Character. Filename to parse
#'
#' @return Character. Extracted subject ID, or "unknown_subject" if unable to extract
#'
#' @keywords internal
extract_subject_id_from_filename <- function(filename) {
  # Remove file extension
  name_no_ext <- sub("\\.[^.]*$", "", filename)

  # Common patterns:
  # - Files like "Mouse_01_DLC.csv" -> "Mouse_01"
  # - Files like "EPM_10DeepCut..." -> "EPM_10"
  # - Files with numbers: extract the part before "DLC" or "DeepCut"

  # Try to find pattern before "DLC" or "DeepCut"
  patterns <- c(
    "^(.+?)_?DLC",
    "^(.+?)_?DeepCut",
    "^([A-Za-z]+_?[0-9]+)",
    "^([A-Za-z]+[0-9]+)"
  )

  for (pattern in patterns) {
    match <- regmatches(name_no_ext, regexec(pattern, name_no_ext))
    if (length(match[[1]]) > 1) {
      return(match[[1]][2])
    }
  }

  # If no pattern matched, use the whole filename
  return(name_no_ext)
}

#' Identify reference points in tracking data
#'
#' Helper function to identify which tracked points are likely to be
#' arena reference points (e.g., maze corners) based on movement patterns.
#'
#' Points with very low movement variance are likely fixed reference points.
#'
#' @param tracking_df Data frame with tracking data
#' @param movement_threshold Numeric. Maximum standard deviation of movement
#'   to be considered a reference point (default: 5 pixels)
#'
#' @return Character vector of body part names identified as reference points
#'
#' @examples
#' \dontrun{
#' dlc_raw <- read_dlc_csv("data.csv")
#' tracking_df <- parse_dlc_data(dlc_raw)
#' ref_points <- detect_reference_points(tracking_df)
#' }
#'
#' @export
detect_reference_points <- function(tracking_df, movement_threshold = 5) {
  bodyparts <- unique(tracking_df$body_part)
  reference_points <- character()

  for (bp in bodyparts) {
    bp_data <- tracking_df[tracking_df$body_part == bp, ]

    # Calculate movement variance
    x_sd <- sd(bp_data$x, na.rm = TRUE)
    y_sd <- sd(bp_data$y, na.rm = TRUE)

    # If both x and y have low variance, likely a reference point
    if (x_sd < movement_threshold && y_sd < movement_threshold) {
      reference_points <- c(reference_points, bp)
    }
  }

  return(reference_points)
}

#' Get body part names from tracking_data
#'
#' Extract unique body part names from a tracking_data object.
#'
#' @param tracking_data A tracking_data object
#'
#' @return Character vector of body part names
#'
#' @examples
#' \dontrun{
#' data <- load_tracking_data("file.csv", fps = 30)
#' bodyparts <- get_bodyparts(data)
#' }
#'
#' @export
get_bodyparts <- function(tracking_data) {
  if (!is_tracking_data(tracking_data)) {
    stop("Input must be a tracking_data object", call. = FALSE)
  }

  unique(tracking_data$tracking$body_part)
}

#' Get reference point names from tracking_data
#'
#' Extract reference point names from a tracking_data object.
#'
#' @param tracking_data A tracking_data object
#'
#' @return Character vector of reference point names, or NULL if none
#'
#' @examples
#' \dontrun{
#' data <- load_tracking_data("file.csv", fps = 30)
#' ref_points <- get_reference_points(data)
#' }
#'
#' @export
get_reference_points <- function(tracking_data) {
  if (!is_tracking_data(tracking_data)) {
    stop("Input must be a tracking_data object", call. = FALSE)
  }

  if (is.null(tracking_data$arena$reference_points)) {
    return(NULL)
  }

  tracking_data$arena$reference_points$point_name
}
