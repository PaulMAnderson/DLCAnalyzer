# Source required files
source("../../R/core/data_structures.R")
source("../../R/core/data_loading.R")
source("../../R/core/data_converters.R")

test_that("convert_dlc_to_tracking_data creates valid tracking_data object", {
  # Create a test DLC file
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose,tail,tail,tail",
    "coords,x,y,likelihood,x,y,likelihood",
    "0,100,200,0.95,150,250,0.90",
    "1,105,205,0.96,155,255,0.91",
    "2,110,210,0.97,160,260,0.92"
  ), temp_file)

  # Convert to tracking_data
  result <- convert_dlc_to_tracking_data(
    temp_file,
    fps = 30,
    subject_id = "test_mouse",
    paradigm = "open_field"
  )

  # Check it's a valid tracking_data object
  expect_true(is_tracking_data(result))
  expect_s3_class(result, "tracking_data")

  # Check metadata
  expect_equal(result$metadata$source, "deeplabcut")
  expect_equal(result$metadata$fps, 30)
  expect_equal(result$metadata$subject_id, "test_mouse")
  expect_equal(result$metadata$paradigm, "open_field")

  # Check tracking data
  expect_true(is.data.frame(result$tracking))
  expect_true("body_part" %in% names(result$tracking))
  expect_equal(length(unique(result$tracking$body_part)), 2)

  # Check arena
  expect_true(!is.null(result$arena))
  expect_true(!is.null(result$arena$dimensions))

  unlink(temp_file)
})

test_that("convert_dlc_to_tracking_data separates reference points", {
  # Create a test DLC file with reference points
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,tl,tl,tl,tr,tr,tr,nose,nose,nose,tail,tail,tail",
    "coords,x,y,likelihood,x,y,likelihood,x,y,likelihood,x,y,likelihood",
    "0,10,10,0.99,490,10,0.99,100,200,0.95,150,250,0.90",
    "1,10,10,0.99,490,10,0.99,105,205,0.96,155,255,0.91",
    "2,10,10,0.99,490,10,0.99,110,210,0.97,160,260,0.92"
  ), temp_file)

  # Convert with reference points specified
  result <- convert_dlc_to_tracking_data(
    temp_file,
    fps = 30,
    subject_id = "test_mouse",
    paradigm = "open_field",
    reference_point_names = c("tl", "tr", "bl", "br")
  )

  # Check that body parts don't include reference points
  bodyparts <- unique(result$tracking$body_part)
  expect_false("tl" %in% bodyparts)
  expect_false("tr" %in% bodyparts)
  expect_true("nose" %in% bodyparts)
  expect_true("tail" %in% bodyparts)

  # Check that reference points are in arena
  expect_true(!is.null(result$arena$reference_points))
  expect_true("tl" %in% result$arena$reference_points$point_name)
  expect_true("tr" %in% result$arena$reference_points$point_name)

  unlink(temp_file)
})

test_that("infer_arena_dimensions calculates correct dimensions", {
  tracking_df <- data.frame(
    frame = rep(1:3, 2),
    time = rep(c(0, 0.033, 0.066), 2),
    body_part = rep(c("nose", "tail"), each = 3),
    x = c(100, 150, 200, 120, 170, 220),
    y = c(200, 250, 300, 220, 270, 320),
    likelihood = rep(0.95, 6)
  )

  dims <- infer_arena_dimensions(tracking_df)

  # Max x is 220, max y is 320
  # With 10% buffer: width ~ 242, height ~ 352
  expect_true(dims$width >= 220)
  expect_true(dims$height >= 320)
  expect_true(dims$width <= 250)
  expect_true(dims$height <= 360)
})

test_that("extract_subject_id_from_filename works with common patterns", {
  # Test various filename patterns
  expect_equal(extract_subject_id_from_filename("Mouse_01_DLC.csv"), "Mouse_01")
  expect_equal(extract_subject_id_from_filename("EPM_10DeepCut_resnet.csv"), "EPM_10")
  expect_equal(extract_subject_id_from_filename("OFT1_tracking.csv"), "OFT1")
  expect_equal(extract_subject_id_from_filename("subject123.csv"), "subject123")
})

test_that("detect_reference_points identifies stationary points", {
  tracking_df <- data.frame(
    frame = rep(1:10, 3),
    time = rep(seq(0, length.out = 10, by = 0.033), 3),
    body_part = rep(c("tl", "nose", "tail"), each = 10),
    x = c(rep(10, 10),  # tl is stationary
          seq(100, 200, length.out = 10),  # nose moves
          seq(150, 250, length.out = 10)), # tail moves
    y = c(rep(10, 10),  # tl is stationary
          seq(200, 300, length.out = 10),  # nose moves
          seq(250, 350, length.out = 10)), # tail moves
    likelihood = rep(0.95, 30)
  )

  ref_points <- detect_reference_points(tracking_df, movement_threshold = 5)

  expect_true("tl" %in% ref_points)
  expect_false("nose" %in% ref_points)
  expect_false("tail" %in% ref_points)
})

test_that("get_bodyparts extracts body part names", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose,tail,tail,tail,head,head,head",
    "coords,x,y,likelihood,x,y,likelihood,x,y,likelihood",
    "0,100,200,0.95,150,250,0.90,110,210,0.92"
  ), temp_file)

  data <- convert_dlc_to_tracking_data(temp_file, fps = 30)
  bodyparts <- get_bodyparts(data)

  expect_equal(length(bodyparts), 3)
  expect_true("nose" %in% bodyparts)
  expect_true("tail" %in% bodyparts)
  expect_true("head" %in% bodyparts)

  unlink(temp_file)
})

test_that("get_reference_points extracts reference point names", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC,DLC",
    "bodyparts,tl,tl,tl,tr,tr,tr,nose,nose,nose",
    "coords,x,y,likelihood,x,y,likelihood,x,y,likelihood",
    "0,10,10,0.99,490,10,0.99,100,200,0.95"
  ), temp_file)

  data <- convert_dlc_to_tracking_data(
    temp_file,
    fps = 30,
    reference_point_names = c("tl", "tr")
  )

  ref_points <- get_reference_points(data)

  expect_equal(length(ref_points), 2)
  expect_true("tl" %in% ref_points)
  expect_true("tr" %in% ref_points)

  unlink(temp_file)
})

test_that("load_tracking_data auto-detects DLC format", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95"
  ), temp_file)

  # Should auto-detect and load
  expect_message(
    result <- load_tracking_data(temp_file, fps = 30),
    "Auto-detected source type: deeplabcut"
  )

  expect_true(is_tracking_data(result))

  unlink(temp_file)
})

test_that("load_tracking_data validates file existence", {
  expect_error(
    load_tracking_data("nonexistent.csv"),
    "File not found"
  )
})

test_that("detect_source_type identifies DLC files", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c(
    "scorer,DLC,DLC,DLC",
    "bodyparts,nose,nose,nose",
    "coords,x,y,likelihood",
    "0,100,200,0.95"
  ), temp_file)

  source_type <- detect_source_type(temp_file)
  expect_equal(source_type, "deeplabcut")

  unlink(temp_file)
})
