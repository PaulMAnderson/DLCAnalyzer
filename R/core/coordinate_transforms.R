#' Coordinate Transformation Utilities
#'
#' Functions for transforming coordinates between different coordinate systems
#' and units (pixels to cm, rotations, translations, etc.).
#'
#' @name coordinate_transforms
NULL

#' Calculate scale factor from two reference points
#'
#' Calculates pixels per cm conversion factor from two reference points
#' with a known real-world distance between them.
#'
#' @param point1 Named numeric vector with x and y coordinates
#' @param point2 Named numeric vector with x and y coordinates
#' @param real_distance_cm Numeric. Known distance between points in cm
#'
#' @return Numeric. Pixels per cm scale factor
#'
#' @examples
#' \dontrun{
#' p1 <- c(x = 100, y = 100)
#' p2 <- c(x = 100, y = 200)
#' scale <- calculate_scale_from_points(p1, p2, real_distance_cm = 10)
#' # If distance is 100 pixels and real distance is 10 cm, scale = 10 pixels/cm
#' }
#'
#' @export
calculate_scale_from_points <- function(point1, point2, real_distance_cm) {
  if (!is.numeric(point1) || !is.numeric(point2)) {
    stop("Points must be numeric vectors", call. = FALSE)
  }

  if (!all(c("x", "y") %in% names(point1)) || !all(c("x", "y") %in% names(point2))) {
    stop("Points must have named 'x' and 'y' coordinates", call. = FALSE)
  }

  if (!is.numeric(real_distance_cm) || real_distance_cm <= 0) {
    stop("real_distance_cm must be a positive number", call. = FALSE)
  }

  # Calculate Euclidean distance in pixels
  dx <- point2["x"] - point1["x"]
  dy <- point2["y"] - point1["y"]
  pixel_distance <- sqrt(dx^2 + dy^2)

  if (pixel_distance == 0) {
    stop("Points are identical, cannot calculate scale", call. = FALSE)
  }

  # Calculate pixels per cm (remove names to return unnamed numeric)
  pixels_per_cm <- as.numeric(pixel_distance / real_distance_cm)

  return(pixels_per_cm)
}

#' Calculate scale from arena calibration
#'
#' Extracts scale information from an arena_config object that has
#' calibration information.
#'
#' @param arena An arena_config object
#' @param point1_name Character. Name of first calibration point
#' @param point2_name Character. Name of second calibration point
#' @param real_distance_cm Numeric. Known distance in cm (optional if in metadata)
#'
#' @return Numeric. Pixels per cm scale factor
#'
#' @examples
#' \dontrun{
#' arena <- load_arena_configs("arena.yaml", "arena1")
#' scale <- calculate_arena_scale(arena, "top_left", "top_right", 50)
#' }
#'
#' @export
calculate_arena_scale <- function(arena, point1_name, point2_name, real_distance_cm = NULL) {
  if (!is_arena_config(arena)) {
    stop("arena must be an arena_config object", call. = FALSE)
  }

  # Try to get real distance from metadata if not provided
  if (is.null(real_distance_cm)) {
    if (!is.null(arena$metadata$calibration$real_distance_cm)) {
      real_distance_cm <- arena$metadata$calibration$real_distance_cm
    } else {
      stop("real_distance_cm must be provided or defined in arena metadata",
           call. = FALSE)
    }
  }

  # Get points
  p1 <- get_arena_point(arena, point1_name)
  p2 <- get_arena_point(arena, point2_name)

  # Calculate scale
  scale <- calculate_scale_from_points(p1, p2, real_distance_cm)

  return(scale)
}

#' Transform coordinates from pixels to cm
#'
#' Converts x, y coordinates from pixels to centimeters using a scale factor.
#'
#' @param x Numeric vector of x coordinates in pixels
#' @param y Numeric vector of y coordinates in pixels
#' @param pixels_per_cm Numeric. Scale factor (pixels per cm)
#'
#' @return Data frame with x and y columns in cm
#'
#' @examples
#' \dontrun{
#' coords_cm <- pixels_to_cm(x = c(100, 200), y = c(150, 250), pixels_per_cm = 10)
#' }
#'
#' @export
pixels_to_cm <- function(x, y, pixels_per_cm) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (!is.numeric(pixels_per_cm) || pixels_per_cm <= 0) {
    stop("pixels_per_cm must be a positive number", call. = FALSE)
  }

  data.frame(
    x = x / pixels_per_cm,
    y = y / pixels_per_cm,
    stringsAsFactors = FALSE
  )
}

#' Transform coordinates from cm to pixels
#'
#' Converts x, y coordinates from centimeters to pixels using a scale factor.
#'
#' @param x Numeric vector of x coordinates in cm
#' @param y Numeric vector of y coordinates in cm
#' @param pixels_per_cm Numeric. Scale factor (pixels per cm)
#'
#' @return Data frame with x and y columns in pixels
#'
#' @examples
#' \dontrun{
#' coords_px <- cm_to_pixels(x = c(10, 20), y = c(15, 25), pixels_per_cm = 10)
#' }
#'
#' @export
cm_to_pixels <- function(x, y, pixels_per_cm) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (!is.numeric(pixels_per_cm) || pixels_per_cm <= 0) {
    stop("pixels_per_cm must be a positive number", call. = FALSE)
  }

  data.frame(
    x = x * pixels_per_cm,
    y = y * pixels_per_cm,
    stringsAsFactors = FALSE
  )
}

#' Transform tracking data coordinates
#'
#' Applies coordinate transformations to a tracking_data object.
#' Can convert units (pixels to cm) and apply spatial transformations.
#'
#' @param tracking_data A tracking_data object
#' @param to_units Character. Target units ("cm" or "pixels")
#' @param pixels_per_cm Numeric. Scale factor (required if converting units)
#' @param origin Numeric vector c(x, y). New origin point (optional)
#' @param flip_y Logical. Flip y-axis (for image coordinate systems)
#'
#' @return tracking_data object with transformed coordinates
#'
#' @examples
#' \dontrun{
#' # Convert from pixels to cm
#' data_cm <- transform_tracking_coords(
#'   tracking_data,
#'   to_units = "cm",
#'   pixels_per_cm = 10
#' )
#'
#' # Convert and flip y-axis
#' data_transformed <- transform_tracking_coords(
#'   tracking_data,
#'   to_units = "cm",
#'   pixels_per_cm = 10,
#'   flip_y = TRUE
#' )
#' }
#'
#' @export
transform_tracking_coords <- function(tracking_data, to_units = NULL,
                                       pixels_per_cm = NULL, origin = NULL,
                                       flip_y = FALSE) {
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  # Get current units
  current_units <- tracking_data$metadata$units
  if (is.null(current_units)) {
    current_units <- "pixels"
  }

  # Make a copy
  result <- tracking_data

  # Unit conversion
  if (!is.null(to_units) && to_units != current_units) {
    if (is.null(pixels_per_cm)) {
      # Try to get from arena config
      if (!is.null(tracking_data$arena$scale)) {
        pixels_per_cm <- tracking_data$arena$scale
      } else {
        stop("pixels_per_cm must be provided for unit conversion", call. = FALSE)
      }
    }

    if (current_units == "pixels" && to_units == "cm") {
      # Convert pixels to cm
      result$tracking$x <- result$tracking$x / pixels_per_cm
      result$tracking$y <- result$tracking$y / pixels_per_cm

      # Update arena dimensions if present
      if (!is.null(result$arena$dimensions)) {
        result$arena$dimensions$width <- result$arena$dimensions$width / pixels_per_cm
        result$arena$dimensions$height <- result$arena$dimensions$height / pixels_per_cm
        result$arena$dimensions$units <- "cm"
      }

      # Update reference points if present
      if (!is.null(result$arena$reference_points)) {
        result$arena$reference_points$x <- result$arena$reference_points$x / pixels_per_cm
        result$arena$reference_points$y <- result$arena$reference_points$y / pixels_per_cm
      }

      result$metadata$units <- "cm"

    } else if (current_units == "cm" && to_units == "pixels") {
      # Convert cm to pixels
      result$tracking$x <- result$tracking$x * pixels_per_cm
      result$tracking$y <- result$tracking$y * pixels_per_cm

      # Update arena dimensions if present
      if (!is.null(result$arena$dimensions)) {
        result$arena$dimensions$width <- result$arena$dimensions$width * pixels_per_cm
        result$arena$dimensions$height <- result$arena$dimensions$height * pixels_per_cm
        result$arena$dimensions$units <- "pixels"
      }

      # Update reference points if present
      if (!is.null(result$arena$reference_points)) {
        result$arena$reference_points$x <- result$arena$reference_points$x * pixels_per_cm
        result$arena$reference_points$y <- result$arena$reference_points$y * pixels_per_cm
      }

      result$metadata$units <- "pixels"
    } else {
      stop("Cannot convert from ", current_units, " to ", to_units, call. = FALSE)
    }
  }

  # Origin translation
  if (!is.null(origin)) {
    if (!is.numeric(origin) || length(origin) != 2) {
      stop("origin must be a numeric vector of length 2", call. = FALSE)
    }

    result$tracking$x <- result$tracking$x - origin[1]
    result$tracking$y <- result$tracking$y - origin[2]

    # Update reference points if present
    if (!is.null(result$arena$reference_points)) {
      result$arena$reference_points$x <- result$arena$reference_points$x - origin[1]
      result$arena$reference_points$y <- result$arena$reference_points$y - origin[2]
    }
  }

  # Y-axis flip (for image coordinate systems where y increases downward)
  if (flip_y) {
    max_y <- max(result$tracking$y, na.rm = TRUE)
    result$tracking$y <- max_y - result$tracking$y

    # Update reference points if present
    if (!is.null(result$arena$reference_points)) {
      result$arena$reference_points$y <- max_y - result$arena$reference_points$y
    }
  }

  # Validate the result
  validate_tracking_data(result)

  return(result)
}

#' Rotate coordinates around a center point
#'
#' Rotates x, y coordinates by an angle around a center point.
#'
#' @param x Numeric vector of x coordinates
#' @param y Numeric vector of y coordinates
#' @param angle Numeric. Rotation angle in degrees (counterclockwise)
#' @param center Numeric vector c(x, y). Center of rotation (default: origin)
#'
#' @return Data frame with rotated x and y columns
#'
#' @examples
#' \dontrun{
#' coords_rotated <- rotate_coordinates(
#'   x = c(1, 2, 3),
#'   y = c(1, 2, 3),
#'   angle = 90,
#'   center = c(0, 0)
#' )
#' }
#'
#' @export
rotate_coordinates <- function(x, y, angle, center = c(0, 0)) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (!is.numeric(angle)) {
    stop("angle must be numeric", call. = FALSE)
  }

  if (!is.numeric(center) || length(center) != 2) {
    stop("center must be a numeric vector of length 2", call. = FALSE)
  }

  # Convert angle to radians
  angle_rad <- angle * pi / 180

  # Translate to origin
  x_translated <- x - center[1]
  y_translated <- y - center[2]

  # Apply rotation matrix
  cos_angle <- cos(angle_rad)
  sin_angle <- sin(angle_rad)

  x_rotated <- x_translated * cos_angle - y_translated * sin_angle
  y_rotated <- x_translated * sin_angle + y_translated * cos_angle

  # Translate back
  x_final <- x_rotated + center[1]
  y_final <- y_rotated + center[2]

  data.frame(
    x = x_final,
    y = y_final,
    stringsAsFactors = FALSE
  )
}

#' Center coordinates around a reference point
#'
#' Translates coordinates so that a reference point becomes the origin.
#'
#' @param x Numeric vector of x coordinates
#' @param y Numeric vector of y coordinates
#' @param reference_point Numeric vector c(x, y). Point to center on
#'
#' @return Data frame with centered x and y columns
#'
#' @examples
#' \dontrun{
#' coords_centered <- center_coordinates(
#'   x = c(100, 200, 300),
#'   y = c(150, 250, 350),
#'   reference_point = c(200, 250)
#' )
#' }
#'
#' @export
center_coordinates <- function(x, y, reference_point) {
  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (!is.numeric(reference_point) || length(reference_point) != 2) {
    stop("reference_point must be a numeric vector of length 2", call. = FALSE)
  }

  data.frame(
    x = x - reference_point[1],
    y = y - reference_point[2],
    stringsAsFactors = FALSE
  )
}

#' Apply arena-based coordinate transformation
#'
#' Applies coordinate transformation to tracking data based on arena configuration.
#' This is a high-level function that handles scale conversion and any arena-specific
#' transformations.
#'
#' @param tracking_data A tracking_data object
#' @param arena An arena_config object
#' @param to_units Character. Target units ("cm" or "pixels", default: "cm")
#'
#' @return tracking_data object with transformed coordinates
#'
#' @examples
#' \dontrun{
#' arena <- load_arena_configs("arena.yaml", "arena1")
#' data_transformed <- apply_arena_transform(tracking_data, arena)
#' }
#'
#' @export
apply_arena_transform <- function(tracking_data, arena, to_units = "cm") {
  if (!is_tracking_data(tracking_data)) {
    stop("tracking_data must be a tracking_data object", call. = FALSE)
  }

  if (!is_arena_config(arena)) {
    stop("arena must be an arena_config object", call. = FALSE)
  }

  # Use arena scale if available
  pixels_per_cm <- arena$scale

  if (is.null(pixels_per_cm)) {
    warning("Arena has no scale information. Cannot convert units.",
            call. = FALSE)
    return(tracking_data)
  }

  # Apply transformation
  result <- transform_tracking_coords(
    tracking_data,
    to_units = to_units,
    pixels_per_cm = pixels_per_cm
  )

  # Attach arena config to result
  result$arena$config_id <- arena$id

  return(result)
}
