#' Arena Configuration Data Structures
#'
#' This file defines S3 classes and functions for handling arena/maze configurations.
#' Arena configurations describe the physical layout of experimental environments,
#' including reference points, zones, and coordinate transformations.
#'
#' @name arena_config
NULL

#' Create a new arena_config object
#'
#' Constructor function for the arena_config S3 class. This represents the
#' configuration for a single arena, including reference points, zones, and
#' coordinate system information.
#'
#' @param id Character. Unique identifier for this arena
#' @param image Character. Path to reference image (optional)
#' @param points Named list or data frame of reference points with x, y coordinates
#' @param zones List of zone definitions
#' @param scale Numeric. Pixels per cm conversion factor (optional)
#' @param metadata List with additional arena metadata (optional)
#'
#' @return An object of class 'arena_config'
#'
#' @examples
#' \dontrun{
#' # Create a simple arena configuration
#' arena <- new_arena_config(
#'   id = "arena1",
#'   image = "arena.png",
#'   points = list(
#'     top_left = c(x = 100, y = 100),
#'     top_right = c(x = 500, y = 100),
#'     bottom_left = c(x = 100, y = 400),
#'     bottom_right = c(x = 500, y = 400)
#'   ),
#'   zones = list()
#' )
#' }
#'
#' @export
new_arena_config <- function(id, image = NULL, points = NULL, zones = list(),
                              scale = NULL, metadata = list()) {
  # Convert points to data frame format if it's a list
  if (!is.null(points) && !is.data.frame(points)) {
    points_df <- data.frame(
      point_name = names(points),
      x = sapply(points, function(p) p["x"]),
      y = sapply(points, function(p) p["y"]),
      stringsAsFactors = FALSE
    )
    rownames(points_df) <- NULL
    points <- points_df
  }

  structure(
    list(
      id = id,
      image = image,
      points = points,
      zones = zones,
      scale = scale,
      metadata = metadata
    ),
    class = "arena_config"
  )
}

#' Validate an arena_config object
#'
#' Validates the structure and content of an arena_config object.
#'
#' @param x An arena_config object to validate
#'
#' @return The validated arena_config object (invisibly), or stops with error
#'
#' @export
validate_arena_config <- function(x) {
  if (!inherits(x, "arena_config")) {
    stop("Object must be of class 'arena_config'", call. = FALSE)
  }

  # Check required fields
  if (is.null(x$id) || !is.character(x$id)) {
    stop("arena_config must have a character 'id' field", call. = FALSE)
  }

  # Validate points if present
  if (!is.null(x$points)) {
    if (!is.data.frame(x$points)) {
      stop("arena_config$points must be a data frame", call. = FALSE)
    }

    required_cols <- c("point_name", "x", "y")
    missing_cols <- setdiff(required_cols, names(x$points))
    if (length(missing_cols) > 0) {
      stop("arena_config$points missing columns: ",
           paste(missing_cols, collapse = ", "), call. = FALSE)
    }

    # Check for duplicate point names
    if (any(duplicated(x$points$point_name))) {
      stop("arena_config$points contains duplicate point names", call. = FALSE)
    }
  }

  # Validate zones if present
  if (!is.null(x$zones) && length(x$zones) > 0) {
    if (!is.list(x$zones)) {
      stop("arena_config$zones must be a list", call. = FALSE)
    }

    # Validate each zone
    for (i in seq_along(x$zones)) {
      validate_zone(x$zones[[i]], i, x$points)
    }
  }

  # Validate scale if present
  if (!is.null(x$scale)) {
    if (!is.numeric(x$scale) || x$scale <= 0) {
      stop("arena_config$scale must be a positive number", call. = FALSE)
    }
  }

  invisible(x)
}

#' Validate a zone definition
#'
#' @param zone List representing a zone
#' @param zone_index Integer index of the zone (for error messages)
#' @param points Data frame of reference points
#'
#' @return Invisible NULL, or stops with error
#'
#' @keywords internal
validate_zone <- function(zone, zone_index, points = NULL) {
  if (!is.list(zone)) {
    stop("Zone ", zone_index, " must be a list", call. = FALSE)
  }

  # Check required fields
  if (is.null(zone$id)) {
    stop("Zone ", zone_index, " missing 'id' field", call. = FALSE)
  }

  if (is.null(zone$name)) {
    stop("Zone ", zone_index, " missing 'name' field", call. = FALSE)
  }

  if (is.null(zone$type)) {
    stop("Zone ", zone_index, " missing 'type' field", call. = FALSE)
  }

  # Validate type-specific fields
  valid_types <- c("points", "proportion", "circle", "rectangle")
  if (!(zone$type %in% valid_types)) {
    stop("Zone ", zone_index, " has invalid type '", zone$type,
         "'. Must be one of: ", paste(valid_types, collapse = ", "),
         call. = FALSE)
  }

  # For "points" type, verify point_names reference valid points
  if (zone$type == "points") {
    if (is.null(zone$point_names)) {
      stop("Zone ", zone_index, " (type 'points') missing 'point_names' field",
           call. = FALSE)
    }

    if (!is.null(points)) {
      missing_points <- setdiff(zone$point_names, points$point_name)
      if (length(missing_points) > 0) {
        stop("Zone ", zone_index, " references undefined points: ",
             paste(missing_points, collapse = ", "), call. = FALSE)
      }
    }
  }

  # For "proportion" type, verify parent_zone exists
  if (zone$type == "proportion") {
    if (is.null(zone$parent_zone)) {
      stop("Zone ", zone_index, " (type 'proportion') missing 'parent_zone' field",
           call. = FALSE)
    }

    if (is.null(zone$proportion)) {
      stop("Zone ", zone_index, " (type 'proportion') missing 'proportion' field",
           call. = FALSE)
    }
  }

  invisible(NULL)
}

#' Check if object is an arena_config
#'
#' @param x Object to test
#'
#' @return Logical
#'
#' @export
is_arena_config <- function(x) {
  inherits(x, "arena_config")
}

#' Print method for arena_config objects
#'
#' @param x An arena_config object
#' @param ... Additional arguments (not used)
#'
#' @return The object invisibly
#'
#' @export
print.arena_config <- function(x, ...) {
  cat("Arena Configuration\n")
  cat("===================\n\n")

  cat("ID:      ", x$id, "\n")

  if (!is.null(x$image)) {
    cat("Image:   ", x$image, "\n")
  }

  if (!is.null(x$scale)) {
    cat("Scale:   ", x$scale, " pixels/cm\n")
  }

  cat("\n")

  # Points
  if (!is.null(x$points) && nrow(x$points) > 0) {
    cat("Reference Points (", nrow(x$points), "):\n", sep = "")
    for (i in 1:min(5, nrow(x$points))) {
      cat("  ", x$points$point_name[i], ": (",
          x$points$x[i], ", ", x$points$y[i], ")\n", sep = "")
    }
    if (nrow(x$points) > 5) {
      cat("  ... and", nrow(x$points) - 5, "more\n")
    }
    cat("\n")
  }

  # Zones
  if (!is.null(x$zones) && length(x$zones) > 0) {
    cat("Zones (", length(x$zones), "):\n", sep = "")
    for (i in 1:min(5, length(x$zones))) {
      zone <- x$zones[[i]]
      cat("  ", zone$id, " (", zone$name, ") - type: ", zone$type, "\n", sep = "")
    }
    if (length(x$zones) > 5) {
      cat("  ... and", length(x$zones) - 5, "more\n")
    }
  }

  invisible(x)
}

#' Load arena configurations from YAML file
#'
#' Loads one or more arena configurations from a YAML file. The YAML file
#' should have an "arenas" key containing a list of arena definitions.
#'
#' @param yaml_file Character. Path to YAML file
#' @param arena_id Character. Specific arena ID to load (NULL loads all)
#'
#' @return A single arena_config object if arena_id specified,
#'         or a list of arena_config objects if loading all
#'
#' @examples
#' \dontrun{
#' # Load all arenas from file
#' arenas <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml")
#'
#' # Load specific arena
#' arena1 <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml", "arena1")
#' }
#'
#' @export
load_arena_configs <- function(yaml_file, arena_id = NULL) {
  # Load YAML using config_utils
  config <- read_config(yaml_file)

  if (is.null(config$arenas)) {
    stop("YAML file missing 'arenas' key", call. = FALSE)
  }

  # Parse each arena
  arena_list <- lapply(config$arenas, function(arena_def) {
    # Convert points list to expected format
    points <- NULL
    if (!is.null(arena_def$points)) {
      points <- data.frame(
        point_name = names(arena_def$points),
        x = sapply(arena_def$points, function(p) p[1]),
        y = sapply(arena_def$points, function(p) p[2]),
        stringsAsFactors = FALSE
      )
    }

    # Create arena_config object
    arena <- new_arena_config(
      id = arena_def$id,
      image = arena_def$image,
      points = points,
      zones = arena_def$zones,
      scale = arena_def$scale,
      metadata = arena_def$metadata
    )

    # Validate
    validate_arena_config(arena)

    return(arena)
  })

  # Name the list by arena IDs
  names(arena_list) <- sapply(arena_list, function(a) a$id)

  # Return specific arena if requested
  if (!is.null(arena_id)) {
    if (!(arena_id %in% names(arena_list))) {
      stop("Arena ID '", arena_id, "' not found in file", call. = FALSE)
    }
    return(arena_list[[arena_id]])
  }

  # Return all arenas
  return(arena_list)
}

#' Get point coordinates from arena
#'
#' Retrieves the x, y coordinates for a named point in an arena.
#'
#' @param arena An arena_config object
#' @param point_name Character. Name of the point
#'
#' @return Named numeric vector with x and y coordinates
#'
#' @export
get_arena_point <- function(arena, point_name) {
  if (!is_arena_config(arena)) {
    stop("arena must be an arena_config object", call. = FALSE)
  }

  if (is.null(arena$points)) {
    stop("Arena has no reference points defined", call. = FALSE)
  }

  point_row <- arena$points[arena$points$point_name == point_name, ]

  if (nrow(point_row) == 0) {
    stop("Point '", point_name, "' not found in arena", call. = FALSE)
  }

  return(c(x = point_row$x[1], y = point_row$y[1]))
}

#' Get zone definition from arena
#'
#' Retrieves a zone definition by ID.
#'
#' @param arena An arena_config object
#' @param zone_id Character. ID of the zone
#'
#' @return List representing the zone definition
#'
#' @export
get_arena_zone <- function(arena, zone_id) {
  if (!is_arena_config(arena)) {
    stop("arena must be an arena_config object", call. = FALSE)
  }

  if (is.null(arena$zones) || length(arena$zones) == 0) {
    stop("Arena has no zones defined", call. = FALSE)
  }

  # Find zone by ID
  zone_ids <- sapply(arena$zones, function(z) z$id)
  zone_idx <- which(zone_ids == zone_id)

  if (length(zone_idx) == 0) {
    stop("Zone '", zone_id, "' not found in arena", call. = FALSE)
  }

  return(arena$zones[[zone_idx[1]]])
}
