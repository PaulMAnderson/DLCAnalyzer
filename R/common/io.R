#' Enhanced I/O Functions for DLCAnalyzer
#'
#' Functions for reading data files with zone column extraction and multi-arena support.
#'
#' @name io_enhanced
NULL

#' Parse Ethovision sheet name
#'
#' Extracts arena_id and subject_id from Ethovision sheet names.
#'
#' @param sheet_name Character. Sheet name (e.g., "Track-Arena 1-Subject 1")
#'
#' @return A list with elements:
#'   \describe{
#'     \item{arena_id}{Numeric. Arena number}
#'     \item{subject_id}{Numeric. Subject number}
#'     \item{raw_name}{Character. Original sheet name}
#'   }
#'
#' @examples
#' \dontrun{
#' info <- parse_ethovision_sheet_name("Track-Arena 1-Subject 1")
#' # info$arena_id = 1, info$subject_id = 1
#' }
#'
#' @export
parse_ethovision_sheet_name <- function(sheet_name) {
  # Initialize result
  result <- list(
    arena_id = NA,
    subject_id = NA,
    raw_name = sheet_name
  )

  # Try to extract arena number
  arena_match <- regexpr("Arena[[:space:]]+([0-9]+)", sheet_name, ignore.case = TRUE)
  if (arena_match > 0) {
    arena_text <- regmatches(sheet_name, arena_match)
    arena_num <- as.numeric(sub(".*?([0-9]+).*", "\\1", arena_text))
    result$arena_id <- arena_num
  }

  # Try to extract subject number
  subject_match <- regexpr("Subject[[:space:]]+([0-9]+)", sheet_name, ignore.case = TRUE)
  if (subject_match > 0) {
    subject_text <- regmatches(sheet_name, subject_match)
    subject_num <- as.numeric(sub(".*?([0-9]+).*", "\\1", subject_text))
    result$subject_id <- subject_num
  }

  return(result)
}

#' Identify zone columns in Ethovision data
#'
#' Finds columns matching zone patterns (e.g., "In zone(zone_name / body_part)").
#'
#' @param column_names Character vector. Column names from Ethovision data
#' @param paradigm Character. Paradigm type ("ld", "oft", "nort", "epm") to filter
#'   relevant zone patterns (optional)
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{column_name}{Character. Original column name}
#'     \item{column_index}{Integer. Column index in data}
#'     \item{zone_name}{Character. Extracted zone name}
#'     \item{body_part}{Character. Body part (center-point, nose-point, tail-point)}
#'     \item{arena_number}{Numeric. Arena number if present in zone name}
#'   }
#'
#' @examples
#' \dontrun{
#' cols <- c("Trial time", "In zone(light floor 1 / Center-point)",
#'           "In zone(door area 1 / Center-point)")
#' zone_cols <- identify_zone_columns(cols, paradigm = "ld")
#' }
#'
#' @export
identify_zone_columns <- function(column_names, paradigm = NULL) {
  # Find columns matching zone pattern: "In zone(...)" ONLY (not "In zone 2")
  # "In zone 2" contains wall zones which are different from primary zones
  zone_pattern <- "^In zone\\("
  zone_indices <- grep(zone_pattern, column_names, ignore.case = TRUE)

  if (length(zone_indices) == 0) {
    return(data.frame(
      column_name = character(0),
      column_index = integer(0),
      zone_name = character(0),
      body_part = character(0),
      arena_number = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Parse each zone column
  zone_info <- lapply(zone_indices, function(idx) {
    col_name <- column_names[idx]

    # Extract content within parentheses
    # Pattern: "In zone(content)" or "In zone 2(content)"
    content_match <- regmatches(col_name, regexec("\\((.*)\\)", col_name))
    if (length(content_match[[1]]) < 2) {
      return(NULL)
    }

    content <- content_match[[1]][2]

    # Split by " / " to separate zone name and body part
    parts <- strsplit(content, " / ", fixed = TRUE)[[1]]

    if (length(parts) >= 2) {
      zone_name <- trimws(parts[1])
      body_part <- trimws(parts[2])
    } else {
      zone_name <- trimws(content)
      body_part <- "unknown"
    }

    # Try to extract arena number from zone name
    # Patterns: "light floor 1", "center1", "Arena 1", etc.
    arena_num <- NA
    arena_match <- regexpr("[[:space:]]?([0-9]+)$", zone_name)
    if (arena_match > 0) {
      arena_text <- regmatches(zone_name, arena_match)
      arena_num <- as.numeric(trimws(arena_text))
    }

    list(
      column_name = col_name,
      column_index = idx,
      zone_name = zone_name,
      body_part = body_part,
      arena_number = arena_num
    )
  })

  # Remove NULL entries
  zone_info <- Filter(Negate(is.null), zone_info)

  # Convert to data frame
  if (length(zone_info) == 0) {
    return(data.frame(
      column_name = character(0),
      column_index = integer(0),
      zone_name = character(0),
      body_part = character(0),
      arena_number = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  zone_df <- do.call(rbind, lapply(zone_info, as.data.frame, stringsAsFactors = FALSE))

  # Filter by paradigm if specified
  if (!is.null(paradigm)) {
    paradigm <- tolower(paradigm)

    # Define paradigm-specific zone patterns
    if (paradigm == "ld") {
      # LD uses "light floor" and "door area" zones
      pattern <- "light floor|door area"
      zone_df <- zone_df[grepl(pattern, zone_df$zone_name, ignore.case = TRUE), ]
    } else if (paradigm == "oft") {
      # OFT uses "center", "floor", "wall", "corner" zones
      pattern <- "center|floor|wall|corner"
      zone_df <- zone_df[grepl(pattern, zone_df$zone_name, ignore.case = TRUE), ]
    } else if (paradigm == "nort") {
      # NORT uses "object" zones
      pattern <- "object"
      zone_df <- zone_df[grepl(pattern, zone_df$zone_name, ignore.case = TRUE), ]
    } else if (paradigm == "epm") {
      # EPM uses "arm" and "center" zones
      pattern <- "arm|center"
      zone_df <- zone_df[grepl(pattern, zone_df$zone_name, ignore.case = TRUE), ]
    }
  }

  # Exclude parent "Arena" zone (always 100% coverage)
  zone_df <- zone_df[!grepl("^Arena[[:space:]]*[0-9]*$", zone_df$zone_name, ignore.case = TRUE), ]

  rownames(zone_df) <- NULL
  return(zone_df)
}

#' Filter zone columns by arena
#'
#' Extracts zone columns relevant to a specific arena number.
#'
#' @param df Data frame. Ethovision tracking data
#' @param zone_info Data frame. Output from identify_zone_columns()
#' @param arena_id Numeric. Arena number to filter
#' @param body_part Character. Body part to use (default: "Center-point")
#'
#' @return Data frame with only relevant zone columns, renamed for easy access
#'
#' @examples
#' \dontrun{
#' zone_info <- identify_zone_columns(colnames(df), paradigm = "ld")
#' arena1_zones <- filter_zone_columns(df, zone_info, arena_id = 1)
#' }
#'
#' @export
filter_zone_columns <- function(df, zone_info, arena_id, body_part = "Center-point") {
  # Filter to matching arena and body part
  # For zones WITHOUT arena numbers (single-arena files), include if body part matches
  # For zones WITH arena numbers, only include if arena number matches
  relevant_zones <- zone_info[
    (is.na(zone_info$arena_number) | zone_info$arena_number == arena_id) &
    tolower(zone_info$body_part) == tolower(body_part),
  ]

  if (nrow(relevant_zones) == 0) {
    warning("No zone columns found for arena ", arena_id, " and body part ", body_part)
    return(df)
  }

  # Extract zone columns
  zone_cols <- df[, relevant_zones$column_index, drop = FALSE]

  # Create simplified zone names for column names
  # "light floor 1" -> "zone_light_floor"
  # "door area 1" -> "zone_door_area"
  new_names <- sapply(relevant_zones$zone_name, function(zn) {
    # Remove arena number
    zn_clean <- sub("[[:space:]]*[0-9]+$", "", zn)
    # Replace spaces with underscores
    zn_clean <- gsub("[[:space:]]+", "_", trimws(zn_clean))
    # Add "zone_" prefix
    paste0("zone_", tolower(zn_clean))
  })

  colnames(zone_cols) <- new_names

  # Combine with original df (remove original zone columns first)
  df_clean <- df[, -zone_info$column_index, drop = FALSE]
  result <- cbind(df_clean, zone_cols)

  return(result)
}

#' Read Ethovision Excel file with zone extraction
#'
#' Enhanced version of read_ethovision_excel() that extracts and includes
#' zone membership columns alongside tracking data.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param sheet Character or numeric. Specific sheet to read, or NULL for first
#' @param skip_control Logical. Skip sheets with "Control" in name (default: TRUE)
#' @param paradigm Character. Paradigm type to filter zones ("ld", "oft", "nort", "epm")
#' @param body_part Character. Body part for zone analysis (default: "Center-point")
#' @param include_zones Logical. Include zone columns in output (default: TRUE)
#'
#' @return A list containing:
#'   \describe{
#'     \item{data}{Data frame with tracking data and zone columns}
#'     \item{metadata}{List of metadata from header}
#'     \item{zone_info}{Data frame with zone column information}
#'     \item{arena_id}{Numeric. Arena number from sheet name}
#'     \item{subject_id}{Numeric. Subject number from sheet name}
#'     \item{fps}{Frames per second}
#'     \item{n_frames}{Total number of frames}
#'     \item{filename}{Name of the source file}
#'     \item{sheet_name}{Name of the sheet}
#'   }
#'
#' @examples
#' \dontrun{
#' # Read LD data with zone extraction
#' ld_data <- read_ethovision_excel_enhanced(
#'   "LD_data.xlsx",
#'   paradigm = "ld",
#'   body_part = "Center-point"
#' )
#'
#' # Access zone columns directly
#' light_zone <- ld_data$data$zone_light_floor
#' }
#'
#' @export
read_ethovision_excel_enhanced <- function(file_path, fps = 25, sheet = NULL,
                                           skip_control = TRUE, paradigm = NULL,
                                           body_part = "Center-point",
                                           include_zones = TRUE) {
  # Check for readxl package
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required. Install with: install.packages('readxl')",
         call. = FALSE)
  }

  # Validate file
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path, call. = FALSE)
  }

  # Get sheet names
  all_sheets <- readxl::excel_sheets(file_path)

  # Determine which sheet to read
  if (is.null(sheet)) {
    if (skip_control) {
      available_sheets <- all_sheets[!grepl("Control", all_sheets, ignore.case = TRUE)]
    } else {
      available_sheets <- all_sheets
    }

    if (length(available_sheets) == 0) {
      stop("No suitable sheets found in file", call. = FALSE)
    }

    sheet_to_read <- available_sheets[1]
  } else {
    sheet_to_read <- sheet
  }

  # Parse sheet name for arena/subject info
  sheet_info <- parse_ethovision_sheet_name(sheet_to_read)

  # Read header information
  header_raw <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                   col_names = FALSE, n_max = 38)

  # Extract number of header lines
  n_header_lines <- as.numeric(header_raw[1, 2])
  if (is.na(n_header_lines)) {
    n_header_lines <- 38
  }

  # Extract metadata
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

  # Get column names
  col_names_raw <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                      col_names = FALSE, skip = 36, n_max = 1)
  col_names <- as.character(col_names_raw[1, ])

  # Replace empty column names with unique placeholders
  empty_idx <- which(col_names == "" | is.na(col_names))
  if (length(empty_idx) > 0) {
    col_names[empty_idx] <- paste0("empty_col_", empty_idx)
  }

  # Read tracking data
  tracking_data <- readxl::read_excel(file_path, sheet = sheet_to_read,
                                      skip = n_header_lines, col_names = col_names)

  # Convert "-" to NA
  tracking_data <- as.data.frame(lapply(tracking_data, function(col) {
    if (is.character(col)) {
      col[col == "-"] <- NA
      col_numeric <- suppressWarnings(as.numeric(col))
      if (!all(is.na(col_numeric))) {
        return(col_numeric)
      }
    }
    return(col)
  }), stringsAsFactors = FALSE)

  # Identify zone columns
  zone_info <- identify_zone_columns(col_names, paradigm = paradigm)

  # Filter zone columns by arena if arena_id is available
  if (include_zones && nrow(zone_info) > 0 && !is.na(sheet_info$arena_id)) {
    tracking_data <- filter_zone_columns(tracking_data, zone_info,
                                        arena_id = sheet_info$arena_id,
                                        body_part = body_part)
  }

  # Package results
  result <- list(
    data = tracking_data,
    metadata = metadata,
    zone_info = zone_info,
    arena_id = sheet_info$arena_id,
    subject_id = sheet_info$subject_id,
    fps = fps,
    n_frames = nrow(tracking_data),
    filename = basename(file_path),
    sheet_name = sheet_to_read
  )

  return(result)
}

#' Read all sheets from Ethovision Excel with zone extraction
#'
#' Reads all non-control sheets with zone extraction for multi-arena experiments.
#'
#' @param file_path Character. Path to the Ethovision Excel file
#' @param fps Numeric. Frames per second (default: 25)
#' @param skip_control Logical. Skip sheets with "Control" in name (default: TRUE)
#' @param paradigm Character. Paradigm type to filter zones
#' @param body_part Character. Body part for zone analysis (default: "Center-point")
#' @param include_zones Logical. Include zone columns in output (default: TRUE)
#'
#' @return A named list where each element is the result from
#'         read_ethovision_excel_enhanced() for one sheet. Names are sheet names.
#'
#' @examples
#' \dontrun{
#' # Read all arenas from LD file
#' ld_subjects <- read_ethovision_excel_multi_enhanced(
#'   "LD_data.xlsx",
#'   paradigm = "ld"
#' )
#'
#' # Access arena 1 data
#' arena1 <- ld_subjects[["Track-Arena 1-Subject 1"]]
#' }
#'
#' @export
read_ethovision_excel_multi_enhanced <- function(file_path, fps = 25,
                                                 skip_control = TRUE,
                                                 paradigm = NULL,
                                                 body_part = "Center-point",
                                                 include_zones = TRUE) {
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
    results[[sheet_name]] <- read_ethovision_excel_enhanced(
      file_path,
      fps = fps,
      sheet = sheet_name,
      skip_control = FALSE,
      paradigm = paradigm,
      body_part = body_part,
      include_zones = include_zones
    )
  }

  return(results)
}
