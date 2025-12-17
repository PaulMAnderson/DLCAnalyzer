#' Data Loading Functions for DLCAnalyzer
#'
#' Functions to load tracking data from various file formats.
#'
#' @name data_loading
NULL

#' Read DeepLabCut CSV file
#'
#' Reads tracking data from a DeepLabCut CSV export file. DLC files have a
#' specific multi-level header structure with scorer, bodyparts, and coordinate
#' information.
#'
#' The DLC CSV format has:
#' - Row 1: scorer information
#' - Row 2: body part names (repeated for each coordinate)
#' - Row 3: coordinate type (x, y, likelihood for each body part)
#' - Row 4+: tracking data
#'
#' @param file_path Character. Path to the DLC CSV file
#' @param fps Numeric. Frames per second of the recording (default: 30)
#' @param subject_id Character. Optional subject identifier
#' @param session_id Character. Optional session identifier
#'
#' @return A list containing:
#'   \describe{
#'     \item{raw_data}{Data frame with all raw tracking data}
#'     \item{scorer}{Character vector with scorer information}
#'     \item{bodyparts}{Character vector of body part names}
#'     \item{coords}{Character vector of coordinate types}
#'     \item{fps}{Frames per second}
#'     \item{n_frames}{Total number of frames}
#'     \item{filename}{Name of the source file}
#'   }
#'
#' @examples
#' \dontrun{
#' # Read a DLC file
#' dlc_data <- read_dlc_csv("path/to/dlc_output.csv", fps = 30)
#'
#' # Access body parts
#' body_parts <- unique(dlc_data$bodyparts)
#' }
#'
#' @export
read_dlc_csv <- function(file_path, fps = 30, subject_id = NULL, session_id = NULL) {
  # Validate inputs
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path,
         "\nPlease check the file path and try again.", call. = FALSE)
  }

  if (!is.numeric(fps) || fps <= 0) {
    stop("fps must be a positive number", call. = FALSE)
  }

  # Try to read the file
  tryCatch({
    # Read header rows
    scorer <- read.table(file_path, sep = ",", header = FALSE, nrows = 1,
                        stringsAsFactors = FALSE, skip = 0)
    bodyparts <- read.table(file_path, sep = ",", header = FALSE, nrows = 1,
                           stringsAsFactors = FALSE, skip = 1)
    coords <- read.table(file_path, sep = ",", header = FALSE, nrows = 1,
                        stringsAsFactors = FALSE, skip = 2)

    # Read data (skip first 3 header rows)
    raw_data <- read.table(file_path, sep = ",", header = FALSE,
                          skip = 3, stringsAsFactors = FALSE)

    # Convert headers to character vectors
    scorer_vec <- as.character(scorer[1, ])
    bodyparts_vec <- as.character(bodyparts[1, ])
    coords_vec <- as.character(coords[1, ])

    # Set column names
    colnames(raw_data) <- coords_vec

    # Extract filename
    filename <- basename(file_path)

    # Package results
    result <- list(
      raw_data = raw_data,
      scorer = scorer_vec,
      bodyparts = bodyparts_vec,
      coords = coords_vec,
      fps = fps,
      n_frames = nrow(raw_data),
      filename = filename
    )

    return(result)

  }, error = function(e) {
    stop("Failed to read DLC CSV file: ", file_path,
         "\nError: ", conditionMessage(e),
         "\n\nPlease ensure the file is a valid DeepLabCut CSV export.",
         call. = FALSE)
  })
}

#' Parse DLC raw data into structured format
#'
#' Converts the raw DLC data structure into a long-format data frame suitable
#' for conversion to tracking_data format.
#'
#' @param dlc_raw List returned by read_dlc_csv()
#'
#' @return A data frame in long format with columns:
#'   \describe{
#'     \item{frame}{Frame number (0-indexed from DLC)}
#'     \item{time}{Time in seconds}
#'     \item{body_part}{Body part name}
#'     \item{x}{X coordinate}
#'     \item{y}{Y coordinate}
#'     \item{likelihood}{Tracking confidence (0-1)}
#'   }
#'
#' @examples
#' \dontrun{
#' dlc_raw <- read_dlc_csv("data.csv", fps = 30)
#' tracking_df <- parse_dlc_data(dlc_raw)
#' }
#'
#' @export
parse_dlc_data <- function(dlc_raw) {
  # Extract components
  raw_data <- dlc_raw$raw_data
  bodyparts <- dlc_raw$bodyparts
  coords <- dlc_raw$coords
  fps <- dlc_raw$fps

  # First column should be frame numbers (named "coords" in DLC files)
  frame_col <- which(coords == "coords")[1]
  if (is.na(frame_col)) {
    stop("Could not find frame column in DLC data", call. = FALSE)
  }

  frames <- raw_data[, frame_col]

  # Initialize result data frame
  result <- data.frame()

  # Process each body part
  # Body parts are repeated every 3 columns (x, y, likelihood)
  # Start from column 2 (after coords/frame column)
  for (i in seq(from = 2, to = ncol(raw_data), by = 3)) {
    # Check if we have all three columns
    if (i + 2 > ncol(raw_data)) {
      warning("Incomplete coordinate triplet at column ", i, ", skipping",
              call. = FALSE)
      break
    }

    # Get body part name (from header row 2)
    body_part <- bodyparts[i]

    # Extract x, y, likelihood
    bp_data <- data.frame(
      frame = frames,
      time = frames / fps,
      body_part = body_part,
      x = as.numeric(raw_data[, i]),
      y = as.numeric(raw_data[, i + 1]),
      likelihood = as.numeric(raw_data[, i + 2]),
      stringsAsFactors = FALSE
    )

    # Append to result
    result <- rbind(result, bp_data)
  }

  # Ensure frame is integer
  result$frame <- as.integer(result$frame)

  # Order by frame and body part
  result <- result[order(result$frame, result$body_part), ]
  rownames(result) <- NULL

  return(result)
}

#' Get list of body parts from DLC data
#'
#' Extracts unique body part names from DLC raw data.
#'
#' @param dlc_raw List returned by read_dlc_csv()
#'
#' @return Character vector of unique body part names
#'
#' @examples
#' \dontrun{
#' dlc_raw <- read_dlc_csv("data.csv")
#' body_parts <- get_dlc_bodyparts(dlc_raw)
#' }
#'
#' @export
get_dlc_bodyparts <- function(dlc_raw) {
  bodyparts <- dlc_raw$bodyparts

  # Remove the first entry (usually "coords" column header)
  bodyparts <- bodyparts[-1]

  # Get unique body parts (they repeat every 3 columns)
  unique_bodyparts <- unique(bodyparts[seq(1, length(bodyparts), by = 3)])

  return(unique_bodyparts)
}

#' Calculate summary statistics for DLC tracking data
#'
#' Computes median position and tracking quality for each body part.
#'
#' @param dlc_raw List returned by read_dlc_csv() or data frame from parse_dlc_data()
#'
#' @return Data frame with columns:
#'   \describe{
#'     \item{body_part}{Body part name}
#'     \item{median_x}{Median X coordinate}
#'     \item{median_y}{Median Y coordinate}
#'     \item{mean_likelihood}{Mean tracking likelihood}
#'     \item{n_frames}{Number of valid frames}
#'     \item{pct_valid}{Percentage of frames with likelihood > 0.5}
#'   }
#'
#' @examples
#' \dontrun{
#' dlc_raw <- read_dlc_csv("data.csv")
#' summary_stats <- summarize_dlc_tracking(dlc_raw)
#' }
#'
#' @export
summarize_dlc_tracking <- function(dlc_raw) {
  # If dlc_raw is a list (from read_dlc_csv), parse it first
  if (is.list(dlc_raw) && "raw_data" %in% names(dlc_raw)) {
    tracking_df <- parse_dlc_data(dlc_raw)
  } else if (is.data.frame(dlc_raw)) {
    tracking_df <- dlc_raw
  } else {
    stop("dlc_raw must be output from read_dlc_csv() or parse_dlc_data()",
         call. = FALSE)
  }

  # Calculate summary by body part
  bodyparts <- unique(tracking_df$body_part)
  summary_list <- list()

  for (bp in bodyparts) {
    bp_data <- tracking_df[tracking_df$body_part == bp, ]

    summary_list[[bp]] <- data.frame(
      body_part = bp,
      median_x = median(bp_data$x, na.rm = TRUE),
      median_y = median(bp_data$y, na.rm = TRUE),
      mean_likelihood = mean(bp_data$likelihood, na.rm = TRUE),
      n_frames = nrow(bp_data),
      pct_valid = sum(bp_data$likelihood > 0.5, na.rm = TRUE) / nrow(bp_data) * 100,
      stringsAsFactors = FALSE
    )
  }

  # Combine into single data frame
  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  return(summary_df)
}

#' Check if file is a DeepLabCut CSV
#'
#' Attempts to determine if a file is a DLC CSV based on header structure.
#'
#' @param file_path Character. Path to the file to check
#'
#' @return Logical. TRUE if file appears to be DLC format, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (is_dlc_csv("data.csv")) {
#'   data <- read_dlc_csv("data.csv")
#' }
#' }
#'
#' @export
is_dlc_csv <- function(file_path) {
  if (!file.exists(file_path)) {
    return(FALSE)
  }

  tryCatch({
    # Read first few rows
    first_rows <- read.table(file_path, sep = ",", header = FALSE,
                            nrows = 3, stringsAsFactors = FALSE)

    # Check if first row contains "scorer" or looks like DLC scorer
    # Check if second row has repeated values (body parts)
    # Check if third row contains "coords", "x", "y", "likelihood"
    third_row <- as.character(first_rows[3, ])

    has_coords <- "coords" %in% third_row
    has_x <- "x" %in% third_row
    has_y <- "y" %in% third_row
    has_likelihood <- "likelihood" %in% third_row

    return(has_coords && has_x && has_y && has_likelihood)

  }, error = function(e) {
    return(FALSE)
  })
}
