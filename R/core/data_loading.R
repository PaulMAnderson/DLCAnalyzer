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

#' Read Ethovision XT Excel file
#'
#' Reads tracking data from an Ethovision XT Excel export file. Ethovision files
#' have a specific structure with metadata header rows and multiple sheets for
#' different arenas/subjects.
#'
#' The Ethovision Excel format has:
#' - Row 1: Number of header lines (typically 38)
#' - Rows 2-36: Metadata (experiment, trial, subject, arena info, etc.)
#' - Row 37: Column names
#' - Row 38: Units
#' - Rows 39+: Tracking data
#'
#' Each sheet represents one animal/arena combination. Sheets named with "Control"
#' are typically not tracking data and are skipped.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25, typical for Ethovision)
#' @param sheet Character or numeric. Specific sheet to read, or NULL for all non-control sheets
#' @param skip_control Logical. Skip sheets with "Control" in name (default: TRUE)
#'
#' @return A list containing:
#'   \describe{
#'     \item{data}{Data frame with all tracking data}
#'     \item{metadata}{List of metadata extracted from header}
#'     \item{column_info}{Data frame with column names and units}
#'     \item{fps}{Frames per second}
#'     \item{n_frames}{Total number of frames}
#'     \item{filename}{Name of the source file}
#'     \item{sheet_name}{Name of the sheet}
#'   }
#'
#' @examples
#' \dontrun{
#' # Read first non-control sheet
#' etho_data <- read_ethovision_excel("raw_data.xlsx")
#'
#' # Read specific sheet
#' etho_data <- read_ethovision_excel("raw_data.xlsx", sheet = "Track-Arena 1-Subject 1")
#'
#' # Read all sheets (returns list of data)
#' all_data <- read_ethovision_excel_multi("raw_data.xlsx")
#' }
#'
#' @export
read_ethovision_excel <- function(file_path, fps = 25, sheet = NULL, skip_control = TRUE) {
  # Check for readxl package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required to read Ethovision Excel files. Please install it with: install.packages('readxl')",
         call. = FALSE)
  }

  # Validate inputs
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path,
         "\nPlease check the file path and try again.", call. = FALSE)
  }

  if (!is.numeric(fps) || fps <= 0) {
    stop("fps must be a positive number", call. = FALSE)
  }

  tryCatch({
    # Get sheet names
    all_sheets <- readxl::excel_sheets(file_path)

    # Determine which sheet to read
    if (is.null(sheet)) {
      # Find first non-control sheet
      if (skip_control) {
        available_sheets <- all_sheets[!grepl("Control", all_sheets, ignore.case = TRUE)]
      } else {
        available_sheets <- all_sheets
      }

      if (length(available_sheets) == 0) {
        stop("No suitable sheets found in file. Available sheets: ",
             paste(all_sheets, collapse = ", "), call. = FALSE)
      }

      sheet_to_read <- available_sheets[1]
    } else {
      sheet_to_read <- sheet
    }

    # Read header information (first 38 rows, no column names)
    header_raw <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                     col_names = FALSE, n_max = 38)

    # Extract number of header lines
    n_header_lines <- as.numeric(header_raw[1, 2])
    if (is.na(n_header_lines)) {
      warning("Could not determine number of header lines, using default of 38")
      n_header_lines <- 38
    }

    # Extract metadata from header
    metadata <- list(
      experiment = as.character(header_raw[2, 2]),
      trial_name = as.character(header_raw[4, 2]),
      trial_id = as.character(header_raw[5, 2]),
      arena_name = as.character(header_raw[6, 2]),
      arena_id = as.character(header_raw[7, 2]),
      subject_name = as.character(header_raw[8, 2]),
      subject_id = as.character(header_raw[9, 2]),
      start_time = as.character(header_raw[13, 2]),
      trial_duration = as.character(header_raw[14, 2]),
      recording_duration = as.character(header_raw[16, 2])
    )

    # Get column names and units (rows 37 and 38)
    col_names_raw <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                        col_names = FALSE, skip = 36, n_max = 2)
    col_names <- as.character(col_names_raw[1, ])
    col_units <- as.character(col_names_raw[2, ])

    # Create column info dataframe
    column_info <- data.frame(
      column_name = col_names,
      unit = col_units,
      stringsAsFactors = FALSE
    )

    # Read the actual tracking data
    tracking_data <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                        skip = n_header_lines, col_names = col_names)

    # Convert "-" to NA (Ethovision uses "-" for missing data)
    tracking_data <- as.data.frame(lapply(tracking_data, function(col) {
      if (is.character(col)) {
        col[col == "-"] <- NA
        # Try to convert to numeric if possible
        col_numeric <- suppressWarnings(as.numeric(col))
        if (!all(is.na(col_numeric))) {
          return(col_numeric)
        }
      }
      return(col)
    }))

    # Extract filename
    filename <- basename(file_path)

    # Package results
    result <- list(
      data = tracking_data,
      metadata = metadata,
      column_info = column_info,
      fps = fps,
      n_frames = nrow(tracking_data),
      filename = filename,
      sheet_name = sheet_to_read
    )

    return(result)

  }, error = function(e) {
    stop("Failed to read Ethovision Excel file: ", file_path,
         "\nError: ", conditionMessage(e),
         "\n\nPlease ensure the file is a valid Ethovision XT Excel export.",
         call. = FALSE)
  })
}

#' Read all sheets from Ethovision XT Excel file
#'
#' Reads tracking data from all non-control sheets in an Ethovision Excel file.
#' Useful for experiments with multiple animals tracked in the same file.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param skip_control Logical. Skip sheets with "Control" in name (default: TRUE)
#'
#' @return A named list where each element is the result from read_ethovision_excel()
#'         for one sheet. Names are the sheet names.
#'
#' @examples
#' \dontrun{
#' # Read all animals from one file
#' all_animals <- read_ethovision_excel_multi("experiment_data.xlsx")
#'
#' # Access individual animals
#' animal1 <- all_animals[["Track-Arena 1-Subject 1"]]
#' }
#'
#' @export
read_ethovision_excel_multi <- function(file_path, fps = 25, skip_control = TRUE) {
  # Check for readxl package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required. Install with: install.packages('readxl')",
         call. = FALSE)
  }

  # Validate file
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path, call. = FALSE)
  }

  # Get all sheets
  all_sheets <- readxl::excel_sheets(file_path)

  # Filter sheets
  if (skip_control) {
    sheets_to_read <- all_sheets[!grepl("Control", all_sheets, ignore.case = TRUE)]
  } else {
    sheets_to_read <- all_sheets
  }

  if (length(sheets_to_read) == 0) {
    stop("No suitable sheets found in file", call. = FALSE)
  }

  # Read each sheet
  results <- list()
  for (sheet_name in sheets_to_read) {
    message("Reading sheet: ", sheet_name)
    results[[sheet_name]] <- read_ethovision_excel(file_path, fps = fps,
                                                    sheet = sheet_name,
                                                    skip_control = FALSE)
  }

  return(results)
}

#' Parse Ethovision data into structured format
#'
#' Converts Ethovision tracking data into a long-format data frame suitable
#' for conversion to tracking_data format. Extracts X/Y coordinates for all
#' tracked body parts.
#'
#' @param etho_raw List returned by read_ethovision_excel()
#'
#' @return A data frame in long format with columns:
#'   \describe{
#'     \item{frame}{Frame number (calculated from time and fps)}
#'     \item{time}{Time in seconds}
#'     \item{body_part}{Body part name (center, nose, tail, etc.)}
#'     \item{x}{X coordinate (in cm)}
#'     \item{y}{Y coordinate (in cm)}
#'     \item{likelihood}{Always 1.0 for Ethovision (no confidence scores)}
#'   }
#'
#' @examples
#' \dontrun{
#' etho_raw <- read_ethovision_excel("data.xlsx", fps = 25)
#' tracking_df <- parse_ethovision_data(etho_raw)
#' }
#'
#' @export
parse_ethovision_data <- function(etho_raw) {
  # Extract components
  data <- etho_raw$data
  fps <- etho_raw$fps
  col_info <- etho_raw$column_info

  # Find time column (usually "Recording time")
  time_col <- which(col_info$column_name == "Recording time")
  if (length(time_col) == 0) {
    time_col <- which(col_info$column_name == "Trial time")
  }
  if (length(time_col) == 0) {
    stop("Could not find time column in Ethovision data", call. = FALSE)
  }

  time_values <- data[[time_col[1]]]

  # Find all X/Y coordinate pairs
  # Ethovision typically has: "X center", "Y center", "X nose", "Y nose", "X tail", "Y tail"
  x_cols <- grep("^X ", col_info$column_name, ignore.case = TRUE)
  y_cols <- grep("^Y ", col_info$column_name, ignore.case = TRUE)

  if (length(x_cols) == 0 || length(y_cols) == 0) {
    stop("Could not find X/Y coordinate columns in Ethovision data", call. = FALSE)
  }

  # Initialize result data frame
  result <- data.frame()

  # Process each body part
  for (i in seq_along(x_cols)) {
    x_idx <- x_cols[i]
    y_idx <- y_cols[i]

    # Extract body part name from column name (e.g., "X center" -> "center")
    body_part <- gsub("^X ", "", col_info$column_name[x_idx], ignore.case = TRUE)
    body_part <- tolower(trimws(body_part))  # Standardize to lowercase

    # Create data frame for this body part
    bp_data <- data.frame(
      frame = seq_along(time_values) - 1,  # 0-indexed
      time = time_values,
      body_part = body_part,
      x = as.numeric(data[[x_idx]]),
      y = as.numeric(data[[y_idx]]),
      likelihood = 1.0,  # Ethovision doesn't provide likelihood, assume perfect tracking
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

#' Check if file is an Ethovision Excel file
#'
#' Attempts to determine if a file is an Ethovision Excel file based on
#' file extension and header structure.
#'
#' @param file_path Character. Path to the file to check
#'
#' @return Logical. TRUE if file appears to be Ethovision format, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (is_ethovision_excel("data.xlsx")) {
#'   data <- read_ethovision_excel("data.xlsx")
#' }
#' }
#'
#' @export
is_ethovision_excel <- function(file_path) {
  if (!file.exists(file_path)) {
    return(FALSE)
  }

  # Check file extension
  if (!grepl("\\.xlsx?$", file_path, ignore.case = TRUE)) {
    return(FALSE)
  }

  # Check for readxl package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    return(FALSE)
  }

  tryCatch({
    # Read first few rows
    header <- readxl::read_excel(file_path, sheet = 1, col_names = FALSE, n_max = 5)

    # Check if first row has "Number of header lines:"
    first_cell <- as.character(header[1, 1])
    has_header_marker <- grepl("Number of header lines", first_cell, ignore.case = TRUE)

    # Check if second row has "Experiment"
    second_cell <- as.character(header[2, 1])
    has_experiment <- grepl("Experiment", second_cell, ignore.case = TRUE)

    return(has_header_marker && has_experiment)

  }, error = function(e) {
    return(FALSE)
  })
}
