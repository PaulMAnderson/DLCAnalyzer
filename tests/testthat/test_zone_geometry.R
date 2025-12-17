context("Zone Geometry")

# Test polygon zone creation
test_that("create_polygon_from_points creates valid polygon", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2", "p3", "p4"),
      x = c(0, 100, 100, 0),
      y = c(0, 0, 100, 100),
      stringsAsFactors = FALSE
    )
  )

  zone_def <- list(
    id = "square",
    name = "Square Zone",
    type = "points",
    point_names = c("p1", "p2", "p3", "p4")
  )

  geom <- create_zone_geometry(zone_def, arena)

  expect_s3_class(geom, "zone_geometry")
  expect_equal(geom$type, "polygon")
  expect_equal(nrow(geom$vertices), 4)
  expect_equal(geom$vertices$x, c(0, 100, 100, 0))
  expect_equal(geom$vertices$y, c(0, 0, 100, 100))
})

test_that("create_polygon_from_points requires at least 3 points", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(0, 100),
      y = c(0, 100),
      stringsAsFactors = FALSE
    )
  )

  zone_def <- list(
    id = "line",
    name = "Line",
    type = "points",
    point_names = c("p1", "p2")
  )

  expect_error(
    create_zone_geometry(zone_def, arena),
    "at least 3 points"
  )
})

# Test proportional zone creation
test_that("create_proportional_zone creates zone from parent", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2", "p3", "p4"),
      x = c(0, 100, 100, 0),
      y = c(0, 0, 100, 100),
      stringsAsFactors = FALSE
    )
  )

  # Create parent zone first
  parent_geom <- structure(
    list(
      type = "polygon",
      vertices = data.frame(
        x = c(0, 100, 100, 0),
        y = c(0, 0, 100, 100),
        stringsAsFactors = FALSE
      )
    ),
    class = "zone_geometry"
  )

  parent_zones <- list(outer = parent_geom)

  zone_def <- list(
    id = "center",
    name = "Center",
    type = "proportion",
    parent_zone = "outer",
    proportion = c(0.25, 0.25, 0.75, 0.75)
  )

  geom <- create_zone_geometry(zone_def, arena, parent_zones)

  expect_s3_class(geom, "zone_geometry")
  expect_equal(geom$type, "polygon")
  expect_equal(nrow(geom$vertices), 4)

  # Check that it's 50% of parent in each dimension
  expect_equal(geom$vertices$x, c(25, 75, 75, 25))
  expect_equal(geom$vertices$y, c(25, 25, 75, 75))
})

test_that("create_proportional_zone requires parent_zone", {
  arena <- new_arena_config(id = "test")

  zone_def <- list(
    id = "center",
    name = "Center",
    type = "proportion",
    proportion = c(0.25, 0.25, 0.75, 0.75)
  )

  expect_error(
    create_zone_geometry(zone_def, arena),
    "missing parent_zone specification"
  )
})

test_that("create_proportional_zone requires proportion field", {
  arena <- new_arena_config(id = "test")
  parent_zones <- list(outer = structure(
    list(type = "polygon", vertices = data.frame(x = 0, y = 0)),
    class = "zone_geometry"
  ))

  zone_def <- list(
    id = "center",
    name = "Center",
    type = "proportion",
    parent_zone = "outer"
  )

  expect_error(
    create_zone_geometry(zone_def, arena, parent_zones),
    "must have proportion as"
  )
})

# Test circle zone creation
test_that("create_circle_zone creates valid circle", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = "center",
      x = 250,
      y = 250,
      stringsAsFactors = FALSE
    ),
    scale = 10
  )

  zone_def <- list(
    id = "circle1",
    name = "Circle",
    type = "circle",
    center_point = "center",
    radius_cm = 10
  )

  geom <- create_zone_geometry(zone_def, arena)

  expect_s3_class(geom, "zone_geometry")
  expect_equal(geom$type, "circle")
  expect_equal(geom$center_x, 250)
  expect_equal(geom$center_y, 250)
  expect_equal(geom$radius, 100)  # 10 cm * 10 pixels/cm
})

# Test point-in-zone detection
test_that("point_in_polygon correctly identifies interior points", {
  # Square from (0,0) to (100,100)
  vertices <- data.frame(
    x = c(0, 100, 100, 0),
    y = c(0, 0, 100, 100),
    stringsAsFactors = FALSE
  )

  # Points clearly inside
  inside <- point_in_polygon(c(50, 25, 75), c(50, 25, 75), vertices)
  expect_equal(inside, c(TRUE, TRUE, TRUE))

  # Points clearly outside
  outside <- point_in_polygon(c(-10, 110, 50), c(50, 50, 110), vertices)
  expect_equal(outside, c(FALSE, FALSE, FALSE))

  # Point on corner (should be inside or on boundary)
  corner <- point_in_polygon(0, 0, vertices)
  expect_type(corner, "logical")
})

test_that("point_in_polygon handles NA values", {
  vertices <- data.frame(
    x = c(0, 100, 100, 0),
    y = c(0, 0, 100, 100),
    stringsAsFactors = FALSE
  )

  result <- point_in_polygon(c(50, NA, 75), c(50, 50, NA), vertices)
  expect_equal(result[1], TRUE)
  expect_true(is.na(result[2]))
  expect_true(is.na(result[3]))
})

test_that("point_in_circle correctly identifies interior points", {
  circle <- structure(
    list(
      type = "circle",
      center_x = 50,
      center_y = 50,
      radius = 25
    ),
    class = "zone_geometry"
  )

  # Point at center
  expect_true(point_in_circle(50, 50, circle))

  # Point inside
  expect_true(point_in_circle(60, 50, circle))

  # Point on edge (should be inside)
  expect_true(point_in_circle(75, 50, circle))

  # Point outside
  expect_false(point_in_circle(80, 50, circle))
  expect_false(point_in_circle(0, 0, circle))
})

test_that("point_in_zone dispatches correctly", {
  # Test with polygon
  poly_geom <- structure(
    list(
      type = "polygon",
      vertices = data.frame(
        x = c(0, 100, 100, 0),
        y = c(0, 0, 100, 100),
        stringsAsFactors = FALSE
      )
    ),
    class = "zone_geometry"
  )

  result_poly <- point_in_zone(c(50, 150), c(50, 50), poly_geom)
  expect_equal(result_poly, c(TRUE, FALSE))

  # Test with circle
  circle_geom <- structure(
    list(
      type = "circle",
      center_x = 50,
      center_y = 50,
      radius = 25
    ),
    class = "zone_geometry"
  )

  result_circle <- point_in_zone(c(50, 150), c(50, 50), circle_geom)
  expect_equal(result_circle, c(TRUE, FALSE))
})

test_that("point_in_zone validates inputs", {
  geom <- structure(
    list(
      type = "polygon",
      vertices = data.frame(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1))
    ),
    class = "zone_geometry"
  )

  expect_error(
    point_in_zone(c(1, 2), c(1, 2, 3), geom),
    "must have the same length"
  )

  expect_error(
    point_in_zone(1, 2, list()),
    "must be a zone_geometry object"
  )
})

# Test create_all_zone_geometries
test_that("create_all_zone_geometries processes all zones", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2", "p3", "p4"),
      x = c(0, 100, 100, 0),
      y = c(0, 0, 100, 100),
      stringsAsFactors = FALSE
    ),
    zones = list(
      list(
        id = "outer",
        name = "Outer",
        type = "points",
        point_names = c("p1", "p2", "p3", "p4")
      ),
      list(
        id = "center",
        name = "Center",
        type = "proportion",
        parent_zone = "outer",
        proportion = c(0.25, 0.25, 0.75, 0.75)
      )
    )
  )

  geometries <- create_all_zone_geometries(arena)

  expect_length(geometries, 2)
  expect_true("outer" %in% names(geometries))
  expect_true("center" %in% names(geometries))

  expect_equal(geometries$outer$type, "polygon")
  expect_equal(geometries$center$type, "polygon")
})

test_that("create_all_zone_geometries handles dependency order", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2", "p3", "p4"),
      x = c(0, 200, 200, 0),
      y = c(0, 0, 200, 200),
      stringsAsFactors = FALSE
    ),
    zones = list(
      # Define child before parent to test dependency resolution
      list(
        id = "inner",
        name = "Inner",
        type = "proportion",
        parent_zone = "middle",
        proportion = c(0.25, 0.25, 0.75, 0.75)
      ),
      list(
        id = "middle",
        name = "Middle",
        type = "proportion",
        parent_zone = "outer",
        proportion = c(0.25, 0.25, 0.75, 0.75)
      ),
      list(
        id = "outer",
        name = "Outer",
        type = "points",
        point_names = c("p1", "p2", "p3", "p4")
      )
    )
  )

  geometries <- create_all_zone_geometries(arena)

  expect_length(geometries, 3)
  expect_true(all(c("outer", "middle", "inner") %in% names(geometries)))
})

test_that("create_all_zone_geometries detects circular dependencies", {
  arena <- new_arena_config(
    id = "test",
    zones = list(
      list(
        id = "z1",
        name = "Zone 1",
        type = "proportion",
        parent_zone = "z2",
        proportion = c(0, 0, 1, 1)
      ),
      list(
        id = "z2",
        name = "Zone 2",
        type = "proportion",
        parent_zone = "z1",
        proportion = c(0, 0, 1, 1)
      )
    )
  )

  expect_error(
    create_all_zone_geometries(arena),
    "Cannot resolve zone dependencies"
  )
})

test_that("get_bbox_from_polygon calculates correct bounds", {
  vertices <- data.frame(
    x = c(10, 50, 50, 10),
    y = c(20, 20, 80, 80),
    stringsAsFactors = FALSE
  )

  bbox <- get_bbox_from_polygon(vertices)

  expect_equal(bbox$x_min, 10)
  expect_equal(bbox$x_max, 50)
  expect_equal(bbox$y_min, 20)
  expect_equal(bbox$y_max, 80)
})

test_that("print.zone_geometry displays information correctly", {
  geom <- structure(
    list(
      type = "polygon",
      zone_id = "z1",
      zone_name = "Test Zone",
      vertices = data.frame(
        x = c(0, 100, 100, 0),
        y = c(0, 0, 100, 100),
        stringsAsFactors = FALSE
      )
    ),
    class = "zone_geometry"
  )

  output <- capture.output(print(geom))

  expect_true(any(grepl("Zone Geometry", output)))
  expect_true(any(grepl("z1", output)))
  expect_true(any(grepl("Test Zone", output)))
  expect_true(any(grepl("polygon", output)))
})
