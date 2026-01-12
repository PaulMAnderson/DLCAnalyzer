#' Geometric Calculations for DLCAnalyzer
#'
#' Functions for spatial calculations and distance metrics.
#'
#' @name geometry
NULL

#' Calculate Euclidean distance between two points
#'
#' Computes straight-line distance between points (x1, y1) and (x2, y2).
#'
#' @param x1 Numeric. X coordinate of first point
#' @param y1 Numeric. Y coordinate of first point
#' @param x2 Numeric. X coordinate of second point
#' @param y2 Numeric. Y coordinate of second point
#'
#' @return Numeric. Euclidean distance
#'
#' @examples
#' \dontrun{
#' dist <- euclidean_distance(0, 0, 3, 4)  # Returns 5
#' }
#'
#' @export
euclidean_distance <- function(x1, y1, x2, y2) {
  sqrt((x2 - x1)^2 + (y2 - y1)^2)
}

#' Calculate distances along a trajectory
#'
#' Computes distance between consecutive points in a trajectory.
#'
#' @param trajectory_df Data frame with columns x and y (and optionally frame/time)
#' @param x_col Character. Name of X coordinate column (default: "x")
#' @param y_col Character. Name of Y coordinate column (default: "y")
#'
#' @return Numeric vector of distances between consecutive points
#'   (length = nrow(trajectory_df) - 1)
#'
#' @examples
#' \dontrun{
#' df <- data.frame(x = c(0, 1, 2, 3), y = c(0, 0, 0, 0))
#' distances <- calculate_distances(df)  # Returns c(1, 1, 1)
#' }
#'
#' @export
calculate_distances <- function(trajectory_df, x_col = "x", y_col = "y") {
  if (!is.data.frame(trajectory_df)) {
    stop("trajectory_df must be a data frame", call. = FALSE)
  }

  if (!x_col %in% colnames(trajectory_df) || !y_col %in% colnames(trajectory_df)) {
    stop("Columns '", x_col, "' and '", y_col, "' must exist in trajectory_df",
         call. = FALSE)
  }

  x <- trajectory_df[[x_col]]
  y <- trajectory_df[[y_col]]

  if (length(x) < 2) {
    return(numeric(0))
  }

  # Calculate distance between consecutive points
  dx <- diff(x)
  dy <- diff(y)
  distances <- sqrt(dx^2 + dy^2)

  return(distances)
}

#' Calculate total distance traveled
#'
#' Sums distances along a trajectory to get total path length.
#'
#' @param trajectory_df Data frame with x and y columns
#' @param x_col Character. Name of X coordinate column (default: "x")
#' @param y_col Character. Name of Y coordinate column (default: "y")
#'
#' @return Numeric. Total distance (same units as coordinates)
#'
#' @examples
#' \dontrun{
#' df <- data.frame(x = c(0, 1, 2, 3), y = c(0, 0, 0, 0))
#' total <- calculate_total_distance(df)  # Returns 3
#' }
#'
#' @export
calculate_total_distance <- function(trajectory_df, x_col = "x", y_col = "y") {
  distances <- calculate_distances(trajectory_df, x_col = x_col, y_col = y_col)
  sum(distances, na.rm = TRUE)
}

#' Calculate distance traveled in zone
#'
#' Computes total distance while in a specific zone.
#'
#' @param trajectory_df Data frame with x, y, and zone columns
#' @param zone_column Character. Name of binary zone membership column
#' @param x_col Character. Name of X coordinate column (default: "x")
#' @param y_col Character. Name of Y coordinate column (default: "y")
#'
#' @return Numeric. Distance traveled while in zone
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   x = c(0, 1, 2, 3, 4),
#'   y = c(0, 0, 0, 0, 0),
#'   zone = c(1, 1, 1, 0, 0)
#' )
#' dist <- calculate_distance_by_zone(df, "zone")  # Returns 2
#' }
#'
#' @export
calculate_distance_by_zone <- function(trajectory_df, zone_column,
                                      x_col = "x", y_col = "y") {
  if (!is.data.frame(trajectory_df)) {
    stop("trajectory_df must be a data frame", call. = FALSE)
  }

  if (!zone_column %in% colnames(trajectory_df)) {
    stop("Zone column '", zone_column, "' not found in data", call. = FALSE)
  }

  if (!x_col %in% colnames(trajectory_df) || !y_col %in% colnames(trajectory_df)) {
    stop("Coordinate columns not found in data", call. = FALSE)
  }

  x <- trajectory_df[[x_col]]
  y <- trajectory_df[[y_col]]
  zone <- trajectory_df[[zone_column]]

  if (length(x) < 2) {
    return(0)
  }

  # Calculate distances
  dx <- diff(x)
  dy <- diff(y)
  distances <- sqrt(dx^2 + dy^2)

  # Only count distance when in zone
  # Use zone[2:length] to align with distances
  in_zone <- zone[-1] == 1

  total_distance <- sum(distances[in_zone], na.rm = TRUE)

  return(total_distance)
}

#' Calculate velocity
#'
#' Computes instantaneous velocity between consecutive frames.
#'
#' @param trajectory_df Data frame with x, y, and time columns
#' @param x_col Character. Name of X coordinate column (default: "x")
#' @param y_col Character. Name of Y coordinate column (default: "y")
#' @param time_col Character. Name of time column (default: "time")
#'
#' @return Numeric vector of velocities (distance/time units)
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   x = c(0, 1, 2, 3),
#'   y = c(0, 0, 0, 0),
#'   time = c(0, 1, 2, 3)
#' )
#' velocities <- calculate_velocity(df)  # Returns c(1, 1, 1)
#' }
#'
#' @export
calculate_velocity <- function(trajectory_df, x_col = "x", y_col = "y",
                               time_col = "time") {
  if (!is.data.frame(trajectory_df)) {
    stop("trajectory_df must be a data frame", call. = FALSE)
  }

  required_cols <- c(x_col, y_col, time_col)
  missing_cols <- setdiff(required_cols, colnames(trajectory_df))
  if (length(missing_cols) > 0) {
    stop("Missing columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  if (nrow(trajectory_df) < 2) {
    return(numeric(0))
  }

  # Calculate distances
  distances <- calculate_distances(trajectory_df, x_col = x_col, y_col = y_col)

  # Calculate time differences
  time_diffs <- diff(trajectory_df[[time_col]])

  # Avoid division by zero
  time_diffs[time_diffs == 0] <- NA

  # Velocity = distance / time
  velocities <- distances / time_diffs

  return(velocities)
}

#' Calculate average velocity
#'
#' Computes mean velocity across trajectory.
#'
#' @param trajectory_df Data frame with x, y, and time columns
#' @param x_col Character. Name of X coordinate column (default: "x")
#' @param y_col Character. Name of Y coordinate column (default: "y")
#' @param time_col Character. Name of time column (default: "time")
#'
#' @return Numeric. Average velocity
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   x = c(0, 1, 2, 3),
#'   y = c(0, 0, 0, 0),
#'   time = c(0, 1, 2, 3)
#' )
#' avg_vel <- calculate_average_velocity(df)  # Returns 1
#' }
#'
#' @export
calculate_average_velocity <- function(trajectory_df, x_col = "x", y_col = "y",
                                      time_col = "time") {
  velocities <- calculate_velocity(trajectory_df, x_col = x_col, y_col = y_col,
                                   time_col = time_col)
  mean(velocities, na.rm = TRUE)
}

#' Point in rectangle test
#'
#' Tests if a point (x, y) is inside a rectangle.
#'
#' @param x Numeric. X coordinate
#' @param y Numeric. Y coordinate
#' @param x_min Numeric. Rectangle minimum X
#' @param x_max Numeric. Rectangle maximum X
#' @param y_min Numeric. Rectangle minimum Y
#' @param y_max Numeric. Rectangle maximum Y
#'
#' @return Logical. TRUE if point is inside rectangle
#'
#' @examples
#' \dontrun{
#' in_rect <- point_in_rectangle(5, 5, 0, 10, 0, 10)  # Returns TRUE
#' }
#'
#' @export
point_in_rectangle <- function(x, y, x_min, x_max, y_min, y_max) {
  x >= x_min & x <= x_max & y >= y_min & y <= y_max
}

#' Point in circle test
#'
#' Tests if a point (x, y) is inside a circle.
#'
#' @param x Numeric. X coordinate of point
#' @param y Numeric. Y coordinate of point
#' @param center_x Numeric. Circle center X
#' @param center_y Numeric. Circle center Y
#' @param radius Numeric. Circle radius
#'
#' @return Logical. TRUE if point is inside circle
#'
#' @examples
#' \dontrun{
#' in_circle <- point_in_circle(1, 1, 0, 0, 2)  # Returns TRUE
#' }
#'
#' @export
point_in_circle <- function(x, y, center_x, center_y, radius) {
  dist <- sqrt((x - center_x)^2 + (y - center_y)^2)
  dist <= radius
}

#' Calculate bounding box from coordinates
#'
#' Computes min/max X and Y from a set of points.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#'
#' @return List with elements: x_min, x_max, y_min, y_max
#'
#' @examples
#' \dontrun{
#' x <- c(1, 2, 3, 4, 5)
#' y <- c(2, 3, 1, 4, 2)
#' bbox <- calculate_bounding_box(x, y)
#' }
#'
#' @export
calculate_bounding_box <- function(x, y) {
  list(
    x_min = min(x, na.rm = TRUE),
    x_max = max(x, na.rm = TRUE),
    y_min = min(y, na.rm = TRUE),
    y_max = max(y, na.rm = TRUE)
  )
}

#' Infer zone boundaries from zone membership data
#'
#' Reverse-engineers approximate zone boundaries from tracking data and
#' binary zone membership. Useful for visualization when zone geometry
#' is not explicitly defined.
#'
#' @param x Numeric vector. X coordinates
#' @param y Numeric vector. Y coordinates
#' @param zone_vector Numeric vector. Binary (0/1) zone membership
#'
#' @return List with bounding box of zone (x_min, x_max, y_min, y_max)
#'
#' @examples
#' \dontrun{
#' x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
#' y <- c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2)
#' zone <- c(1, 1, 1, 1, 1, 0, 0, 0, 0, 0)
#' bounds <- infer_zone_boundaries(x, y, zone)
#' }
#'
#' @export
infer_zone_boundaries <- function(x, y, zone_vector) {
  if (length(x) != length(y) || length(x) != length(zone_vector)) {
    stop("x, y, and zone_vector must have the same length", call. = FALSE)
  }

  # Get points where zone == 1
  in_zone <- zone_vector == 1 & !is.na(zone_vector)

  if (sum(in_zone) == 0) {
    warning("No points found in zone", call. = FALSE)
    return(list(x_min = NA, x_max = NA, y_min = NA, y_max = NA))
  }

  x_in_zone <- x[in_zone]
  y_in_zone <- y[in_zone]

  # Calculate bounding box
  bounds <- calculate_bounding_box(x_in_zone, y_in_zone)

  return(bounds)
}
