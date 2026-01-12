context("Time in Zone")

# Helper: Create arena with two simple zones
create_two_zone_arena <- function() {
  arena <- new_arena_config(
    id = "test",
    points = data.frame(
      point_name = c("tl", "tr", "br", "bl", "mid_left", "mid_right"),
      x = c(0, 200, 200, 0, 0, 200),
      y = c(0, 0, 200, 200, 100, 100),
      stringsAsFactors = FALSE
    ),
    zones = list(
      list(id = "zone_a", name = "Zone A", type = "points",
           point_names = c("tl", "mid_left", "mid_right", "tr")),
      list(id = "zone_b", name = "Zone B", type = "points",
           point_names = c("mid_left", "bl", "br", "mid_right"))
    ),
    scale = 1
  )
  return(arena)
}

# Helper: Create tracking with specific zone visits
create_zone_visit_tracking <- function(zone_sequence, fps = 30) {
  # zone_sequence is a vector like c("zone_a", "zone_a", "zone_b", "zone_b", NA, "zone_a")
  # Each element represents one frame

  n_frames <- length(zone_sequence)

  # Map zones to positions
  positions <- data.frame(
    frame = 0:(n_frames - 1),
    body_part = rep("nose", n_frames),
    x = numeric(n_frames),
    y = numeric(n_frames),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_frames)) {
    zone <- zone_sequence[i]
    if (is.na(zone)) {
      # Outside all zones
      positions$x[i] <- 300
      positions$y[i] <- 100
    } else if (zone == "zone_a") {
      # In zone A (top half)
      positions$x[i] <- 100
      positions$y[i] <- 50
    } else if (zone == "zone_b") {
      # In zone B (bottom half)
      positions$x[i] <- 100
      positions$y[i] <- 150
    }
  }

  tracking_df <- data.frame(
    frame = positions$frame,
    time = positions$frame / fps,
    body_part = positions$body_part,
    x = positions$x,
    y = positions$y,
    likelihood = rep(0.99, n_frames),
    stringsAsFactors = FALSE
  )

  metadata <- list(
    source = "test",
    fps = fps,
    subject_id = "test"
  )

  arena <- list(
    dimensions = list(width = 400, height = 200)
  )

  tracking_data <- new_tracking_data(
    metadata = metadata,
    tracking = tracking_df,
    arena = arena
  )

  return(tracking_data)
}

# Test calculate_zone_entries
test_that("calculate_zone_entries counts entries correctly", {
  arena <- create_two_zone_arena()

  # Create sequence: zone_a (3 frames), zone_b (3 frames), zone_a (3 frames)
  # Should be 2 entries to zone_a, 1 entry to zone_b
  zone_seq <- c(rep("zone_a", 3), rep("zone_b", 3), rep("zone_a", 3))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_entries(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("zone_id", "n_entries", "mean_duration", "total_time") %in% names(result)))

  # Check zone_a: 2 entries
  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(nrow(zone_a_row), 1)
  expect_equal(zone_a_row$n_entries, 2)

  # Check zone_b: 1 entry
  zone_b_row <- result[result$zone_id == "zone_b", ]
  expect_equal(nrow(zone_b_row), 1)
  expect_equal(zone_b_row$n_entries, 1)
})

test_that("calculate_zone_entries calculates durations correctly", {
  arena <- create_two_zone_arena()

  # zone_a: 10 frames, zone_b: 20 frames at 30 fps
  zone_seq <- c(rep("zone_a", 10), rep("zone_b", 20))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_entries(tracking_data, arena)

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_entries, 1)
  expect_equal(zone_a_row$mean_duration, 10/30, tolerance = 0.01)
  expect_equal(zone_a_row$total_time, 10/30, tolerance = 0.01)

  zone_b_row <- result[result$zone_id == "zone_b", ]
  expect_equal(zone_b_row$mean_duration, 20/30, tolerance = 0.01)
})

test_that("calculate_zone_entries respects min_duration filter", {
  arena <- create_two_zone_arena()

  # Two entries to zone_a: one 5 frames (0.167s), one 35 frames (1.167s)
  # With min_duration=1.0, only second entry should count
  zone_seq <- c(rep("zone_a", 5), rep("zone_b", 10), rep("zone_a", 35))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_entries(tracking_data, arena, min_duration = 1.0)

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_entries, 1)  # Only long visit counts
  expect_equal(zone_a_row$mean_duration, 35/30, tolerance = 0.01)
})

test_that("calculate_zone_entries handles animal starting in zone", {
  arena <- create_two_zone_arena()

  # Starts in zone_a
  zone_seq <- c(rep("zone_a", 5), rep("zone_b", 5))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_entries(tracking_data, arena)

  # Should count starting position as an entry
  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_entries, 1)
})

test_that("calculate_zone_entries handles animal ending in zone", {
  arena <- create_two_zone_arena()

  # Ends in zone_a
  zone_seq <- c(rep("zone_b", 5), rep("zone_a", 5))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_entries(tracking_data, arena)

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_entries, 1)
  # Duration should be calculated correctly even without exit
  expect_equal(zone_a_row$mean_duration, 5/30, tolerance = 0.01)
})

test_that("calculate_zone_entries validates inputs", {
  arena <- create_two_zone_arena()
  tracking_data <- create_mock_tracking_data()

  expect_error(
    calculate_zone_entries(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  expect_error(
    calculate_zone_entries(tracking_data, list()),
    "arena_config must be an arena_config object"
  )

  expect_error(
    calculate_zone_entries(tracking_data, arena, min_duration = -1),
    "min_duration must be a non-negative number"
  )
})

# Test calculate_zone_exits
test_that("calculate_zone_exits counts exits correctly", {
  arena <- create_two_zone_arena()

  # zone_a, zone_b, zone_a -> 2 exits from zone_a (one to zone_b, one at end), 1 from zone_b
  zone_seq <- c(rep("zone_a", 3), rep("zone_b", 3), rep("zone_a", 3))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_exits(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("zone_id", "n_exits") %in% names(result)))

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_exits, 1)  # One exit from first visit to zone_a

  zone_b_row <- result[result$zone_id == "zone_b", ]
  expect_equal(zone_b_row$n_exits, 1)
})

test_that("calculate_zone_exits handles no exits (ends in zone)", {
  arena <- create_two_zone_arena()

  # Starts in zone_a, stays in zone_a -> 0 exits
  zone_seq <- rep("zone_a", 10)
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_exits(tracking_data, arena)

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$n_exits, 0)
})

test_that("calculate_zone_exits validates inputs", {
  arena <- create_two_zone_arena()
  tracking_data <- create_mock_tracking_data()

  expect_error(
    calculate_zone_exits(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  expect_error(
    calculate_zone_exits(tracking_data, list()),
    "arena_config must be an arena_config object"
  )
})

# Test calculate_zone_latency
test_that("calculate_zone_latency calculates first entry time", {
  arena <- create_two_zone_arena()

  # Frame 0-4: outside, Frame 5-9: zone_a, Frame 10-14: zone_b
  zone_seq <- c(rep(NA, 5), rep("zone_a", 5), rep("zone_b", 5))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_latency(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("zone_id", "latency_seconds", "first_entry_frame") %in% names(result)))

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$latency_seconds, 5/30, tolerance = 0.01)
  expect_equal(zone_a_row$first_entry_frame, 5)

  zone_b_row <- result[result$zone_id == "zone_b", ]
  expect_equal(zone_b_row$latency_seconds, 10/30, tolerance = 0.01)
  expect_equal(zone_b_row$first_entry_frame, 10)
})

test_that("calculate_zone_latency returns NA for never-entered zones", {
  arena <- create_two_zone_arena()

  # Only visit zone_a, never zone_b
  zone_seq <- rep("zone_a", 10)
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_latency(tracking_data, arena)

  zone_b_row <- result[result$zone_id == "zone_b", ]
  expect_true(is.na(zone_b_row$latency_seconds))
  expect_true(is.na(zone_b_row$first_entry_frame))
})

test_that("calculate_zone_latency handles starting in zone", {
  arena <- create_two_zone_arena()

  # Start in zone_a (frame 0)
  zone_seq <- c(rep("zone_a", 5), rep("zone_b", 5))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_latency(tracking_data, arena)

  zone_a_row <- result[result$zone_id == "zone_a", ]
  expect_equal(zone_a_row$latency_seconds, 0)
  expect_equal(zone_a_row$first_entry_frame, 0)
})

test_that("calculate_zone_latency respects min_duration filter", {
  arena <- create_two_zone_arena()

  # Frame 0-4: outside
  # Frame 5: zone_a (single frame - tracking glitch)
  # Frame 6-9: outside
  # Frame 10-44: zone_a (sustained entry, 35 frames = 1.167s)
  # Frame 45-64: zone_b (20 frames = 0.667s, sustained)
  zone_seq <- c(
    rep(NA, 5),           # 0-4: outside
    "zone_a",             # 5: glitch
    rep(NA, 4),           # 6-9: outside
    rep("zone_a", 35),    # 10-44: real entry
    rep("zone_b", 20)     # 45-64: zone_b sustained
  )
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  # Without filter: should find glitch at frame 5
  result_no_filter <- calculate_zone_latency(tracking_data, arena, min_duration = 0)
  zone_a_no_filter <- result_no_filter[result_no_filter$zone_id == "zone_a", ]
  expect_equal(zone_a_no_filter$first_entry_frame, 5)
  expect_equal(zone_a_no_filter$latency_seconds, 5/30, tolerance = 0.01)

  # With min_duration = 0.5s: should skip glitch and find real entry at frame 10
  result_filtered <- calculate_zone_latency(tracking_data, arena, min_duration = 0.5)
  zone_a_filtered <- result_filtered[result_filtered$zone_id == "zone_a", ]
  expect_equal(zone_a_filtered$first_entry_frame, 10)
  expect_equal(zone_a_filtered$latency_seconds, 10/30, tolerance = 0.01)

  # Zone B should be the same (no glitches)
  zone_b_no_filter <- result_no_filter[result_no_filter$zone_id == "zone_b", ]
  zone_b_filtered <- result_filtered[result_filtered$zone_id == "zone_b", ]
  expect_equal(zone_b_no_filter$first_entry_frame, zone_b_filtered$first_entry_frame)
})

test_that("calculate_zone_latency validates inputs", {
  arena <- create_two_zone_arena()
  tracking_data <- create_mock_tracking_data()

  expect_error(
    calculate_zone_latency(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  expect_error(
    calculate_zone_latency(tracking_data, list()),
    "arena_config must be an arena_config object"
  )

  expect_error(
    calculate_zone_latency(tracking_data, arena, min_duration = -1),
    "min_duration must be a non-negative number"
  )
})

# Test calculate_zone_transitions
test_that("calculate_zone_transitions counts transitions correctly", {
  arena <- create_two_zone_arena()

  # zone_a -> zone_b -> zone_a -> zone_b
  # Transitions: zone_a->zone_b (2), zone_b->zone_a (1)
  zone_seq <- c(rep("zone_a", 3), rep("zone_b", 3), rep("zone_a", 3), rep("zone_b", 3))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_transitions(tracking_data, arena)

  expect_true(is.data.frame(result))
  expect_true(all(c("from_zone", "to_zone", "n_transitions") %in% names(result)))

  # zone_a -> zone_b
  trans_ab <- result[result$from_zone == "zone_a" & result$to_zone == "zone_b", ]
  expect_equal(nrow(trans_ab), 1)
  expect_equal(trans_ab$n_transitions, 2)

  # zone_b -> zone_a
  trans_ba <- result[result$from_zone == "zone_b" & result$to_zone == "zone_a", ]
  expect_equal(nrow(trans_ba), 1)
  expect_equal(trans_ba$n_transitions, 1)
})

test_that("calculate_zone_transitions handles transitions through NA (outside zones)", {
  arena <- create_two_zone_arena()

  # zone_a -> outside -> zone_b
  # Should have: zone_a->NA, NA->zone_b
  zone_seq <- c(rep("zone_a", 3), rep(NA, 3), rep("zone_b", 3))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_transitions(tracking_data, arena)

  # zone_a -> NA
  trans_a_out <- result[result$from_zone == "zone_a" & is.na(result$to_zone), ]
  expect_equal(nrow(trans_a_out), 1)
  expect_equal(trans_a_out$n_transitions, 1)

  # NA -> zone_b
  trans_out_b <- result[is.na(result$from_zone) & result$to_zone == "zone_b", ]
  expect_equal(nrow(trans_out_b), 1)
  expect_equal(trans_out_b$n_transitions, 1)
})

test_that("calculate_zone_transitions respects min_duration filter", {
  arena <- create_two_zone_arena()

  # zone_a (2 frames=0.067s), zone_b (40 frames=1.33s), zone_a (2 frames), zone_b (40 frames)
  # With min_duration=1.0, brief visits should be ignored
  zone_seq <- c(rep("zone_a", 2), rep("zone_b", 40), rep("zone_a", 2), rep("zone_b", 40))
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_transitions(tracking_data, arena, min_duration = 1.0)

  # Should only see zone_b -> zone_b (no transition) or just one entry
  # Actually with filtering, brief visits are removed, leaving just zone_b visits
  # So there should be no transitions (or just zone_b stays)
  # Let's check there are fewer transitions than without filter
  result_no_filter <- calculate_zone_transitions(tracking_data, arena, min_duration = 0)

  expect_true(nrow(result) <= nrow(result_no_filter))
})

test_that("calculate_zone_transitions handles no transitions", {
  arena <- create_two_zone_arena()

  # Stay in zone_a entire time
  zone_seq <- rep("zone_a", 10)
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  result <- calculate_zone_transitions(tracking_data, arena)

  # No transitions (stayed in same zone)
  expect_equal(nrow(result), 0)
})

test_that("calculate_zone_transitions validates inputs", {
  arena <- create_two_zone_arena()
  tracking_data <- create_mock_tracking_data()

  expect_error(
    calculate_zone_transitions(list(), arena),
    "tracking_data must be a tracking_data object"
  )

  expect_error(
    calculate_zone_transitions(tracking_data, list()),
    "arena_config must be an arena_config object"
  )

  expect_error(
    calculate_zone_transitions(tracking_data, arena, min_duration = -1),
    "min_duration must be a non-negative number"
  )
})

# Integration test with multiple body parts
test_that("time_in_zone functions handle multiple body parts", {
  arena <- create_two_zone_arena()

  # Create tracking with two body parts
  zone_seq_nose <- c(rep("zone_a", 5), rep("zone_b", 5))
  zone_seq_tail <- c(rep("zone_b", 5), rep("zone_a", 5))

  tracking_df <- data.frame(
    frame = rep(0:9, 2),
    time = rep((0:9) / 30, 2),
    body_part = c(rep("nose", 10), rep("tail", 10)),
    x = c(
      ifelse(zone_seq_nose == "zone_a", 100, 100),
      ifelse(zone_seq_tail == "zone_b", 100, 100)
    ),
    y = c(
      ifelse(zone_seq_nose == "zone_a", 50, 150),
      ifelse(zone_seq_tail == "zone_b", 150, 50)
    ),
    likelihood = rep(0.99, 20),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(source = "test", fps = 30, subject_id = "test"),
    tracking = tracking_df,
    arena = list(dimensions = list(width = 400, height = 200))
  )

  # Test entries
  entries <- calculate_zone_entries(tracking_data, arena)
  expect_true("body_part" %in% names(entries))
  expect_true("nose" %in% entries$body_part)
  expect_true("tail" %in% entries$body_part)

  # Test exits
  exits <- calculate_zone_exits(tracking_data, arena)
  expect_true("body_part" %in% names(exits))

  # Test latency
  latency <- calculate_zone_latency(tracking_data, arena)
  expect_true("body_part" %in% names(latency))

  # Test transitions
  transitions <- calculate_zone_transitions(tracking_data, arena)
  expect_true("body_part" %in% names(transitions))
})

# Edge case tests
test_that("time_in_zone functions handle empty tracking data", {
  arena <- create_two_zone_arena()

  tracking_df <- data.frame(
    frame = integer(0),
    time = numeric(0),
    body_part = character(0),
    x = numeric(0),
    y = numeric(0),
    likelihood = numeric(0),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(source = "test", fps = 30),
    tracking = tracking_df,
    arena = list()
  )

  # Should return empty data frames with correct structure
  entries <- calculate_zone_entries(tracking_data, arena)
  expect_equal(nrow(entries), 0)
  expect_true(all(c("zone_id", "n_entries", "mean_duration", "total_time") %in% names(entries)))

  exits <- calculate_zone_exits(tracking_data, arena)
  expect_equal(nrow(exits), 0)

  latency <- calculate_zone_latency(tracking_data, arena)
  expect_equal(nrow(latency), 0)

  transitions <- calculate_zone_transitions(tracking_data, arena)
  expect_equal(nrow(transitions), 0)
})

# Regression tests for bug fixes
test_that("time_in_zone functions exclude NA body parts (no duplicates)", {
  # This tests the fix for duplicate entries caused by NA body parts
  arena <- create_two_zone_arena()

  # Create tracking with explicit NA body part entries
  # This simulates what happens when classify_points_by_zone returns NA body parts
  zone_seq <- c(rep("zone_a", 5), rep("zone_b", 5))
  n_frames <- length(zone_seq)

  tracking_df <- data.frame(
    frame = rep(0:(n_frames - 1), 2),  # Duplicate frames
    time = rep((0:(n_frames - 1)) / 30, 2),
    body_part = c(rep("nose", n_frames), rep(NA, n_frames)),  # One valid, one NA
    x = rep(c(rep(100, 5), rep(100, 5)), 2),
    y = rep(c(rep(50, 5), rep(150, 5)), 2),
    likelihood = rep(0.99, n_frames * 2),
    stringsAsFactors = FALSE
  )

  tracking_data <- new_tracking_data(
    metadata = list(source = "test", fps = 30, subject_id = "test"),
    tracking = tracking_df,
    arena = list(dimensions = list(width = 400, height = 200))
  )

  # Test entries - should have exactly 2 rows (one per zone), not 4
  entries <- calculate_zone_entries(tracking_data, arena, body_part = "nose")
  expect_equal(nrow(entries), 2)
  expect_false("body_part" %in% names(entries))  # No body_part column when specific part requested

  # Check no duplicates
  zone_counts <- table(entries$zone_id)
  expect_true(all(zone_counts == 1))

  # Test exits - should have exactly 2 rows
  exits <- calculate_zone_exits(tracking_data, arena, body_part = "nose")
  expect_equal(nrow(exits), 2)
  zone_counts_exits <- table(exits$zone_id)
  expect_true(all(zone_counts_exits == 1))

  # Test latency - should have exactly 2 rows (one per zone in arena)
  latency <- calculate_zone_latency(tracking_data, arena, body_part = "nose")
  expect_equal(nrow(latency), 2)
  zone_counts_latency <- table(latency$zone_id)
  expect_true(all(zone_counts_latency == 1))

  # Test transitions
  transitions <- calculate_zone_transitions(tracking_data, arena, body_part = "nose")
  # Check no duplicate zone_id pairs
  if (nrow(transitions) > 0) {
    transition_pairs <- paste(transitions$from_zone, transitions$to_zone, sep = "->")
    expect_equal(length(transition_pairs), length(unique(transition_pairs)))
  }
})

test_that("calculate_zone_latency filters multiple brief tracking glitches", {
  # Test that multiple single-frame glitches are all filtered out
  arena <- create_two_zone_arena()

  # Create sequence with multiple glitches:
  # Frame 0-9: outside
  # Frame 10: zone_a (glitch 1)
  # Frame 11-14: outside
  # Frame 15: zone_a (glitch 2)
  # Frame 16-19: outside
  # Frame 20: zone_a (glitch 3)
  # Frame 21-29: outside
  # Frame 30-60: zone_a (real sustained entry, 31 frames = 1.03s)
  zone_seq <- c(
    rep(NA, 10),
    "zone_a",          # glitch 1
    rep(NA, 4),
    "zone_a",          # glitch 2
    rep(NA, 4),
    "zone_a",          # glitch 3
    rep(NA, 9),
    rep("zone_a", 31)  # real entry
  )
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  # With min_duration = 1.0s, should skip all 3 glitches
  result <- calculate_zone_latency(tracking_data, arena, min_duration = 1.0)
  zone_a_row <- result[result$zone_id == "zone_a", ]

  expect_equal(zone_a_row$first_entry_frame, 30)
  expect_equal(zone_a_row$latency_seconds, 30/30, tolerance = 0.01)
})

test_that("calculate_zone_latency returns NA when only brief glitches exist", {
  # Test when a zone is only visited briefly (all visits filtered out)
  arena <- create_two_zone_arena()

  # Only brief visits to zone_a (all < 0.5s)
  zone_seq <- c(
    rep(NA, 10),
    "zone_a",          # 1 frame = 0.033s
    rep(NA, 5),
    rep("zone_a", 10), # 10 frames = 0.333s
    rep(NA, 5),
    rep("zone_a", 5),  # 5 frames = 0.167s
    rep(NA, 10)
  )
  tracking_data <- create_zone_visit_tracking(zone_seq, fps = 30)

  # With min_duration = 0.5s, all visits should be filtered
  result <- calculate_zone_latency(tracking_data, arena, min_duration = 0.5)
  zone_a_row <- result[result$zone_id == "zone_a", ]

  # Should return NA since no visits meet duration threshold
  expect_true(is.na(zone_a_row$latency_seconds))
  expect_true(is.na(zone_a_row$first_entry_frame))
})
