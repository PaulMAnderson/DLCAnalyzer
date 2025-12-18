#' Zone Geometry Functions
#'
#' Functions for creating and working with zone geometries in arena configurations.
#' Zones can be defined by points, proportions, circles, or rectangles.
#'
#' @name zone_geometry
NULL

#' Create zone geometry from arena zone definition
#'
#' Converts a zone definition from an arena_config into a geometry object
#' that can be used for point-in-zone testing.
#'
#' @param zone List. Zone definition from arena_config
#' @param arena arena_config object containing reference points
#' @param parent_zones List of already-created zone geometries (for proportion zones)
#'
#' @return A zone_geometry object containing polygon vertices or circle definition
#'
#' @examples
#' \dontrun{
#' arena <- load_arena_configs("arena.yaml", "arena1")
#' zone_def <- get_arena_zone(arena, "center")
#' geometry <- create_zone_geometry(zone_def, arena)
#' }
#'
#' @export
create_zone_geometry <- function(zone, arena, parent_zones = list()) {
  if (!is.list(zone) || is.null(zone$type)) {
    stop("Invalid zone definition", call. = FALSE)
  }

  geometry <- switch(zone$type,
    points = create_polygon_from_points(zone, arena),
    proportion = create_proportional_zone(zone, arena, parent_zones),
    circle = create_circle_zone(zone, arena),
    rectangle = create_rectangle_zone(zone, arena),
    stop("Unknown zone type: ", zone$type, call. = FALSE)
  )

  # Add zone metadata
  geometry$zone_id <- zone$id
  geometry$zone_name <- zone$name

  return(geometry)
}

#' Create polygon zone from points
#'
#' Creates a polygon zone geometry from named reference points.
#'
#' @param zone List with point_names field
#' @param arena arena_config object
#'
#' @return zone_geometry object with type "polygon"
#'
#' @keywords internal
create_polygon_from_points <- function(zone, arena) {
  if (is.null(zone$point_names) || length(zone$point_names) < 3) {
    stop("Polygon zones require at least 3 points", call. = FALSE)
  }

  # Get coordinates for each point
  vertices <- data.frame(
    x = numeric(length(zone$point_names)),
    y = numeric(length(zone$point_names)),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(zone$point_names)) {
    point <- get_arena_point(arena, zone$point_names[i])
    vertices$x[i] <- point["x"]
    vertices$y[i] <- point["y"]
  }

  structure(
    list(
      type = "polygon",
      vertices = vertices
    ),
    class = "zone_geometry"
  )
}

#' Create proportional zone
#'
#' Creates a zone as a proportion of a parent zone.
#'
#' @param zone List with parent_zone and proportion fields
#' @param arena arena_config object
#' @param parent_zones List of already-created zone geometries
#'
#' @return zone_geometry object
#'
#' @keywords internal
create_proportional_zone <- function(zone, arena, parent_zones) {
  if (is.null(zone$parent_zone)) {
    stop("Proportional zone missing parent_zone specification", call. = FALSE)
  }

  if (is.null(zone$proportion) || length(zone$proportion) != 4) {
    stop("Proportional zone must have proportion as [left, top, right, bottom]",
         call. = FALSE)
  }

  # Get parent zone geometry
  parent_geom <- parent_zones[[zone$parent_zone]]

  if (is.null(parent_geom)) {
    stop("Parent zone '", zone$parent_zone, "' not found. ",
         "Parent zones must be defined before child zones.", call. = FALSE)
  }

  # For now, only support proportional zones of polygon parents
  if (parent_geom$type != "polygon") {
    stop("Proportional zones currently only support polygon parents", call. = FALSE)
  }

  # Get bounding box of parent
  parent_bbox <- get_bbox_from_polygon(parent_geom$vertices)

  # Calculate proportional coordinates
  # Proportions are: [left_proportion, top_proportion, right_proportion, bottom_proportion]
  # Values can be >1 to extend beyond parent
  prop <- zone$proportion
  width <- parent_bbox$x_max - parent_bbox$x_min
  height <- parent_bbox$y_max - parent_bbox$y_min

  # For proportions >1, interpret as expansion factor
  # For proportions <1, interpret as relative position within parent
  x_min <- parent_bbox$x_min + prop[1] * width
  x_max <- parent_bbox$x_min + prop[3] * width
  y_min <- parent_bbox$y_min + prop[2] * height
  y_max <- parent_bbox$y_min + prop[4] * height

  # Create rectangle vertices
  vertices <- data.frame(
    x = c(x_min, x_max, x_max, x_min),
    y = c(y_min, y_min, y_max, y_max),
    stringsAsFactors = FALSE
  )

  structure(
    list(
      type = "polygon",
      vertices = vertices,
      parent_zone = zone$parent_zone
    ),
    class = "zone_geometry"
  )
}

#' Create circle zone
#'
#' Creates a circular zone geometry.
#'
#' @param zone List with center_point and radius_cm fields
#' @param arena arena_config object
#'
#' @return zone_geometry object with type "circle"
#'
#' @keywords internal
create_circle_zone <- function(zone, arena) {
  if (is.null(zone$center_point)) {
    stop("Circle zone missing center_point specification", call. = FALSE)
  }

  if (is.null(zone$radius_cm)) {
    stop("Circle zone missing radius_cm specification", call. = FALSE)
  }

  # Get center coordinates
  center <- get_arena_point(arena, zone$center_point)

  # Convert radius from cm to pixels if scale is available
  radius_pixels <- zone$radius_cm
  if (!is.null(arena$scale)) {
    radius_pixels <- zone$radius_cm * arena$scale
  }

  structure(
    list(
      type = "circle",
      center_x = as.numeric(center["x"]),
      center_y = as.numeric(center["y"]),
      radius = radius_pixels
    ),
    class = "zone_geometry"
  )
}

#' Create rectangle zone
#'
#' Creates a rectangular zone geometry.
#'
#' @param zone List with corner points or dimensions
#' @param arena arena_config object
#'
#' @return zone_geometry object with type "polygon" (rectangle)
#'
#' @keywords internal
create_rectangle_zone <- function(zone, arena) {
  # Rectangles can be specified by two corner points
  if (!is.null(zone$point_names) && length(zone$point_names) >= 2) {
    p1 <- get_arena_point(arena, zone$point_names[1])
    p2 <- get_arena_point(arena, zone$point_names[2])

    # Create rectangle vertices
    vertices <- data.frame(
      x = c(p1["x"], p2["x"], p2["x"], p1["x"]),
      y = c(p1["y"], p1["y"], p2["y"], p2["y"]),
      stringsAsFactors = FALSE
    )

    return(structure(
      list(
        type = "polygon",
        vertices = vertices
      ),
      class = "zone_geometry"
    ))
  }

  stop("Rectangle zone specification not supported", call. = FALSE)
}

#' Get bounding box from polygon vertices
#'
#' @param vertices Data frame with x and y columns
#'
#' @return List with x_min, x_max, y_min, y_max
#'
#' @keywords internal
get_bbox_from_polygon <- function(vertices) {
  list(
    x_min = min(vertices$x),
    x_max = max(vertices$x),
    y_min = min(vertices$y),
    y_max = max(vertices$y)
  )
}

#' Check if points are inside a zone
#'
#' Tests whether x, y coordinates fall within a zone geometry.
#'
#' @param x Numeric vector of x coordinates
#' @param y Numeric vector of y coordinates
#' @param zone_geometry A zone_geometry object
#'
#' @return Logical vector indicating whether each point is in the zone
#'
#' @examples
#' \dontrun{
#' arena <- load_arena_configs("arena.yaml", "arena1")
#' zone_def <- get_arena_zone(arena, "center")
#' geometry <- create_zone_geometry(zone_def, arena)
#'
#' # Test if tracking points are in zone
#' in_zone <- point_in_zone(tracking_data$x, tracking_data$y, geometry)
#' }
#'
#' @export
point_in_zone <- function(x, y, zone_geometry) {
  if (!inherits(zone_geometry, "zone_geometry")) {
    stop("zone_geometry must be a zone_geometry object", call. = FALSE)
  }

  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  if (zone_geometry$type == "circle") {
    return(point_in_circle(x, y, zone_geometry))
  } else if (zone_geometry$type == "polygon") {
    return(point_in_polygon(x, y, zone_geometry$vertices))
  } else {
    stop("Unknown zone geometry type: ", zone_geometry$type, call. = FALSE)
  }
}

#' Test if points are inside a circle
#'
#' @param x Numeric vector of x coordinates
#' @param y Numeric vector of y coordinates
#' @param circle Zone geometry object with type "circle"
#'
#' @return Logical vector
#'
#' @keywords internal
point_in_circle <- function(x, y, circle) {
  dx <- x - circle$center_x
  dy <- y - circle$center_y
  distance_sq <- dx^2 + dy^2
  radius_sq <- circle$radius^2

  return(distance_sq <= radius_sq)
}

#' Test if points are inside a polygon
#'
#' Uses the ray casting algorithm (even-odd rule) to determine if points
#' are inside a polygon.
#'
#' @param x Numeric vector of x coordinates
#' @param y Numeric vector of y coordinates
#' @param vertices Data frame with x and y columns defining polygon vertices
#'
#' @return Logical vector
#'
#' @keywords internal
point_in_polygon <- function(x, y, vertices) {
  n <- length(x)
  n_vertices <- nrow(vertices)

  # Initialize result
  inside <- logical(n)

  # Ray casting algorithm for each point
  for (i in seq_len(n)) {
    # Handle NA values
    if (is.na(x[i]) || is.na(y[i])) {
      inside[i] <- NA
      next
    }

    # Count intersections with edges
    intersections <- 0

    for (j in seq_len(n_vertices)) {
      # Get edge vertices (j to j+1, wrapping around)
      j_next <- if (j == n_vertices) 1 else j + 1

      x1 <- vertices$x[j]
      y1 <- vertices$y[j]
      x2 <- vertices$x[j_next]
      y2 <- vertices$y[j_next]

      # Check if ray from point crosses this edge
      if (((y1 <= y[i] && y[i] < y2) || (y2 <= y[i] && y[i] < y1)) &&
          (x[i] < (x2 - x1) * (y[i] - y1) / (y2 - y1) + x1)) {
        intersections <- intersections + 1
      }
    }

    # Odd number of intersections means inside
    inside[i] <- (intersections %% 2) == 1
  }

  return(inside)
}

#' Create all zone geometries from arena
#'
#' Processes all zones in an arena configuration and creates their geometries.
#' Handles dependencies between zones (e.g., proportional zones).
#'
#' @param arena An arena_config object
#'
#' @return Named list of zone_geometry objects
#'
#' @examples
#' \dontrun{
#' arena <- load_arena_configs("arena.yaml", "arena1")
#' geometries <- create_all_zone_geometries(arena)
#' }
#'
#' @export
create_all_zone_geometries <- function(arena) {
  if (!is_arena_config(arena)) {
    stop("arena must be an arena_config object", call. = FALSE)
  }

  if (is.null(arena$zones) || length(arena$zones) == 0) {
    return(list())
  }

  # Create geometries, respecting dependencies
  geometries <- list()

  # First pass: create all non-proportional zones
  for (zone in arena$zones) {
    if (zone$type != "proportion") {
      geom <- create_zone_geometry(zone, arena, geometries)
      geometries[[zone$id]] <- geom
    }
  }

  # Second pass: create proportional zones
  max_iterations <- length(arena$zones)
  iteration <- 0

  remaining_zones <- Filter(function(z) z$type == "proportion", arena$zones)

  while (length(remaining_zones) > 0 && iteration < max_iterations) {
    iteration <- iteration + 1
    created_this_iteration <- FALSE
    zones_to_remove <- c()

    for (i in seq_along(remaining_zones)) {
      zone <- remaining_zones[[i]]

      # Check if parent exists
      if (zone$parent_zone %in% names(geometries)) {
        geom <- create_zone_geometry(zone, arena, geometries)
        geometries[[zone$id]] <- geom
        zones_to_remove <- c(zones_to_remove, i)
        created_this_iteration <- TRUE
      }
    }

    # Remove processed zones
    if (length(zones_to_remove) > 0) {
      remaining_zones <- remaining_zones[-zones_to_remove]
    }

    # If no zones were created this iteration, we have a dependency issue
    if (!created_this_iteration && length(remaining_zones) > 0) {
      missing_parents <- sapply(remaining_zones, function(z) z$parent_zone)
      stop("Cannot resolve zone dependencies. Missing parent zones: ",
           paste(unique(missing_parents), collapse = ", "), call. = FALSE)
    }
  }

  return(geometries)
}

#' Print method for zone_geometry objects
#'
#' @param x A zone_geometry object
#' @param ... Additional arguments (not used)
#'
#' @return The object invisibly
#'
#' @export
print.zone_geometry <- function(x, ...) {
  cat("Zone Geometry\n")
  cat("=============\n\n")

  if (!is.null(x$zone_id)) {
    cat("Zone ID:   ", x$zone_id, "\n")
  }

  if (!is.null(x$zone_name)) {
    cat("Zone Name: ", x$zone_name, "\n")
  }

  cat("Type:      ", x$type, "\n\n")

  if (x$type == "polygon") {
    cat("Vertices:  ", nrow(x$vertices), "\n")
    bbox <- get_bbox_from_polygon(x$vertices)
    cat("Bounds:    X[", sprintf("%.1f", bbox$x_min), ", ",
        sprintf("%.1f", bbox$x_max), "], Y[",
        sprintf("%.1f", bbox$y_min), ", ",
        sprintf("%.1f", bbox$y_max), "]\n", sep = "")
  } else if (x$type == "circle") {
    cat("Center:    (", sprintf("%.1f", x$center_x), ", ",
        sprintf("%.1f", x$center_y), ")\n", sep = "")
    cat("Radius:    ", sprintf("%.1f", x$radius), "\n", sep = "")
  }

  invisible(x)
}
