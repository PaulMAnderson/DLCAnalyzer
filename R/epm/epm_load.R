#' EPM (Elevated Plus Maze) Data Loading Functions
#'
#' Functions for loading and preparing EPM behavioral paradigm data from
#' DeepLabCut CSV files.
#'
#' @name epm_load
NULL

#' Load EPM data from DeepLabCut CSV file
#'
#' Loads Elevated Plus Maze tracking data from a DeepLabCut CSV export. Handles
#' pixel-to-cm conversion, zone calculation from maze geometry, and data validation.
#'
#' @param file_path Character. Path to the DLC CSV file
#' @param fps Numeric. Frames per second of the recording (default: 25)
#' @param pixels_per_cm Numeric. Pixel-to-cm conversion factor (default: 5.3)
#' @param arena_config List. EPM arena dimensions (optional). Default structure:
#'   \itemize{
#'     \item arm_length: 40 cm (default)
#'     \item arm_width: 5 cm (default)
#'     \item center_size: 10 cm (default)
#'     \item open_arms: c("north", "south") (default)
#'     \item closed_arms: c("east", "west") (default)
#'   }
#' @param body_part Character. Body part to use for analysis (default: "mouse_center")
#' @param likelihood_threshold Numeric. Minimum confidence for valid points (default: 0.9)
#'
#' @return A list with EPM data in standard format:
#'   \describe{
#'     \item{data}{Data frame with columns:
#'       \itemize{
#'         \item frame: Frame number
#'         \item time: Time in seconds
#'         \item x: X coordinate (cm)
#'         \item y: Y coordinate (cm)
#'         \item likelihood: Tracking confidence
#'         \item zone_open_arms: Binary (0/1) for open arm occupancy
#'         \item zone_closed_arms: Binary (0/1) for closed arm occupancy
#'         \item zone_center: Binary (0/1) for center platform
#'         \item arm_id: Specific arm name ("north", "south", "east", "west", "center")
#'       }
#'     }
#'     \item{subject_id}{Character. Subject identifier (from filename)}
#'     \item{fps}{Frames per second}
#'     \item{arena_config}{List of arena dimensions used}
#'     \item{pixels_per_cm}{Conversion factor used}
#'     \item{body_part}{Body part used for analysis}
#'   }
#'
#' @examples
#' \dontrun{
#' # Load EPM data with defaults
#' epm_data <- load_epm_data("ID7687_DLC_output.csv")
#'
#' # Load with custom pixel conversion
#' epm_data <- load_epm_data("ID7687_DLC_output.csv", pixels_per_cm = 6.0)
#'
#' # Check anxiety metrics
#' mean(epm_data$data$zone_open_arms)  # Proportion in open arms
#' }
#'
#' @export
load_epm_data <- function(file_path,
                          fps = 25,
                          pixels_per_cm = 5.3,
                          arena_config = NULL,
                          body_part = "mouse_center",
                          likelihood_threshold = 0.9) {

  # Validate inputs
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path, call. = FALSE)
  }

  if (!is.numeric(fps) || fps <= 0) {
    stop("fps must be a positive number", call. = FALSE)
  }

  if (!is.numeric(pixels_per_cm) || pixels_per_cm <= 0) {
    stop("pixels_per_cm must be a positive number", call. = FALSE)
  }

  if (!is.numeric(likelihood_threshold) || likelihood_threshold < 0 || likelihood_threshold > 1) {
    stop("likelihood_threshold must be between 0 and 1", call. = FALSE)
  }

  # Set default arena config if not provided
  if (is.null(arena_config)) {
    arena_config <- list(
      arm_length = 40,      # cm from center edge to arm end
      arm_width = 5,        # cm width of each arm
      center_size = 10,     # cm diameter of center platform
      open_arms = c("north", "south"),
      closed_arms = c("east", "west")
    )
  }

  # Read DLC CSV using existing function
  message("Reading DLC CSV file: ", basename(file_path))
  dlc_raw <- read_dlc_csv(file_path, fps = fps)

  # Parse DLC data into long format
  tracking_df <- parse_dlc_data(dlc_raw)

  # Check if body part exists
  available_bodyparts <- unique(tracking_df$body_part)
  if (!body_part %in% available_bodyparts) {
    warning("Body part '", body_part, "' not found. Available: ",
            paste(available_bodyparts, collapse = ", "),
            "\nUsing first available body part: ", available_bodyparts[1])
    body_part <- available_bodyparts[1]
  }

  # Filter to selected body part
  bp_data <- tracking_df[tracking_df$body_part == body_part, ]

  # Filter low likelihood points
  if (likelihood_threshold > 0) {
    n_before <- sum(!is.na(bp_data$likelihood))
    bp_data$x[bp_data$likelihood < likelihood_threshold] <- NA
    bp_data$y[bp_data$likelihood < likelihood_threshold] <- NA
    n_after <- sum(!is.na(bp_data$x))
    if (n_before > 0) {
      pct_filtered <- (n_before - n_after) / n_before * 100
      message(sprintf("Filtered %.1f%% of points with likelihood < %.2f",
                      pct_filtered, likelihood_threshold))
    }
  }

  # Convert pixels to cm
  message(sprintf("Converting coordinates: %.2f pixels/cm", pixels_per_cm))
  bp_data$x <- bp_data$x / pixels_per_cm
  bp_data$y <- bp_data$y / pixels_per_cm

  # Center coordinates (optional - EPM analysis typically uses centered coords)
  # Find approximate center as median position
  center_x <- median(bp_data$x, na.rm = TRUE)
  center_y <- median(bp_data$y, na.rm = TRUE)
  bp_data$x <- bp_data$x - center_x
  bp_data$y <- bp_data$y - center_y

  message(sprintf("Centered coordinates at (%.2f, %.2f) cm", center_x, center_y))

  # Calculate EPM zones from geometry
  message("Calculating EPM arm zones...")
  zones <- define_epm_zones(bp_data$x, bp_data$y, arena_config)

  # Add zone columns to data
  bp_data$zone_open_arms <- zones$zone_open_arms
  bp_data$zone_closed_arms <- zones$zone_closed_arms
  bp_data$zone_center <- zones$zone_center
  bp_data$arm_id <- zones$arm_id

  # Standardize column names for consistency
  final_df <- data.frame(
    frame = bp_data$frame,
    time = bp_data$time,
    x = bp_data$x,
    y = bp_data$y,
    likelihood = bp_data$likelihood,
    zone_open_arms = bp_data$zone_open_arms,
    zone_closed_arms = bp_data$zone_closed_arms,
    zone_center = bp_data$zone_center,
    arm_id = bp_data$arm_id,
    stringsAsFactors = FALSE
  )

  # Extract subject ID from filename
  subject_id <- extract_subject_id(file_path)

  # Create result structure matching LD/OFT/NORT format
  result <- list(
    data = final_df,
    subject_id = subject_id,
    fps = fps,
    arena_config = arena_config,
    pixels_per_cm = pixels_per_cm,
    body_part = body_part,
    likelihood_threshold = likelihood_threshold,
    n_frames = nrow(final_df),
    filename = basename(file_path)
  )

  message(sprintf("Loaded %d frames (%.1f seconds) for subject %s",
                  result$n_frames, max(final_df$time, na.rm = TRUE), subject_id))

  # Validate the result
  validate_epm_data(result)

  return(result)
}


#' Define EPM arm zones from coordinates
#'
#' Calculates which EPM arm or center platform the animal is in based on
#' X/Y coordinates and maze geometry.
#'
#' EPM geometry:
#' - North arm (open): positive Y, |X| < arm_width/2
#' - South arm (open): negative Y, |X| < arm_width/2
#' - East arm (closed): positive X, |Y| < arm_width/2
#' - West arm (closed): negative X, |Y| < arm_width/2
#' - Center: sqrt(X^2 + Y^2) < center_radius
#'
#' @param x Numeric vector. X coordinates (in cm, centered)
#' @param y Numeric vector. Y coordinates (in cm, centered)
#' @param arena_config List. Arena dimensions
#'
#' @return List with zone vectors:
#'   \describe{
#'     \item{zone_open_arms}{Numeric (0/1). In any open arm}
#'     \item{zone_closed_arms}{Numeric (0/1). In any closed arm}
#'     \item{zone_center}{Numeric (0/1). In center platform}
#'     \item{arm_id}{Character. Specific arm ("north", "south", "east", "west", "center", "none")}
#'   }
#'
#' @keywords internal
define_epm_zones <- function(x, y, arena_config) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  # Extract arena dimensions
  arm_length <- arena_config$arm_length
  arm_width <- arena_config$arm_width
  center_size <- arena_config$center_size
  open_arms <- arena_config$open_arms
  closed_arms <- arena_config$closed_arms

  # Calculate center radius (half of center_size)
  center_radius <- center_size / 2

  # Calculate arm threshold (distance from center to start of arm proper)
  arm_threshold <- center_radius

  # Initialize zone vectors
  n <- length(x)
  zone_open_arms <- numeric(n)
  zone_closed_arms <- numeric(n)
  zone_center <- numeric(n)
  arm_id <- character(n)

  # Calculate distance from center
  dist_from_center <- sqrt(x^2 + y^2)

  # Determine zone for each point
  for (i in 1:n) {
    if (is.na(x[i]) || is.na(y[i])) {
      # Missing data
      zone_open_arms[i] <- NA
      zone_closed_arms[i] <- NA
      zone_center[i] <- NA
      arm_id[i] <- NA
      next
    }

    xi <- x[i]
    yi <- y[i]
    disti <- dist_from_center[i]

    # Check if in center platform
    if (disti < center_radius) {
      zone_center[i] <- 1
      zone_open_arms[i] <- 0
      zone_closed_arms[i] <- 0
      arm_id[i] <- "center"
      next
    }

    # Check which arm (if any)
    # North arm: y > arm_threshold, |x| < arm_width/2
    if (yi > arm_threshold && abs(xi) < arm_width / 2) {
      arm_id[i] <- "north"
      if ("north" %in% open_arms) {
        zone_open_arms[i] <- 1
        zone_closed_arms[i] <- 0
      } else {
        zone_open_arms[i] <- 0
        zone_closed_arms[i] <- 1
      }
      zone_center[i] <- 0
      next
    }

    # South arm: y < -arm_threshold, |x| < arm_width/2
    if (yi < -arm_threshold && abs(xi) < arm_width / 2) {
      arm_id[i] <- "south"
      if ("south" %in% open_arms) {
        zone_open_arms[i] <- 1
        zone_closed_arms[i] <- 0
      } else {
        zone_open_arms[i] <- 0
        zone_closed_arms[i] <- 1
      }
      zone_center[i] <- 0
      next
    }

    # East arm: x > arm_threshold, |y| < arm_width/2
    if (xi > arm_threshold && abs(yi) < arm_width / 2) {
      arm_id[i] <- "east"
      if ("east" %in% open_arms) {
        zone_open_arms[i] <- 1
        zone_closed_arms[i] <- 0
      } else {
        zone_open_arms[i] <- 0
        zone_closed_arms[i] <- 1
      }
      zone_center[i] <- 0
      next
    }

    # West arm: x < -arm_threshold, |y| < arm_width/2
    if (xi < -arm_threshold && abs(yi) < arm_width / 2) {
      arm_id[i] <- "west"
      if ("west" %in% open_arms) {
        zone_open_arms[i] <- 1
        zone_closed_arms[i] <- 0
      } else {
        zone_open_arms[i] <- 0
        zone_closed_arms[i] <- 1
      }
      zone_center[i] <- 0
      next
    }

    # Not in any defined zone
    zone_open_arms[i] <- 0
    zone_closed_arms[i] <- 0
    zone_center[i] <- 0
    arm_id[i] <- "none"
  }

  # Return zone data
  result <- list(
    zone_open_arms = zone_open_arms,
    zone_closed_arms = zone_closed_arms,
    zone_center = zone_center,
    arm_id = arm_id
  )

  return(result)
}


#' Extract subject ID from filename
#'
#' Extracts subject identifier from EPM CSV filename.
#' Handles common DLC naming patterns like "ID7687_model_config.csv".
#'
#' @param file_path Character. Path to file
#'
#' @return Character. Subject ID
#'
#' @keywords internal
extract_subject_id <- function(file_path) {
  filename <- basename(file_path)

  # Try to extract ID pattern (e.g., "ID7687")
  id_match <- regexpr("ID[0-9]+", filename)
  if (id_match > 0) {
    return(regmatches(filename, id_match))
  }

  # Try other patterns (e.g., "Subject_1", "Mouse_A")
  id_match <- regexpr("(Subject|Mouse|Animal)_?[A-Z0-9]+", filename, ignore.case = TRUE)
  if (id_match > 0) {
    return(regmatches(filename, id_match))
  }

  # Fall back to filename without extension
  return(tools::file_path_sans_ext(filename))
}


#' Validate EPM data structure
#'
#' Checks that EPM data has required columns and valid values.
#'
#' @param epm_data List. EPM data structure from load_epm_data()
#'
#' @return NULL (stops with error if invalid)
#'
#' @keywords internal
validate_epm_data <- function(epm_data) {
  # Check structure
  if (!is.list(epm_data) || !"data" %in% names(epm_data)) {
    stop("epm_data must be a list with 'data' element", call. = FALSE)
  }

  df <- epm_data$data

  # Check required columns
  required_cols <- c("frame", "time", "x", "y", "zone_open_arms",
                     "zone_closed_arms", "zone_center", "arm_id")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  # Check zone vectors are binary (0/1 or NA)
  for (zone_col in c("zone_open_arms", "zone_closed_arms", "zone_center")) {
    valid_values <- df[[zone_col]] %in% c(0, 1, NA)
    if (!all(valid_values)) {
      stop("Zone column '", zone_col, "' must contain only 0, 1, or NA",
           call. = FALSE)
    }
  }

  # Check that zones don't overlap (except center which is mutually exclusive)
  for (i in 1:nrow(df)) {
    if (is.na(df$zone_open_arms[i])) next

    open <- df$zone_open_arms[i]
    closed <- df$zone_closed_arms[i]
    center <- df$zone_center[i]

    # If in center, should not be in open or closed arms
    if (center == 1 && (open == 1 || closed == 1)) {
      stop("Zone overlap detected at frame ", df$frame[i],
           ": point cannot be in center and an arm simultaneously", call. = FALSE)
    }

    # Cannot be in both open and closed arms
    if (open == 1 && closed == 1) {
      stop("Zone overlap detected at frame ", df$frame[i],
           ": point cannot be in both open and closed arms", call. = FALSE)
    }
  }

  message("EPM data validation passed")
  return(invisible(NULL))
}


#' Summarize EPM data
#'
#' Provides quick summary statistics for EPM tracking data.
#'
#' @param epm_data List. EPM data structure from load_epm_data()
#'
#' @return Invisibly returns summary list, prints to console
#'
#' @examples
#' \dontrun{
#' epm_data <- load_epm_data("ID7687_DLC.csv")
#' summarize_epm_data(epm_data)
#' }
#'
#' @export
summarize_epm_data <- function(epm_data) {
  if (!is.list(epm_data) || !"data" %in% names(epm_data)) {
    stop("epm_data must be a valid EPM data structure", call. = FALSE)
  }

  df <- epm_data$data

  cat("\n=== EPM Data Summary ===\n")
  cat("Subject ID:        ", epm_data$subject_id, "\n")
  cat("Frames:            ", epm_data$n_frames, "\n")
  cat("Duration:          ", sprintf("%.1f sec", max(df$time, na.rm = TRUE)), "\n")
  cat("FPS:               ", epm_data$fps, "\n")
  cat("Body part:         ", epm_data$body_part, "\n")
  cat("Pixels/cm:         ", sprintf("%.2f", epm_data$pixels_per_cm), "\n\n")

  cat("Zone Occupancy:\n")
  pct_open <- mean(df$zone_open_arms, na.rm = TRUE) * 100
  pct_closed <- mean(df$zone_closed_arms, na.rm = TRUE) * 100
  pct_center <- mean(df$zone_center, na.rm = TRUE) * 100
  pct_none <- mean(df$zone_open_arms == 0 & df$zone_closed_arms == 0 & df$zone_center == 0, na.rm = TRUE) * 100

  cat(sprintf("  Open arms:    %6.2f%%\n", pct_open))
  cat(sprintf("  Closed arms:  %6.2f%%\n", pct_closed))
  cat(sprintf("  Center:       %6.2f%%\n", pct_center))
  cat(sprintf("  Outside:      %6.2f%%\n", pct_none))

  cat("\nArm Distribution:\n")
  arm_table <- table(df$arm_id)
  arm_pcts <- prop.table(arm_table) * 100
  for (arm in names(arm_pcts)) {
    cat(sprintf("  %s: %6.2f%%\n", arm, arm_pcts[arm]))
  }

  cat("\nCoordinate Ranges (cm):\n")
  cat(sprintf("  X: [%.2f, %.2f]\n", min(df$x, na.rm = TRUE), max(df$x, na.rm = TRUE)))
  cat(sprintf("  Y: [%.2f, %.2f]\n", min(df$y, na.rm = TRUE), max(df$y, na.rm = TRUE)))

  if ("likelihood" %in% names(df)) {
    cat("\nTracking Quality:\n")
    cat(sprintf("  Mean likelihood: %.3f\n", mean(df$likelihood, na.rm = TRUE)))
    cat(sprintf("  Min likelihood:  %.3f\n", min(df$likelihood, na.rm = TRUE)))
  }

  cat("\n")

  # Return summary invisibly
  summary_list <- list(
    subject_id = epm_data$subject_id,
    n_frames = epm_data$n_frames,
    duration_sec = max(df$time, na.rm = TRUE),
    pct_open = pct_open,
    pct_closed = pct_closed,
    pct_center = pct_center,
    arm_distribution = as.list(arm_pcts)
  )

  return(invisible(summary_list))
}
