test_that("new_tracking_data creates valid object", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    session_id = "session_01",
    paradigm = "open_field",
    timestamp = Sys.time(),
    units = "pixels"
  )

  tracking <- data.frame(
    frame = 1:10,
    time = seq(0, length.out = 10, by = 1/30),
    body_part = rep("bodycentre", 10),
    x = rnorm(10, 250, 50),
    y = rnorm(10, 250, 50),
    likelihood = runif(10, 0.9, 1.0)
  )

  arena <- list(
    dimensions = list(width = 500, height = 500, units = "pixels")
  )

  data <- new_tracking_data(metadata, tracking, arena)

  expect_s3_class(data, "tracking_data")
  expect_true(is_tracking_data(data))
  expect_equal(data$metadata$source, "deeplabcut")
  expect_equal(nrow(data$tracking), 10)
})

test_that("validate_tracking_data accepts valid object", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240),
    likelihood = c(0.95, 0.96, 0.97, 0.98, 0.99)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_silent(validate_tracking_data(data))
})

test_that("validate_tracking_data rejects missing metadata fields", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30
    # Missing subject_id and paradigm
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_error(validate_tracking_data(data), "Missing required metadata fields")
})

test_that("validate_tracking_data rejects invalid fps", {
  metadata <- list(
    source = "deeplabcut",
    fps = -10,  # Invalid negative fps
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_error(validate_tracking_data(data), "fps must be a positive number")
})

test_that("validate_tracking_data rejects missing tracking columns", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30)
    # Missing body_part, x, y
  )

  data <- new_tracking_data(metadata, tracking)

  expect_error(validate_tracking_data(data), "Missing required tracking columns")
})

test_that("validate_tracking_data rejects invalid likelihood values", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240),
    likelihood = c(0.95, 1.5, 0.97, 0.98, 0.99)  # 1.5 is out of range
  )

  data <- new_tracking_data(metadata, tracking)

  expect_error(validate_tracking_data(data), "likelihood values must be between 0 and 1")
})

test_that("validate_tracking_data accepts NA likelihood values", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240),
    likelihood = c(0.95, NA, 0.97, 0.98, NA)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_silent(validate_tracking_data(data))
})

test_that("validate_tracking_data validates arena dimensions", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240)
  )

  arena <- list(
    dimensions = list(width = -100, height = 500, units = "pixels")  # Invalid negative width
  )

  data <- new_tracking_data(metadata, tracking, arena)

  expect_error(validate_tracking_data(data), "width must be a positive number")
})

test_that("validate_tracking_data validates reference_points", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240)
  )

  arena <- list(
    dimensions = list(width = 500, height = 500, units = "pixels"),
    reference_points = data.frame(
      point_name = c("tl", "tr"),
      x = c(10, 490)
      # Missing y column
    )
  )

  data <- new_tracking_data(metadata, tracking, arena)

  expect_error(validate_tracking_data(data), "Missing reference_points columns")
})

test_that("print.tracking_data works", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field",
    units = "pixels"
  )

  tracking <- data.frame(
    frame = 1:10,
    time = seq(0, length.out = 10, by = 1/30),
    body_part = rep("bodycentre", 10),
    x = rnorm(10, 250, 50),
    y = rnorm(10, 250, 50),
    likelihood = runif(10, 0.9, 1.0)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_output(print(data), "Tracking Data Object")
  expect_output(print(data), "deeplabcut")
  expect_output(print(data), "mouse_01")
})

test_that("summary.tracking_data works", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = rep(1:5, 2),
    time = rep(seq(0, length.out = 5, by = 1/30), 2),
    body_part = rep(c("bodycentre", "nose"), each = 5),
    x = rnorm(10, 250, 50),
    y = rnorm(10, 250, 50),
    likelihood = runif(10, 0.9, 1.0)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_output(summary(data), "Tracking Data Summary")
  expect_output(summary(data), "bodycentre")
  expect_output(summary(data), "nose")
})

test_that("is_tracking_data correctly identifies objects", {
  metadata <- list(
    source = "deeplabcut",
    fps = 30,
    subject_id = "mouse_01",
    paradigm = "open_field"
  )

  tracking <- data.frame(
    frame = 1:5,
    time = seq(0, length.out = 5, by = 1/30),
    body_part = rep("bodycentre", 5),
    x = c(100, 110, 120, 130, 140),
    y = c(200, 210, 220, 230, 240)
  )

  data <- new_tracking_data(metadata, tracking)

  expect_true(is_tracking_data(data))
  expect_false(is_tracking_data(list()))
  expect_false(is_tracking_data(data.frame()))
  expect_false(is_tracking_data(NULL))
})
