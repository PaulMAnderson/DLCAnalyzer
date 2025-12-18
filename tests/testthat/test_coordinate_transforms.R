context("Coordinate Transformations")

# Test scale calculation
test_that("calculate_scale_from_points calculates correct scale", {
  # Vertical line: 100 pixels = 10 cm -> 10 pixels/cm
  p1 <- c(x = 100, y = 100)
  p2 <- c(x = 100, y = 200)
  scale <- calculate_scale_from_points(p1, p2, 10)

  expect_equal(scale, 10)

  # Horizontal line
  p1 <- c(x = 50, y = 100)
  p2 <- c(x = 150, y = 100)
  scale <- calculate_scale_from_points(p1, p2, 20)

  expect_equal(scale, 5)

  # Diagonal line (3-4-5 triangle: 5 units = 5 cm -> 1 pixel/cm)
  p1 <- c(x = 0, y = 0)
  p2 <- c(x = 3, y = 4)
  scale <- calculate_scale_from_points(p1, p2, 5)

  expect_equal(scale, 1)
})

test_that("calculate_scale_from_points validates inputs", {
  p1 <- c(x = 0, y = 0)
  p2 <- c(x = 100, y = 100)

  # Non-numeric points
  expect_error(
    calculate_scale_from_points("not numeric", p2, 10),
    "must be numeric vectors"
  )

  # Missing coordinate names
  expect_error(
    calculate_scale_from_points(c(0, 0), p2, 10),
    "must have named 'x' and 'y' coordinates"
  )

  # Zero distance
  expect_error(
    calculate_scale_from_points(p1, p2, 0),
    "must be a positive number"
  )

  # Identical points
  expect_error(
    calculate_scale_from_points(p1, p1, 10),
    "identical"
  )
})

test_that("calculate_arena_scale uses arena points", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(0, 0),
      y = c(0, 100),
      stringsAsFactors = FALSE
    )
  )

  scale <- calculate_arena_scale(arena, "p1", "p2", 10)
  expect_equal(scale, 10)
})

test_that("calculate_arena_scale uses metadata if distance not provided", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(0, 0),
      y = c(0, 100),
      stringsAsFactors = FALSE
    ),
    metadata = list(
      calibration = list(real_distance_cm = 10)
    )
  )

  scale <- calculate_arena_scale(arena, "p1", "p2")
  expect_equal(scale, 10)
})

# Test unit conversion
test_that("pixels_to_cm converts correctly", {
  result <- pixels_to_cm(c(100, 200), c(150, 250), pixels_per_cm = 10)

  expect_equal(result$x, c(10, 20))
  expect_equal(result$y, c(15, 25))
  expect_true(is.data.frame(result))
})

test_that("cm_to_pixels converts correctly", {
  result <- cm_to_pixels(c(10, 20), c(15, 25), pixels_per_cm = 10)

  expect_equal(result$x, c(100, 200))
  expect_equal(result$y, c(150, 250))
  expect_true(is.data.frame(result))
})

test_that("pixels_to_cm and cm_to_pixels are inverses", {
  original_x <- c(100, 200, 300)
  original_y <- c(150, 250, 350)
  scale <- 10

  # Convert to cm and back
  cm_coords <- pixels_to_cm(original_x, original_y, scale)
  back_to_pixels <- cm_to_pixels(cm_coords$x, cm_coords$y, scale)

  expect_equal(back_to_pixels$x, original_x)
  expect_equal(back_to_pixels$y, original_y)
})

test_that("pixels_to_cm validates inputs", {
  expect_error(
    pixels_to_cm(c(1, 2), c(1, 2, 3), 10),
    "must have the same length"
  )

  expect_error(
    pixels_to_cm(c(1, 2), c(1, 2), -5),
    "must be a positive number"
  )
})

# Test coordinate rotation
test_that("rotate_coordinates rotates correctly", {
  # 90 degree rotation around origin
  result <- rotate_coordinates(c(1, 0), c(0, 1), angle = 90, center = c(0, 0))

  expect_equal(result$x[1], 0, tolerance = 1e-10)
  expect_equal(result$y[1], 1, tolerance = 1e-10)
  expect_equal(result$x[2], -1, tolerance = 1e-10)
  expect_equal(result$y[2], 0, tolerance = 1e-10)
})

test_that("rotate_coordinates handles 180 degree rotation", {
  result <- rotate_coordinates(c(1, 2), c(3, 4), angle = 180, center = c(0, 0))

  expect_equal(result$x, c(-1, -2), tolerance = 1e-10)
  expect_equal(result$y, c(-3, -4), tolerance = 1e-10)
})

test_that("rotate_coordinates handles custom center", {
  # Rotate 90 degrees around (1, 1)
  result <- rotate_coordinates(c(2), c(1), angle = 90, center = c(1, 1))

  expect_equal(result$x, 1, tolerance = 1e-10)
  expect_equal(result$y, 2, tolerance = 1e-10)
})

# Test coordinate centering
test_that("center_coordinates centers correctly", {
  result <- center_coordinates(
    c(100, 200, 300),
    c(150, 250, 350),
    reference_point = c(200, 250)
  )

  expect_equal(result$x, c(-100, 0, 100))
  expect_equal(result$y, c(-100, 0, 100))
})

test_that("center_coordinates validates inputs", {
  expect_error(
    center_coordinates(c(1, 2), c(1, 2, 3), c(0, 0)),
    "must have the same length"
  )

  expect_error(
    center_coordinates(c(1, 2), c(1, 2), c(0)),
    "must be a numeric vector of length 2"
  )
})

# Test transform_tracking_coords
test_that("transform_tracking_coords converts units correctly", {
  # Create test tracking data
  tracking_df <- data.frame(
    frame = 1:3,
    time = c(0, 0.033, 0.066),
    body_part = "bodycentre",
    x = c(100, 200, 300),
    y = c(150, 250, 350),
    likelihood = c(0.99, 0.99, 0.99),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df,
    arena = list(
      dimensions = list(width = 500, height = 500, units = "pixels"),
      scale = 10
    )
  )

  # Convert to cm
  result <- transform_tracking_coords(tracking_data, to_units = "cm")

  expect_equal(result$tracking$x, c(10, 20, 30))
  expect_equal(result$tracking$y, c(15, 25, 35))
  expect_equal(result$metadata$units, "cm")
  expect_equal(result$arena$dimensions$units, "cm")
  expect_equal(result$arena$dimensions$width, 50)
})

test_that("transform_tracking_coords applies origin translation", {
  tracking_df <- data.frame(
    frame = 1:3,
    time = c(0, 0.033, 0.066),
    body_part = "bodycentre",
    x = c(100, 200, 300),
    y = c(150, 250, 350),
    likelihood = c(0.99, 0.99, 0.99),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  result <- transform_tracking_coords(tracking_data, origin = c(200, 250))

  expect_equal(result$tracking$x, c(-100, 0, 100))
  expect_equal(result$tracking$y, c(-100, 0, 100))
})

test_that("transform_tracking_coords flips y-axis", {
  tracking_df <- data.frame(
    frame = 1:3,
    time = c(0, 0.033, 0.066),
    body_part = "bodycentre",
    x = c(100, 200, 300),
    y = c(0, 50, 100),
    likelihood = c(0.99, 0.99, 0.99),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  result <- transform_tracking_coords(tracking_data, flip_y = TRUE)

  expect_equal(result$tracking$y, c(100, 50, 0))
})

test_that("transform_tracking_coords validates inputs", {
  tracking_df <- data.frame(
    frame = 1:3,
    time = c(0, 0.033, 0.066),
    body_part = "bodycentre",
    x = c(100, 200, 300),
    y = c(150, 250, 350),
    likelihood = c(0.99, 0.99, 0.99),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  # Missing scale for conversion
  expect_error(
    transform_tracking_coords(tracking_data, to_units = "cm"),
    "pixels_per_cm must be provided"
  )

  # Not a tracking_data object
  expect_error(
    transform_tracking_coords(list(), to_units = "cm"),
    "must be a tracking_data object"
  )
})

test_that("apply_arena_transform applies arena scale", {
  tracking_df <- data.frame(
    frame = 1:3,
    time = c(0, 0.033, 0.066),
    body_part = "bodycentre",
    x = c(100, 200, 300),
    y = c(150, 250, 350),
    likelihood = c(0.99, 0.99, 0.99),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  arena <- new_arena_config(id = "test", scale = 10)

  result <- apply_arena_transform(tracking_data, arena, to_units = "cm")

  expect_equal(result$tracking$x, c(10, 20, 30))
  expect_equal(result$tracking$y, c(15, 25, 35))
  expect_equal(result$metadata$units, "cm")
  expect_equal(result$arena$config_id, "test")
})

test_that("apply_arena_transform warns if no scale", {
  tracking_df <- data.frame(
    frame = 1,
    time = 0,
    body_part = "bodycentre",
    x = 100,
    y = 150,
    likelihood = 0.99,
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(
      source = "test",
      fps = 30,
      subject_id = "test",
      paradigm = "test",
      units = "pixels"
    ),
    tracking = tracking_df
  )

  arena <- new_arena_config(id = "test")

  expect_warning(
    apply_arena_transform(tracking_data, arena),
    "no scale information"
  )
})
