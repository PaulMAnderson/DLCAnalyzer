#!/usr/bin/env Rscript
# Integration test for Ethovision XT import functionality
# Tests the complete pipeline from Excel file to tracking_data object

cat("================================================================================\n")
cat("ETHOVISION XT IMPORT INTEGRATION TEST\n")
cat("================================================================================\n\n")

# Load required functions
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")

# Test files
oft_file <- "data/OFT/Example Exported Data/Raw data-Rebecca OF Oct20th2025-Trial     1.xlsx"
nort_file <- "data/NORT/Example Exported Data/Raw data-NORT D3 20251003-Trial     1 (1).xlsx"
ld_file <- "data/LD/Example Exported Data/Raw data-LD Rebecca 20251022-Trial     1.xlsx"  # Trial 2 has no data

test_count <- 0
pass_count <- 0
fail_count <- 0

run_test <- function(test_name, test_expr) {
  test_count <<- test_count + 1
  cat(sprintf("\n[Test %d] %s\n", test_count, test_name))

  result <- tryCatch({
    test_expr
    cat("  ✓ PASS\n")
    pass_count <<- pass_count + 1
    TRUE
  }, error = function(e) {
    cat(sprintf("  ✗ FAIL: %s\n", conditionMessage(e)))
    fail_count <<- fail_count + 1
    FALSE
  })

  return(result)
}

# ==============================================================================
# TEST 1: File Detection
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 1: File Format Detection\n")
cat(rep("=", 60), "\n", sep="")

run_test("Detect OFT file as Ethovision", {
  is_etho <- is_ethovision_excel(oft_file)
  stopifnot(is_etho == TRUE)
})

run_test("Detect NORT file as Ethovision", {
  is_etho <- is_ethovision_excel(nort_file)
  stopifnot(is_etho == TRUE)
})

run_test("Auto-detect source type", {
  source_type <- detect_source_type(oft_file)
  stopifnot(source_type == "ethovision")
})

# ==============================================================================
# TEST 2: Read Single Sheet
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 2: Read Single Sheet\n")
cat(rep("=", 60), "\n", sep="")

etho_raw <- NULL

run_test("Read OFT Excel file (single sheet)", {
  etho_raw <<- read_ethovision_excel(oft_file, fps = 25)
  stopifnot(is.list(etho_raw))
  stopifnot("data" %in% names(etho_raw))
  stopifnot("metadata" %in% names(etho_raw))
  stopifnot("column_info" %in% names(etho_raw))
})

run_test("Check metadata extraction", {
  stopifnot(!is.null(etho_raw$metadata$experiment))
  stopifnot(!is.null(etho_raw$metadata$subject_name))
  stopifnot(!is.null(etho_raw$metadata$arena_name))
  cat(sprintf("    Experiment: %s\n", etho_raw$metadata$experiment))
  cat(sprintf("    Subject: %s\n", etho_raw$metadata$subject_name))
  cat(sprintf("    Arena: %s\n", etho_raw$metadata$arena_name))
})

run_test("Check data dimensions", {
  stopifnot(nrow(etho_raw$data) > 0)
  stopifnot(ncol(etho_raw$data) > 0)
  cat(sprintf("    Data shape: %d rows x %d columns\n",
              nrow(etho_raw$data), ncol(etho_raw$data)))
})

run_test("Check column info", {
  stopifnot(nrow(etho_raw$column_info) > 0)
  stopifnot("column_name" %in% names(etho_raw$column_info))
  stopifnot("unit" %in% names(etho_raw$column_info))
  cat(sprintf("    Found %d columns\n", nrow(etho_raw$column_info)))
})

# ==============================================================================
# TEST 3: Parse Tracking Data
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 3: Parse Tracking Data\n")
cat(rep("=", 60), "\n", sep="")

tracking_df <- NULL

run_test("Parse Ethovision data to long format", {
  tracking_df <<- parse_ethovision_data(etho_raw)
  stopifnot(is.data.frame(tracking_df))
  stopifnot(all(c("frame", "time", "body_part", "x", "y", "likelihood") %in%
                names(tracking_df)))
})

run_test("Check parsed data structure", {
  stopifnot(nrow(tracking_df) > 0)
  body_parts <- unique(tracking_df$body_part)
  cat(sprintf("    Parsed %d rows\n", nrow(tracking_df)))
  cat(sprintf("    Body parts: %s\n", paste(body_parts, collapse = ", ")))
  stopifnot(length(body_parts) > 0)
})

run_test("Check coordinate data types", {
  stopifnot(is.numeric(tracking_df$x))
  stopifnot(is.numeric(tracking_df$y))
  stopifnot(is.numeric(tracking_df$time))
  stopifnot(is.numeric(tracking_df$likelihood))
})

run_test("Check likelihood values (should all be 1.0)", {
  stopifnot(all(tracking_df$likelihood == 1.0, na.rm = TRUE))
})

# ==============================================================================
# TEST 4: Convert to tracking_data Object
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 4: Convert to tracking_data Object\n")
cat(rep("=", 60), "\n", sep="")

tracking_obj <- NULL

run_test("Convert Ethovision to tracking_data", {
  tracking_obj <<- convert_ethovision_to_tracking_data(
    oft_file,
    fps = 25,
    paradigm = "open_field"
  )
  stopifnot(is_tracking_data(tracking_obj))
})

run_test("Validate tracking_data structure", {
  # Should not throw error
  validate_tracking_data(tracking_obj)
})

run_test("Check metadata in tracking_data", {
  stopifnot(tracking_obj$metadata$source == "ethovision")
  stopifnot(tracking_obj$metadata$fps == 25)
  stopifnot(tracking_obj$metadata$units == "cm")
  stopifnot(!is.null(tracking_obj$metadata$subject_id))
  cat(sprintf("    Source: %s\n", tracking_obj$metadata$source))
  cat(sprintf("    FPS: %d\n", tracking_obj$metadata$fps))
  cat(sprintf("    Units: %s\n", tracking_obj$metadata$units))
  cat(sprintf("    Subject: %s\n", tracking_obj$metadata$subject_id))
})

run_test("Check arena information", {
  stopifnot(!is.null(tracking_obj$arena))
  stopifnot(!is.null(tracking_obj$arena$dimensions))
  stopifnot(tracking_obj$arena$dimensions$units == "cm")
  cat(sprintf("    Arena: %.1f x %.1f %s\n",
              tracking_obj$arena$dimensions$width,
              tracking_obj$arena$dimensions$height,
              tracking_obj$arena$dimensions$units))
})

run_test("Check body parts extraction", {
  body_parts <- get_bodyparts(tracking_obj)
  stopifnot(length(body_parts) > 0)
  cat(sprintf("    Body parts: %s\n", paste(body_parts, collapse = ", ")))
})

run_test("Print method works", {
  output <- capture.output(print(tracking_obj))
  stopifnot(length(output) > 0)
})

run_test("Summary method works", {
  output <- capture.output(summary(tracking_obj))
  stopifnot(length(output) > 0)
})

# ==============================================================================
# TEST 5: Multi-Sheet Support
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 5: Multi-Sheet/Multi-Animal Support\n")
cat(rep("=", 60), "\n", sep="")

all_sheets <- NULL

run_test("Read all sheets from OFT file", {
  all_sheets <<- read_ethovision_excel_multi(oft_file, fps = 25)
  stopifnot(is.list(all_sheets))
  stopifnot(length(all_sheets) > 0)
  cat(sprintf("    Found %d sheets\n", length(all_sheets)))
  cat(sprintf("    Sheet names: %s\n", paste(names(all_sheets), collapse = ", ")))
})

run_test("Each sheet has valid data", {
  for (sheet_name in names(all_sheets)) {
    sheet_data <- all_sheets[[sheet_name]]
    stopifnot(is.list(sheet_data))
    stopifnot("data" %in% names(sheet_data))
    stopifnot(nrow(sheet_data$data) > 0)
  }
})

all_tracking <- NULL

run_test("Convert multi-sheet file to tracking_data list", {
  all_tracking <<- convert_ethovision_multi(oft_file, fps = 25, paradigm = "open_field")
  stopifnot(is.list(all_tracking))
  stopifnot(length(all_tracking) > 0)
  cat(sprintf("    Converted %d animals\n", length(all_tracking)))
})

run_test("Each tracking_data object is valid", {
  for (sheet_name in names(all_tracking)) {
    obj <- all_tracking[[sheet_name]]
    stopifnot(is_tracking_data(obj))
    validate_tracking_data(obj)
  }
})

# ==============================================================================
# TEST 6: Different Paradigms
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 6: Different Behavioral Paradigms\n")
cat(rep("=", 60), "\n", sep="")

run_test("Load NORT data", {
  nort_data <- convert_ethovision_to_tracking_data(
    nort_file,
    fps = 25,
    paradigm = "novel_object"
  )
  stopifnot(is_tracking_data(nort_data))
  stopifnot(nort_data$metadata$paradigm == "novel_object")
  cat(sprintf("    NORT data: %d frames\n", nrow(nort_data$tracking) / length(unique(nort_data$tracking$body_part))))
})

run_test("Load LD data", {
  ld_data <- convert_ethovision_to_tracking_data(
    ld_file,
    fps = 25,
    paradigm = "light_dark"
  )
  stopifnot(is_tracking_data(ld_data))
  stopifnot(ld_data$metadata$paradigm == "light_dark")
  cat(sprintf("    LD data: %d frames\n", nrow(ld_data$tracking) / length(unique(ld_data$tracking$body_part))))
})

# ==============================================================================
# TEST 7: Auto-Detection and load_tracking_data
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep="")
cat("TEST SECTION 7: Auto-Detection with load_tracking_data()\n")
cat(rep("=", 60), "\n", sep="")

run_test("Auto-load Ethovision file", {
  auto_data <- load_tracking_data(oft_file, fps = 25, paradigm = "open_field")
  stopifnot(is_tracking_data(auto_data))
  stopifnot(auto_data$metadata$source == "ethovision")
})

run_test("Explicit source_type specification", {
  explicit_data <- load_tracking_data(oft_file, source_type = "ethovision",
                                       fps = 25, paradigm = "open_field")
  stopifnot(is_tracking_data(explicit_data))
})

# ==============================================================================
# SUMMARY
# ==============================================================================
cat("\n\n")
cat("================================================================================\n")
cat("TEST SUMMARY\n")
cat("================================================================================\n")
cat(sprintf("Total tests: %d\n", test_count))
cat(sprintf("Passed: %d (%.1f%%)\n", pass_count, pass_count/test_count*100))
cat(sprintf("Failed: %d (%.1f%%)\n", fail_count, fail_count/test_count*100))
cat("================================================================================\n")

if (fail_count == 0) {
  cat("\n✓ ALL TESTS PASSED!\n\n")
  cat("Ethovision XT import functionality is working correctly:\n")
  cat("  • File format detection\n")
  cat("  • Single-sheet data loading\n")
  cat("  • Multi-sheet/multi-animal support\n")
  cat("  • Metadata extraction\n")
  cat("  • Coordinate parsing\n")
  cat("  • tracking_data conversion\n")
  cat("  • Multiple paradigms (OFT, NORT, LD)\n")
  cat("  • Auto-detection integration\n\n")
  quit(status = 0)
} else {
  cat("\n✗ SOME TESTS FAILED\n")
  cat("Please review the errors above.\n\n")
  quit(status = 1)
}
