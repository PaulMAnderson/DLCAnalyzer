test_that("read_dlc_csv validates file existence", {
  expect_error(
    read_dlc_csv("nonexistent_file.csv"),
    "File not found"
  )
})

test_that("read_dlc_csv validates fps parameter", {
  # Create a temporary minimal DLC file for testing
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC",
    "bodyparts,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95"
  ), temp_file)

  expect_error(
    read_dlc_csv(temp_file, fps = -1),
    "fps must be a positive number"
  )

  expect_error(
    read_dlc_csv(temp_file, fps = 0),
    "fps must be a positive number"
  )

  unlink(temp_file)
})

test_that("read_dlc_csv reads DLC file correctly", {
  # Create a minimal DLC file
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95",
    "1,105,205,0.96"
  ), temp_file)

  result <- read_dlc_csv(temp_file, fps = 30)

  expect_type(result, "list")
  expect_true("raw_data" %in% names(result))
  expect_true("bodyparts" %in% names(result))
  expect_true("fps" %in% names(result))
  expect_equal(result$fps, 30)
  expect_equal(result$n_frames, 2)

  unlink(temp_file)
})

test_that("parse_dlc_data creates correct long format", {
  # Create a minimal DLC file with two body parts
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose,tail,tail,tail",
    "coords,x,y,likelihood,x,y,likelihood",
    "0,100,200,0.95,150,250,0.90",
    "1,105,205,0.96,155,255,0.91"
  ), temp_file)

  dlc_raw <- read_dlc_csv(temp_file, fps = 30)
  tracking_df <- parse_dlc_data(dlc_raw)

  # Should have 4 rows (2 frames × 2 body parts)
  expect_equal(nrow(tracking_df), 4)

  # Check column names
  expected_cols <- c("frame", "time", "body_part", "x", "y", "likelihood")
  expect_true(all(expected_cols %in% names(tracking_df)))

  # Check body parts
  expect_equal(length(unique(tracking_df$body_part)), 2)
  expect_true("nose" %in% tracking_df$body_part)
  expect_true("tail" %in% tracking_df$body_part)

  # Check time calculation
  expect_equal(tracking_df$time[tracking_df$frame == 0], rep(0, 2))
  expect_equal(tracking_df$time[tracking_df$frame == 1], rep(1/30, 2))

  # Check data values for nose
  nose_frame0 <- tracking_df[tracking_df$body_part == "nose" & tracking_df$frame == 0, ]
  expect_equal(nose_frame0$x, 100)
  expect_equal(nose_frame0$y, 200)
  expect_equal(nose_frame0$likelihood, 0.95)

  unlink(temp_file)
})

test_that("get_dlc_bodyparts extracts body part names", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose,tail,tail,tail,head,head,head",
    "coords,x,y,likelihood,x,y,likelihood,x,y,likelihood",
    "0,100,200,0.95,150,250,0.90,110,210,0.92"
  ), temp_file)

  dlc_raw <- read_dlc_csv(temp_file, fps = 30)
  bodyparts <- get_dlc_bodyparts(dlc_raw)

  expect_equal(length(bodyparts), 3)
  expect_true("nose" %in% bodyparts)
  expect_true("tail" %in% bodyparts)
  expect_true("head" %in% bodyparts)

  unlink(temp_file)
})

test_that("summarize_dlc_tracking calculates correct statistics", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95",
    "1,102,202,0.96",
    "2,104,204,0.97",
    "3,106,206,0.98",
    "4,108,208,0.99"
  ), temp_file)

  dlc_raw <- read_dlc_csv(temp_file, fps = 30)
  summary_stats <- summarize_dlc_tracking(dlc_raw)

  expect_equal(nrow(summary_stats), 1)
  expect_equal(summary_stats$body_part, "nose")
  expect_equal(summary_stats$median_x, 104)
  expect_equal(summary_stats$median_y, 204)
  expect_equal(summary_stats$n_frames, 5)
  expect_equal(summary_stats$pct_valid, 100)

  # Test mean likelihood
  expected_mean_likelihood <- mean(c(0.95, 0.96, 0.97, 0.98, 0.99))
  expect_equal(summary_stats$mean_likelihood, expected_mean_likelihood)

  unlink(temp_file)
})

test_that("summarize_dlc_tracking handles low likelihood values", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95",
    "1,102,202,0.30",
    "2,104,204,0.20",
    "3,106,206,0.98",
    "4,108,208,0.99"
  ), temp_file)

  dlc_raw <- read_dlc_csv(temp_file, fps = 30)
  summary_stats <- summarize_dlc_tracking(dlc_raw)

  # Only 3 out of 5 frames have likelihood > 0.5
  expect_equal(summary_stats$pct_valid, 60)

  unlink(temp_file)
})

test_that("is_dlc_csv correctly identifies DLC files", {
  # Create a valid DLC file
  temp_dlc <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95"
  ), temp_dlc)

  expect_true(is_dlc_csv(temp_dlc))

  # Create a non-DLC file
  temp_other <- tempfile(fileext = ".csv")
  writeLines(c(
    "x,y,z",
    "1,2,3",
    "4,5,6"
  ), temp_other)

  expect_false(is_dlc_csv(temp_other))

  # Test non-existent file
  expect_false(is_dlc_csv("nonexistent_file.csv"))

  unlink(temp_dlc)
  unlink(temp_other)
})

test_that("parse_dlc_data handles multiple body parts correctly", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose,bodycentre,bodycentre,bodycentre,tail,tail,tail",
    "coords,x,y,likelihood,x,y,likelihood,x,y,likelihood",
    "0,100,200,0.95,250,300,0.96,400,450,0.94",
    "1,101,201,0.95,251,301,0.96,401,451,0.94",
    "2,102,202,0.95,252,302,0.96,402,452,0.94"
  ), temp_file)

  dlc_raw <- read_dlc_csv(temp_file, fps = 30)
  tracking_df <- parse_dlc_data(dlc_raw)

  # Should have 9 rows (3 frames × 3 body parts)
  expect_equal(nrow(tracking_df), 9)

  # Check that all body parts are present
  bodyparts <- unique(tracking_df$body_part)
  expect_equal(length(bodyparts), 3)
  expect_true(all(c("nose", "bodycentre", "tail") %in% bodyparts))

  # Check specific values
  nose_frame0 <- tracking_df[tracking_df$body_part == "nose" & tracking_df$frame == 0, ]
  expect_equal(nrow(nose_frame0), 1)
  expect_equal(nose_frame0$x, 100)
  expect_equal(nose_frame0$y, 200)

  bodycentre_frame1 <- tracking_df[tracking_df$body_part == "bodycentre" & tracking_df$frame == 1, ]
  expect_equal(bodycentre_frame1$x, 251)
  expect_equal(bodycentre_frame1$y, 301)

  unlink(temp_file)
})
