#' Internal Data Structures for DLCAnalyzer
#'
#' This file defines the core S3 class 'tracking_data' which serves as the
#' standardized internal format for all tracking data regardless of source.
#'
#' @name data_structures
NULL

#' Create a new tracking_data object
#'
#' Constructor function for the tracking_data S3 class. This creates a standardized
#' data structure that all data sources are converted to, enabling consistent
#' processing across different input formats.
#'
#' @param metadata List containing metadata about the tracking session:
#'   \describe{
#'     \item{source}{Character. Data source type ("deeplabcut", "ethovision", "custom")}
#'     \item{fps}{Numeric. Frames per second of the recording}
#'     \item{subject_id}{Character. Identifier for the subject}
#'     \item{session_id}{Character. Identifier for the session}
#'     \item{paradigm}{Character. Behavioral paradigm ("open_field", "epm", etc.)}
#'     \item{timestamp}{POSIXct. When the data was imported}
#'     \item{original_file}{Character. Path to the source data file}
#'     \item{units}{Character. Measurement units ("pixels", "cm", etc.)}
#'   }
#' @param tracking Data frame with tracking data containing:
#'   \describe{
#'     \item{frame}{Integer. Frame number (1-indexed)}
#'     \item{time}{Numeric. Time in seconds}
#'     \item{body_part}{Character. Name of the tracked body part}
#'     \item{x}{Numeric. X coordinate}
#'     \item{y}{Numeric. Y coordinate}
#'     \item{likelihood}{Numeric. Confidence score (0-1), or NA if not available}
#'   }
#' @param arena Optional list containing arena information:
#'   \describe{
#'     \item{dimensions}{List with width, height, and units}
#'     \item{reference_points}{Data frame with point_name, x, y, likelihood}
#'     \item{zones}{List of zone definitions}
#'   }
#' @param config Optional list with paradigm-specific configuration
#'
#' @return An object of class 'tracking_data'
#'
#' @examples
#' \dontrun{
#' # Create a simple tracking_data object
#' metadata <- list(
#'   source = "deeplabcut",
#'   fps = 30,
#'   subject_id = "mouse_01",
#'   session_id = "session_20240101",
#'   paradigm = "open_field",
#'   timestamp = Sys.time(),
#'   original_file = "path/to/file.csv",
#'   units = "pixels"
#' )
#'
#' tracking <- data.frame(
#'   frame = 1:100,
#'   time = seq(0, length.out = 100, by = 1/30),
#'   body_part = "bodycentre",
#'   x = rnorm(100, 250, 50),
#'   y = rnorm(100, 250, 50),
#'   likelihood = runif(100, 0.9, 1.0)
#' )
#'
#' arena <- list(
#'   dimensions = list(width = 500, height = 500, units = "pixels")
#' )
#'
#' data <- new_tracking_data(metadata, tracking, arena)
#' }
#'
#' @export
new_tracking_data <- function(metadata, tracking, arena = NULL, config = NULL) {
  structure(
    list(
      metadata = metadata,
      tracking = tracking,
      arena = arena,
      config = config
    ),
    class = "tracking_data"
  )
}

#' Validate a tracking_data object
#'
#' Validates the structure and content of a tracking_data object to ensure
#' it meets the requirements for downstream processing.
#'
#' @param x A tracking_data object to validate
#'
#' @return The validated tracking_data object (invisibly), or stops with error message
#'
#' @examples
#' \dontrun{
#' # This will validate the structure
#' validate_tracking_data(my_data)
#' }
#'
#' @export
validate_tracking_data <- function(x) {
  # Check class
  if (!inherits(x, "tracking_data")) {
    stop("Object must be of class 'tracking_data'", call. = FALSE)
  }

  # Check required top-level elements
  required_elements <- c("metadata", "tracking")
  missing_elements <- setdiff(required_elements, names(x))
  if (length(missing_elements) > 0) {
    stop("Missing required elements: ", paste(missing_elements, collapse = ", "),
         call. = FALSE)
  }

  # Validate metadata
  validate_metadata(x$metadata)

  # Validate tracking data frame
  validate_tracking_df(x$tracking)

  # Validate arena if present
  if (!is.null(x$arena)) {
    validate_arena(x$arena)
  }

  # Return invisibly for piping
  invisible(x)
}

#' Validate metadata component
#' @keywords internal
validate_metadata <- function(metadata) {
  required_fields <- c("source", "fps", "subject_id", "paradigm")
  missing_fields <- setdiff(required_fields, names(metadata))

  if (length(missing_fields) > 0) {
    stop("Missing required metadata fields: ",
         paste(missing_fields, collapse = ", "), call. = FALSE)
  }

  # Check data types
  if (!is.character(metadata$source)) {
    stop("metadata$source must be character", call. = FALSE)
  }

  if (!is.numeric(metadata$fps) || metadata$fps <= 0) {
    stop("metadata$fps must be a positive number", call. = FALSE)
  }

  if (!is.character(metadata$subject_id)) {
    stop("metadata$subject_id must be character", call. = FALSE)
  }

  if (!is.character(metadata$paradigm)) {
    stop("metadata$paradigm must be character", call. = FALSE)
  }

  invisible(metadata)
}

#' Validate tracking data frame component
#' @keywords internal
validate_tracking_df <- function(tracking) {
  if (!is.data.frame(tracking)) {
    stop("tracking must be a data frame", call. = FALSE)
  }

  required_cols <- c("frame", "time", "body_part", "x", "y")
  missing_cols <- setdiff(required_cols, names(tracking))

  if (length(missing_cols) > 0) {
    stop("Missing required tracking columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Check data types
  if (!is.numeric(tracking$frame)) {
    stop("tracking$frame must be numeric", call. = FALSE)
  }

  if (!is.numeric(tracking$time)) {
    stop("tracking$time must be numeric", call. = FALSE)
  }

  if (!is.character(tracking$body_part)) {
    stop("tracking$body_part must be character", call. = FALSE)
  }

  if (!is.numeric(tracking$x)) {
    stop("tracking$x must be numeric", call. = FALSE)
  }

  if (!is.numeric(tracking$y)) {
    stop("tracking$y must be numeric", call. = FALSE)
  }

  # Check likelihood if present
  if ("likelihood" %in% names(tracking)) {
    if (!is.numeric(tracking$likelihood)) {
      stop("tracking$likelihood must be numeric", call. = FALSE)
    }

    # Check range (allowing for NA values)
    valid_likelihood <- is.na(tracking$likelihood) |
      (tracking$likelihood >= 0 & tracking$likelihood <= 1)
    if (!all(valid_likelihood)) {
      stop("tracking$likelihood values must be between 0 and 1 (or NA)",
           call. = FALSE)
    }
  }

  # Check for empty data
  if (nrow(tracking) == 0) {
    warning("tracking data frame is empty", call. = FALSE)
  }

  invisible(tracking)
}

#' Validate arena component
#' @keywords internal
validate_arena <- function(arena) {
  if (!is.list(arena)) {
    stop("arena must be a list", call. = FALSE)
  }

  # Validate dimensions if present
  if ("dimensions" %in% names(arena)) {
    dims <- arena$dimensions
    required_dim_fields <- c("width", "height", "units")
    missing_dim_fields <- setdiff(required_dim_fields, names(dims))

    if (length(missing_dim_fields) > 0) {
      stop("Missing arena dimension fields: ",
           paste(missing_dim_fields, collapse = ", "), call. = FALSE)
    }

    if (!is.numeric(dims$width) || dims$width <= 0) {
      stop("arena$dimensions$width must be a positive number", call. = FALSE)
    }

    if (!is.numeric(dims$height) || dims$height <= 0) {
      stop("arena$dimensions$height must be a positive number", call. = FALSE)
    }

    if (!is.character(dims$units)) {
      stop("arena$dimensions$units must be character", call. = FALSE)
    }
  }

  # Validate reference_points if present
  if ("reference_points" %in% names(arena) && !is.null(arena$reference_points)) {
    ref_points <- arena$reference_points

    if (!is.data.frame(ref_points)) {
      stop("arena$reference_points must be a data frame", call. = FALSE)
    }

    required_ref_cols <- c("point_name", "x", "y")
    missing_ref_cols <- setdiff(required_ref_cols, names(ref_points))

    if (length(missing_ref_cols) > 0) {
      stop("Missing reference_points columns: ",
           paste(missing_ref_cols, collapse = ", "), call. = FALSE)
    }
  }

  invisible(arena)
}

#' Check if object is a tracking_data object
#'
#' Test if an object is of class 'tracking_data'
#'
#' @param x Object to test
#'
#' @return Logical. TRUE if x is a tracking_data object, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (is_tracking_data(my_data)) {
#'   # Process the data
#' }
#' }
#'
#' @export
is_tracking_data <- function(x) {
  inherits(x, "tracking_data")
}

#' Print method for tracking_data objects
#'
#' @param x A tracking_data object
#' @param ... Additional arguments (not used)
#'
#' @return The object invisibly
#'
#' @export
print.tracking_data <- function(x, ...) {
  cat("Tracking Data Object\n")
  cat("====================\n\n")

  # Metadata
  cat("Metadata:\n")
  cat("  Source:      ", x$metadata$source, "\n")
  cat("  Subject:     ", x$metadata$subject_id, "\n")
  if (!is.null(x$metadata$session_id)) {
    cat("  Session:     ", x$metadata$session_id, "\n")
  }
  cat("  Paradigm:    ", x$metadata$paradigm, "\n")
  cat("  FPS:         ", x$metadata$fps, "\n")
  if (!is.null(x$metadata$units)) {
    cat("  Units:       ", x$metadata$units, "\n")
  }
  cat("\n")

  # Tracking data summary
  cat("Tracking Data:\n")
  cat("  Frames:      ", length(unique(x$tracking$frame)), "\n")
  cat("  Duration:    ", sprintf("%.2f", max(x$tracking$time, na.rm = TRUE)), " seconds\n")
  cat("  Body parts:  ", paste(unique(x$tracking$body_part), collapse = ", "), "\n")

  if ("likelihood" %in% names(x$tracking)) {
    avg_likelihood <- mean(x$tracking$likelihood, na.rm = TRUE)
    cat("  Avg likelihood:", sprintf("%.3f", avg_likelihood), "\n")
  }
  cat("\n")

  # Arena info
  if (!is.null(x$arena)) {
    cat("Arena:\n")
    if (!is.null(x$arena$dimensions)) {
      cat("  Dimensions:  ", x$arena$dimensions$width, " x ",
          x$arena$dimensions$height, " ", x$arena$dimensions$units, "\n")
    }
    if (!is.null(x$arena$reference_points)) {
      cat("  Reference pts:", nrow(x$arena$reference_points), "\n")
    }
    if (!is.null(x$arena$zones)) {
      cat("  Zones:       ", length(x$arena$zones), "\n")
    }
    cat("\n")
  }

  # Config
  if (!is.null(x$config)) {
    cat("Configuration: Present\n")
  }

  invisible(x)
}

#' Summary method for tracking_data objects
#'
#' @param object A tracking_data object
#' @param ... Additional arguments (not used)
#'
#' @return A summary object (invisibly)
#'
#' @export
summary.tracking_data <- function(object, ...) {
  cat("Tracking Data Summary\n")
  cat("=====================\n\n")

  # Basic info
  cat("Source:   ", object$metadata$source, "\n")
  cat("Subject:  ", object$metadata$subject_id, "\n")
  cat("Paradigm: ", object$metadata$paradigm, "\n")
  cat("\n")

  # Tracking summary by body part
  cat("Tracking Summary by Body Part:\n")
  cat("------------------------------\n")

  for (bp in unique(object$tracking$body_part)) {
    bp_data <- object$tracking[object$tracking$body_part == bp, ]

    cat("\n", bp, ":\n", sep = "")
    cat("  Total points:   ", nrow(bp_data), "\n")
    cat("  Missing (NA):   ", sum(is.na(bp_data$x) | is.na(bp_data$y)), "\n")

    if ("likelihood" %in% names(bp_data)) {
      cat("  Avg likelihood: ", sprintf("%.3f", mean(bp_data$likelihood, na.rm = TRUE)), "\n")
      cat("  Min likelihood: ", sprintf("%.3f", min(bp_data$likelihood, na.rm = TRUE)), "\n")
    }

    # Coordinate ranges
    x_range <- range(bp_data$x, na.rm = TRUE)
    y_range <- range(bp_data$y, na.rm = TRUE)
    cat("  X range:        ", sprintf("[%.1f, %.1f]", x_range[1], x_range[2]), "\n")
    cat("  Y range:        ", sprintf("[%.1f, %.1f]", y_range[1], y_range[2]), "\n")
  }

  cat("\n")
  invisible(object)
}
