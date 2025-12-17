context("Zone Analysis")

# Helper: Create simple test arena with zones
create_test_arena_with_zones <- function() {
  # Create arena with reference points forming a 400x400 square
  arena <- new_arena_config(
    id = "test_arena",
    points = data.frame(
      point_name = c("tl", "tr", "br", "bl", "center",
                     "left_mid", "right_mid", "top_mid", "bottom_mid"),
      x = c(0, 400, 400, 0, 200,
            0, 400, 200, 200),
      y = c(0, 0, 400, 400, 200,
            200, 200, 0, 400),
      stringsAsFactors = FALSE
    ),
    zones = list(
      # Zone 1: Top-left quadrant (0-200, 0-200)
      list(
        id = "zone1",
        name = "Top Left",
        type = "points",
        point_names = c("tl", "top_mid", "center", "left_mid")
      ),
      # Zone 2: Top-right quadrant (200-400, 0-200)
      list(
        id = "zone2",
        name = "Top Right",
        type = "points",
        point_names = c("top_mid", "tr", "right_mid", "center")
      ),
      # Zone 3: Center circle (radius 50 around center point)
      list(
        id = "zone3",
        name = "Center Circle",
        type = "circle",
        center_point = "center",
        radius_cm = 50
      )
    ),
    scale = 1  # 1 pixel per cm for simplicity
  )

  return(arena)
}

# Helper: Create tracking data with known positions
create_test_tracking_with_positions <- function(positions, fps = 30) {
  # positions is a data frame with columns: frame, body_part, x, y

  tracking_df <- data.frame(
    frame = positions$frame,
    time = positions$frame / fps,
    body_part = positions$body_part,
    x = positions$x,
    y = positions$y,
    likelihood = rep(0.99, nrow(positions)),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    source = "test",
    fps = fps,
    subject_id = "test_subject",
    paradigm = "test"
  )

  arena <- list(
    dimensions = list(width = 500, height = 500, units = "pixels")
  )

  tracking_data <- new_tracking_data(
    metadata = metadata,
    tracking = tracking_df,
    arena = arena
  )

  return(tracking_data)
}

# Test classify_points_by_zone
test_that("classify_points_by_zone correctly identifies zones", {
  arena <- create_test_arena_with_zones()

  # Create tracking data with points in different zones
  positions <- data.frame(
    frame = c(0, 1, 2, 3),
    body_part = rep("nose", 4),
    x = c(100, 300, 200, 50),  # zone1, zone2, center (overlaps zone1/2/3), zone1
    y = c(100, 100, 200, 50),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions)

  result <- classify_points_by_zone(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("frame", "body_part", "x", "y", "zone_id") %in% names(result)))

  # Check frame 0 (100, 100) - should be in zone1
  frame0 <- result[result$frame == 0, ]
  expect_true("zone1" %in% frame0$zone_id)

  # Check frame 1 (300, 100) - should be in zone2
  frame1 <- result[result$frame == 1, ]
  expect_true("zone2" %in% frame1$zone_id)

  # Check frame 2 (200, 200) - center point, should be in zone3 (circle)
  # and possibly in zone1/zone2 depending on boundaries
  frame2 <- result[result$frame == 2, ]
  expect_true("zone3" %in% frame2$zone_id)
})

test_that("classify_points_by_zone handles points outside all zones", {
  arena <- create_test_arena_with_zones()

  # Create tracking data with point clearly outside all zones
  positions <- data.frame(
    frame = c(0, 1),
    body_part = rep("nose", 2),
    x = c(500, 100),  # Outside arena, inside zone1
    y = c(500, 100),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions)

  result <- classify_points_by_zone(tracking_data, arena)

  # Frame 0 should have NA zone_id
  frame0 <- result[result$frame == 0, ]
  expect_true(nrow(frame0) == 1)
  expect_true(is.na(frame0$zone_id[1]))

  # Frame 1 should have zone1
  frame1 <- result[result$frame == 1, ]
  expect_true("zone1" %in% frame1$zone_id)
})

test_that("classify_points_by_zone handles multiple body parts", {
  arena <- create_test_arena_with_zones()

  # Create tracking data with two body parts
  positions <- data.frame(
    frame = c(0, 0, 1, 1),
    body_part = c("nose", "tail", "nose", "tail"),
    x = c(100, 300, 300, 100),  # nose: zone1->zone2, tail: zone2->zone1
    y = c(100, 100, 100, 100),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions)

  # All body parts
  result_all <- classify_points_by_zone(tracking_data, arena)
  expect_true("nose" %in% result_all$body_part)
  expect_true("tail" %in% result_all$body_part)

  # Just nose
  result_nose <- classify_points_by_zone(tracking_data, arena, body_part = "nose")
  expect_true(all(result_nose$body_part == "nose"))
  expect_equal(length(unique(result_nose$frame)), 2)
})

test_that("classify_points_by_zone handles overlapping zones", {
  arena <- create_test_arena_with_zones()

  # Point at (200, 200) should be in zone3 (circle) and at boundaries of zone1/zone2
  positions <- data.frame(
    frame = 0,
    body_part = "nose",
    x = 200,
    y = 200,
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions)

  result <- classify_points_by_zone(tracking_data, arena)

  frame0 <- result[result$frame == 0, ]

  # Should definitely be in zone3 (circle with radius 50 around center)
  expect_true("zone3" %in% frame0$zone_id)

  # May be in multiple zones - check that we get separate rows
  # (The center point (200,200) is vertex of zone1 and zone2, behavior may vary)
})

test_that("classify_points_by_zone validates inputs", {
  arena <- create_test_arena_with_zones()
  tracking_data <- create_mock_tracking_data(n_frames = 10)

  # Invalid tracking_data
  expect_error(
    classify_points_by_zone(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  # Invalid arena_config
  expect_error(
    classify_points_by_zone(tracking_data, list()),
    "arena_config must be an arena_config object"
  )

  # Arena with no zones
  arena_no_zones <- new_arena_config(id = "test", zones = list())
  expect_error(
    classify_points_by_zone(tracking_data, arena_no_zones),
    "arena_config has no zones defined"
  )

  # Invalid body_part
  expect_error(
    classify_points_by_zone(tracking_data, arena, body_part = "nonexistent"),
    "Body part 'nonexistent' not found"
  )
})

test_that("classify_points_by_zone handles NA coordinates", {
  arena <- create_test_arena_with_zones()

  # Create tracking data with NA coordinates
  positions <- data.frame(
    frame = c(0, 1, 2),
    body_part = rep("nose", 3),
    x = c(100, NA, 300),
    y = c(100, 100, NA),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions)

  result <- classify_points_by_zone(tracking_data, arena)

  # Frames with NA should still appear with zone_id = NA
  expect_true(1 %in% result$frame)
  expect_true(2 %in% result$frame)

  frame1 <- result[result$frame == 1, ]
  expect_true(is.na(frame1$zone_id[1]))
})

# Test calculate_zone_occupancy
test_that("calculate_zone_occupancy calculates correct time and percentage", {
  arena <- create_test_arena_with_zones()

  # Create 30 frames at 30 fps = 1 second total
  # 10 frames in zone1, 10 in zone2, 10 in zone3
  positions <- data.frame(
    frame = 0:29,
    body_part = rep("nose", 30),
    x = c(rep(100, 10), rep(300, 10), rep(200, 10)),  # zone1, zone2, zone3
    y = c(rep(100, 10), rep(100, 10), rep(200, 10)),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("zone_id", "n_frames", "time_seconds", "percentage") %in% names(result)))

  # Each zone should have ~10 frames, ~0.333 seconds, ~33.3%
  zone1_row <- result[result$zone_id == "zone1", ]
  expect_equal(zone1_row$n_frames, 10)
  expect_equal(zone1_row$time_seconds, 10/30, tolerance = 0.01)
  expect_equal(zone1_row$percentage, (10/30)*100, tolerance = 0.1)

  zone2_row <- result[result$zone_id == "zone2", ]
  expect_equal(zone2_row$n_frames, 10)
  expect_equal(zone2_row$time_seconds, 10/30, tolerance = 0.01)

  zone3_row <- result[result$zone_id == "zone3", ]
  expect_equal(zone3_row$n_frames, 10)
  expect_equal(zone3_row$time_seconds, 10/30, tolerance = 0.01)
})

test_that("calculate_zone_occupancy handles single body part analysis", {
  arena <- create_test_arena_with_zones()

  positions <- data.frame(
    frame = 0:9,
    body_part = rep("nose", 10),
    x = rep(100, 10),  # All in zone1
    y = rep(100, 10),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena, body_part = "nose")

  expect_true("zone1" %in% result$zone_id)
  expect_false("body_part" %in% names(result))  # Should not have body_part column for single BP
  expect_equal(result$n_frames[result$zone_id == "zone1"], 10)
})

test_that("calculate_zone_occupancy handles multiple body parts separately", {
  arena <- create_test_arena_with_zones()

  # Nose in zone1, tail in zone2
  positions <- data.frame(
    frame = rep(0:9, 2),
    body_part = c(rep("nose", 10), rep("tail", 10)),
    x = c(rep(100, 10), rep(300, 10)),
    y = c(rep(100, 10), rep(100, 10)),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena)

  expect_true("body_part" %in% names(result))  # Should have body_part column

  nose_zone1 <- result[result$body_part == "nose" & result$zone_id == "zone1", ]
  expect_equal(nrow(nose_zone1), 1)
  expect_equal(nose_zone1$n_frames, 10)

  tail_zone2 <- result[result$body_part == "tail" & result$zone_id == "zone2", ]
  expect_equal(nrow(tail_zone2), 1)
  expect_equal(tail_zone2$n_frames, 10)
})

test_that("calculate_zone_occupancy handles no points in zones", {
  arena <- create_test_arena_with_zones()

  # All points outside zones
  positions <- data.frame(
    frame = 0:9,
    body_part = rep("nose", 10),
    x = rep(500, 10),  # Outside arena
    y = rep(500, 10),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena)

  # Should return empty data frame with correct structure
  expect_equal(nrow(result), 0)
  expect_true(all(c("zone_id", "n_frames", "time_seconds", "percentage") %in% names(result)))
})

test_that("calculate_zone_occupancy validates inputs", {
  arena <- create_test_arena_with_zones()
  tracking_data <- create_mock_tracking_data(n_frames = 10)

  # Invalid tracking_data
  expect_error(
    calculate_zone_occupancy(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  # Invalid arena_config
  expect_error(
    calculate_zone_occupancy(tracking_data, list()),
    "arena_config must be an arena_config object"
  )

  # Missing fps
  tracking_bad_fps <- tracking_data
  tracking_bad_fps$metadata$fps <- NULL
  expect_error(
    calculate_zone_occupancy(tracking_bad_fps, arena),
    "metadata must contain valid fps"
  )
})

test_that("calculate_zone_occupancy handles overlapping zones correctly", {
  # When a point is in multiple zones, it should be counted in each zone
  arena <- create_test_arena_with_zones()

  # All 10 points at center (200, 200) - in zone3 and possibly at boundary of zone1/zone2
  positions <- data.frame(
    frame = 0:9,
    body_part = rep("nose", 10),
    x = rep(200, 10),
    y = rep(200, 10),
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena)

  # All points should be in zone3
  zone3_row <- result[result$zone_id == "zone3", ]
  expect_equal(nrow(zone3_row), 1)
  expect_equal(zone3_row$n_frames, 10)

  # Note: Percentages can sum to > 100% if zones overlap
})

test_that("calculate_zone_occupancy percentage sums correctly for non-overlapping zones", {
  # Create arena with non-overlapping zones only (proper rectangles with 4 points)
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("tl", "tr", "br", "bl", "mid_left", "mid_right"),
      x = c(0, 200, 200, 0, 0, 200),
      y = c(0, 0, 200, 200, 100, 100),
      stringsAsFactors = FALSE
    ),
    zones = list(
      list(id = "top", name = "Top", type = "points",
           point_names = c("tl", "mid_left", "mid_right", "tr")),  # Top rectangle
      list(id = "bottom", name = "Bottom", type = "points",
           point_names = c("mid_left", "bl", "br", "mid_right"))  # Bottom rectangle
    )
  )

  positions <- data.frame(
    frame = 0:9,
    body_part = rep("nose", 10),
    x = c(rep(100, 5), rep(100, 5)),  # 5 in top, 5 in bottom
    y = c(rep(50, 5), rep(150, 5)),   # Top half, bottom half
    stringsAsFactors = FALSE
  )

  tracking_data <- create_test_tracking_with_positions(positions, fps = 30)

  result <- calculate_zone_occupancy(tracking_data, arena)

  # For single body part, non-overlapping zones, percentages should sum to ~100%
  # (only counting frames that are IN zones)
  total_pct <- sum(result$percentage)
  expect_equal(total_pct, 100, tolerance = 1)
})
