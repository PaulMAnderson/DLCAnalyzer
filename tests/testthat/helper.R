#' Helper Functions for Testing
#'
#' This file contains helper functions used across multiple test files.

#' Create a mock tracking_data object for testing
#'
#' @param n_frames Number of frames to generate
#' @param bodyparts Character vector of body part names
#' @param fps Frames per second
#' @param add_noise Logical. Add random noise to coordinates
#'
#' @return A tracking_data object
create_mock_tracking_data <- function(n_frames = 100,
                                      bodyparts = c("bodycentre", "nose", "tail"),
                                      fps = 30,
                                      add_noise = TRUE) {

  # Generate tracking data for each body part
  tracking_list <- list()

  for (bp in bodyparts) {
    # Base trajectory (circular movement)
    t <- seq(0, 2*pi, length.out = n_frames)
    center_x <- 250
    center_y <- 250
    radius <- 100

    x <- center_x + radius * cos(t)
    y <- center_y + radius * sin(t)

    # Add noise if requested
    if (add_noise) {
      x <- x + rnorm(n_frames, 0, 5)
      y <- y + rnorm(n_frames, 0, 5)
    }

    bp_data <- data.frame(
      frame = 0:(n_frames - 1),
      time = seq(0, length.out = n_frames, by = 1/fps),
      body_part = bp,
      x = x,
      y = y,
      likelihood = runif(n_frames, 0.9, 1.0),
      stringsAsFactors = FALSE
    )

    tracking_list[[bp]] <- bp_data
  }

  # Combine all body parts
  tracking_df <- do.call(rbind, tracking_list)
  rownames(tracking_df) <- NULL

  # Create metadata
  metadata <- list(
    source = "mock",
    fps = fps,
    subject_id = "mock_subject",
    session_id = "mock_session",
    paradigm = "test",
    timestamp = Sys.time(),
    units = "pixels"
  )

  # Create arena
  arena <- list(
    dimensions = list(width = 500, height = 500, units = "pixels"),
    reference_points = NULL,
    zones = NULL
  )

  # Create tracking_data object
  tracking_data <- new_tracking_data(
    metadata = metadata,
    tracking = tracking_df,
    arena = arena
  )

  return(tracking_data)
}

#' Create a temporary DLC CSV file for testing
#'
#' @param bodyparts Character vector of body part names
#' @param n_frames Number of frames
#' @param fps Frames per second
#'
#' @return Path to temporary file
create_temp_dlc_file <- function(bodyparts = c("nose", "tail"),
                                 n_frames = 10,
                                 fps = 30) {

  temp_file <- tempfile(fileext = ".csv")

  # Build header rows
  scorer_row <- c("scorer", rep("DLC", length(bodyparts) * 3))
  bodyparts_row <- c("bodyparts", rep(bodyparts, each = 3))
  coords_row <- c("coords", rep(c("x", "y", "likelihood"), length(bodyparts)))

  # Generate data rows
  data_rows <- list()
  for (i in 0:(n_frames - 1)) {
    row <- c(i)
    for (bp in bodyparts) {
      # Simple linear movement
      x <- 100 + i * 10
      y <- 200 + i * 5
      likelihood <- 0.95
      row <- c(row, x, y, likelihood)
    }
    data_rows[[i + 1]] <- paste(row, collapse = ",")
  }

  # Write file
  writeLines(c(
    paste(scorer_row, collapse = ","),
    paste(bodyparts_row, collapse = ","),
    paste(coords_row, collapse = ","),
    data_rows
  ), temp_file)

  return(temp_file)
}

#' Check if two tracking_data objects are equivalent
#'
#' @param td1 First tracking_data object
#' @param td2 Second tracking_data object
#' @param tolerance Numeric tolerance for floating point comparisons
#'
#' @return Logical
tracking_data_equal <- function(td1, td2, tolerance = 1e-6) {
  if (!is_tracking_data(td1) || !is_tracking_data(td2)) {
    return(FALSE)
  }

  # Check metadata (excluding timestamp)
  metadata_fields <- setdiff(names(td1$metadata), "timestamp")
  for (field in metadata_fields) {
    if (!identical(td1$metadata[[field]], td2$metadata[[field]])) {
      return(FALSE)
    }
  }

  # Check tracking data dimensions
  if (nrow(td1$tracking) != nrow(td2$tracking)) {
    return(FALSE)
  }

  # Check tracking data columns
  if (!identical(names(td1$tracking), names(td2$tracking))) {
    return(FALSE)
  }

  # Check numeric columns with tolerance
  numeric_cols <- c("x", "y", "likelihood", "time")
  for (col in numeric_cols) {
    if (col %in% names(td1$tracking)) {
      if (!all(abs(td1$tracking[[col]] - td2$tracking[[col]]) < tolerance, na.rm = TRUE)) {
        return(FALSE)
      }
    }
  }

  return(TRUE)
}

#' Clean up temporary test files
#'
#' @param file_paths Character vector of file paths to remove
cleanup_temp_files <- function(file_paths) {
  for (path in file_paths) {
    if (file.exists(path)) {
      unlink(path)
    }
  }
}
