context("Arena Configuration")

# Test arena_config S3 class
test_that("new_arena_config creates valid arena_config object", {
  arena <- new_arena_config(
    id = "test_arena",
    image = "test.png",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(100, 200),
      y = c(100, 200),
      stringsAsFactors = FALSE
    ),
    zones = list(),
    scale = 10
  )

  expect_s3_class(arena, "arena_config")
  expect_equal(arena$id, "test_arena")
  expect_equal(arena$scale, 10)
  expect_equal(nrow(arena$points), 2)
})

test_that("new_arena_config converts points list to data frame", {
  arena <- new_arena_config(
    id = "test_arena",
    points = list(
      p1 = c(x = 100, y = 100),
      p2 = c(x = 200, y = 200)
    )
  )

  expect_true(is.data.frame(arena$points))
  expect_equal(nrow(arena$points), 2)
  expect_equal(arena$points$point_name, c("p1", "p2"))
  expect_equal(arena$points$x, c(100, 200))
})

test_that("validate_arena_config accepts valid configuration", {
  arena <- new_arena_config(
    id = "test_arena",
    points = data.frame(
      point_name = c("p1", "p2", "p3"),
      x = c(0, 100, 0),
      y = c(0, 0, 100),
      stringsAsFactors = FALSE
    ),
    zones = list(
      list(
        id = "zone1",
        name = "Zone 1",
        type = "points",
        point_names = c("p1", "p2", "p3")
      )
    )
  )

  expect_silent(validate_arena_config(arena))
})

test_that("validate_arena_config rejects invalid configurations", {
  # Missing ID
  expect_error(
    validate_arena_config(list(class = "arena_config")),
    "must have a character 'id' field"
  )

  # Duplicate point names
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p1"),
      x = c(100, 200),
      y = c(100, 200),
      stringsAsFactors = FALSE
    )
  )
  expect_error(validate_arena_config(arena), "duplicate point names")

  # Invalid scale
  arena <- new_arena_config(id = "test", scale = -5)
  expect_error(validate_arena_config(arena), "must be a positive number")
})

test_that("is_arena_config correctly identifies arena_config objects", {
  arena <- new_arena_config(id = "test")
  expect_true(is_arena_config(arena))
  expect_false(is_arena_config(list()))
  expect_false(is_arena_config("not an arena"))
})

test_that("get_arena_point retrieves point coordinates", {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(100, 200),
      y = c(150, 250),
      stringsAsFactors = FALSE
    )
  )

  point <- get_arena_point(arena, "p1")
  expect_equal(point, c(x = 100, y = 150))

  point2 <- get_arena_point(arena, "p2")
  expect_equal(point2, c(x = 200, y = 250))
})

test_that("get_arena_point handles errors", {
  arena <- new_arena_config(id = "test")

  expect_error(get_arena_point(arena, "nonexistent"), "has no reference points")

  arena$points <- data.frame(
    point_name = "p1",
    x = 100,
    y = 100,
    stringsAsFactors = FALSE
  )

  expect_error(get_arena_point(arena, "p2"), "not found in arena")
})

test_that("get_arena_zone retrieves zone definition", {
  arena <- new_arena_config(
    id = "test",
    zones = list(
      list(id = "z1", name = "Zone 1", type = "points"),
      list(id = "z2", name = "Zone 2", type = "circle")
    )
  )

  zone <- get_arena_zone(arena, "z1")
  expect_equal(zone$id, "z1")
  expect_equal(zone$name, "Zone 1")

  zone2 <- get_arena_zone(arena, "z2")
  expect_equal(zone2$type, "circle")
})

test_that("get_arena_zone handles errors", {
  arena <- new_arena_config(id = "test")

  expect_error(get_arena_zone(arena, "z1"), "has no zones defined")

  arena$zones <- list(list(id = "z1", name = "Zone 1", type = "points"))

  expect_error(get_arena_zone(arena, "z2"), "not found in arena")
})

# Test zone validation
test_that("validate_zone checks required fields", {
  points <- data.frame(
    point_name = c("p1", "p2", "p3"),
    x = c(0, 100, 0),
    y = c(0, 0, 100),
    stringsAsFactors = FALSE
  )

  # Missing ID
  expect_error(
    validate_zone(list(name = "Zone", type = "points"), 1, points),
    "missing 'id' field"
  )

  # Missing name
  expect_error(
    validate_zone(list(id = "z1", type = "points"), 1, points),
    "missing 'name' field"
  )

  # Missing type
  expect_error(
    validate_zone(list(id = "z1", name = "Zone"), 1, points),
    "missing 'type' field"
  )
})

test_that("validate_zone checks type-specific fields", {
  points <- data.frame(
    point_name = c("p1", "p2"),
    x = c(0, 100),
    y = c(0, 100),
    stringsAsFactors = FALSE
  )

  # Invalid type
  expect_error(
    validate_zone(list(id = "z1", name = "Zone", type = "invalid"), 1, points),
    "invalid type"
  )

  # Points type missing point_names
  expect_error(
    validate_zone(list(id = "z1", name = "Zone", type = "points"), 1, points),
    "missing 'point_names' field"
  )

  # Points type with undefined points
  expect_error(
    validate_zone(
      list(id = "z1", name = "Zone", type = "points", point_names = c("p1", "p3")),
      1,
      points
    ),
    "references undefined points"
  )

  # Proportion type missing parent_zone
  expect_error(
    validate_zone(list(id = "z1", name = "Zone", type = "proportion"), 1, points),
    "missing 'parent_zone' field"
  )

  # Proportion type missing proportion
  expect_error(
    validate_zone(
      list(id = "z1", name = "Zone", type = "proportion", parent_zone = "p1"),
      1,
      points
    ),
    "missing 'proportion' field"
  )
})

test_that("print.arena_config displays information correctly", {
  arena <- new_arena_config(
    id = "test_arena",
    image = "test.png",
    points = data.frame(
      point_name = c("p1", "p2"),
      x = c(100, 200),
      y = c(100, 200),
      stringsAsFactors = FALSE
    ),
    zones = list(
      list(id = "z1", name = "Zone 1", type = "points")
    ),
    scale = 10
  )

  output <- capture.output(print(arena))

  expect_true(any(grepl("Arena Configuration", output)))
  expect_true(any(grepl("test_arena", output)))
  expect_true(any(grepl("10 pixels/cm", output)))
  expect_true(any(grepl("Reference Points", output)))
})
