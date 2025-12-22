#!/usr/bin/env Rscript
# Example: Batch Analysis of All Paradigms
#
# This master script processes all available data for EPM, OFT, NORT, and LD paradigms.
# It generates individual reports and creates a cross-paradigm summary.

# ============================================================================
# SETUP
# ============================================================================

setwd("/mnt/g/Bella/Rebecca/Code/DLCAnalyzer")
source("tests/testthat/setup.R")

if (!requireNamespace("readxl", quietly = TRUE)) {
  cat("Installing readxl package for Excel support...\n")
  install.packages("readxl", repos = "https://cloud.r-project.org/")
}

# ============================================================================
# CONFIGURATION
# ============================================================================

output_base <- "reports/batch_all_paradigms"
dir.create(output_base, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# FUNCTION: Process EPM Data
# ============================================================================

process_epm_data <- function() {
  cat("\n", rep("=", 70), "\n", sep = "")
  cat("PROCESSING EPM DATA\n")
  cat(rep("=", 70), "\n\n", sep = "")

  data_dir <- "data/EPM/Example DLC Data"
  files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)

  if (length(files) == 0) {
    cat("No EPM data found.\n")
    return(NULL)
  }

  arena <- load_arena_configs("config/arena_definitions/EPM/EPM.yaml",
                              arena_id = "arena1")

  results <- list()

  for (file in files) {
    subject_id <- gsub("_superanimal.*", "", basename(file))
    cat(sprintf("Processing %s...\n", subject_id))

    tryCatch({
      tracking_data <- convert_dlc_to_tracking_data(file, fps = 30,
                                                    subject_id = subject_id,
                                                    paradigm = "epm")

      occupancy <- calculate_zone_occupancy(tracking_data, arena,
                                            body_part = "mouse_center")

      results[[subject_id]] <- list(
        paradigm = "EPM",
        subject_id = subject_id,
        open_arm_pct = sum(occupancy$percentage[occupancy$zone_id %in%
                                                c("open_arm_1", "open_arm_2")])
      )

      # Generate report
      generate_subject_report(tracking_data, arena,
                            output_dir = file.path(output_base, "epm", subject_id),
                            body_part = "mouse_center")

    }, error = function(e) {
      cat(sprintf("  ERROR: %s\n", e$message))
    })
  }

  return(results)
}

# ============================================================================
# FUNCTION: Process OFT Data
# ============================================================================

process_oft_data <- function() {
  cat("\n", rep("=", 70), "\n", sep = "")
  cat("PROCESSING OFT DATA\n")
  cat(rep("=", 70), "\n\n", sep = "")

  data_dir <- "data/OFT/Example Exported Data"
  files <- list.files(data_dir, pattern = "\\.xlsx$", full.names = TRUE)

  if (length(files) == 0) {
    cat("No OFT data found.\n")
    return(NULL)
  }

  # Create or load arena config
  arena_file <- "config/arena_definitions/OF/of_standard.yaml"
  if (file.exists(arena_file)) {
    arena <- load_arena_configs(arena_file, arena_id = "arena1")
  } else {
    arena <- new_arena_config(
      arena_id = "of_default",
      dimensions = list(width = 640, height = 480),
      zones = list(
        center = list(type = "circle", center_x = 320, center_y = 240, radius = 120)
      )
    )
  }

  results <- list()

  for (file in files) {
    subject_id <- gsub("Raw data-|.xlsx|-Trial.*", "", basename(file))
    cat(sprintf("Processing %s...\n", subject_id))

    tryCatch({
      tracking_data <- convert_ethovision_to_tracking_data(file, fps = 30,
                                                           paradigm = "open_field")
      tracking_data$metadata$subject_id <- subject_id

      occupancy <- calculate_zone_occupancy(tracking_data, arena,
                                            body_part = "mouse_center")

      results[[subject_id]] <- list(
        paradigm = "OFT",
        subject_id = subject_id,
        center_pct = occupancy$percentage[occupancy$zone_id == "center"]
      )

      generate_subject_report(tracking_data, arena,
                            output_dir = file.path(output_base, "oft", subject_id),
                            body_part = "mouse_center")

    }, error = function(e) {
      cat(sprintf("  ERROR: %s\n", e$message))
    })
  }

  return(results)
}

# ============================================================================
# FUNCTION: Process NORT Data
# ============================================================================

process_nort_data <- function() {
  cat("\n", rep("=", 70), "\n", sep = "")
  cat("PROCESSING NORT DATA\n")
  cat(rep("=", 70), "\n\n", sep = "")

  data_dir <- "data/NORT/Example Exported Data"
  files <- list.files(data_dir, pattern = "\\.xlsx$", full.names = TRUE)

  if (length(files) == 0) {
    cat("No NORT data found.\n")
    return(NULL)
  }

  # Create or load arena config
  arena_file <- "config/arena_definitions/NORT/nort_standard.yaml"
  if (file.exists(arena_file)) {
    arena <- load_arena_configs(arena_file, arena_id = "arena1")
  } else {
    arena <- new_arena_config(
      arena_id = "nort_default",
      dimensions = list(width = 640, height = 480),
      zones = list(
        novel_object = list(type = "circle", center_x = 200, center_y = 240, radius = 50),
        familiar_object = list(type = "circle", center_x = 440, center_y = 240, radius = 50)
      )
    )
  }

  results <- list()

  for (file in files) {
    subject_id <- gsub("Raw data-|.xlsx|\\(1\\)|-Trial.*", "", basename(file))
    cat(sprintf("Processing %s...\n", subject_id))

    tryCatch({
      tracking_data <- convert_ethovision_to_tracking_data(file, fps = 30,
                                                           paradigm = "nort")
      tracking_data$metadata$subject_id <- subject_id

      occupancy <- calculate_zone_occupancy(tracking_data, arena,
                                            body_part = "mouse_center")

      novel <- occupancy$time_in_zone[occupancy$zone_id == "novel_object"]
      familiar <- occupancy$time_in_zone[occupancy$zone_id == "familiar_object"]

      if (length(novel) == 0) novel <- 0
      if (length(familiar) == 0) familiar <- 0

      di <- if ((novel + familiar) > 0) {
        (novel - familiar) / (novel + familiar)
      } else { 0 }

      results[[subject_id]] <- list(
        paradigm = "NORT",
        subject_id = subject_id,
        discrimination_index = di
      )

      generate_subject_report(tracking_data, arena,
                            output_dir = file.path(output_base, "nort", subject_id),
                            body_part = "mouse_center")

    }, error = function(e) {
      cat(sprintf("  ERROR: %s\n", e$message))
    })
  }

  return(results)
}

# ============================================================================
# FUNCTION: Process LD Data
# ============================================================================

process_ld_data <- function() {
  cat("\n", rep("=", 70), "\n", sep = "")
  cat("PROCESSING LIGHT/DARK BOX DATA\n")
  cat(rep("=", 70), "\n\n", sep = "")

  data_dir <- "data/LD/Example Exported Data"
  files <- list.files(data_dir, pattern = "\\.xlsx$", full.names = TRUE)

  if (length(files) == 0) {
    cat("No LD data found.\n")
    return(NULL)
  }

  # Create or load arena config
  arena_file <- "config/arena_definitions/LD/ld_standard.yaml"
  if (file.exists(arena_file)) {
    arena <- load_arena_configs(arena_file, arena_id = "arena1")
  } else {
    arena <- new_arena_config(
      arena_id = "ld_default",
      dimensions = list(width = 640, height = 480),
      zones = list(
        light = list(type = "rectangle", x_min = 0, y_min = 0, x_max = 320, y_max = 480),
        dark = list(type = "rectangle", x_min = 320, y_min = 0, x_max = 640, y_max = 480)
      )
    )
  }

  results <- list()

  for (file in files) {
    subject_id <- gsub("Raw data-|.xlsx|-Trial.*", "", basename(file))
    cat(sprintf("Processing %s...\n", subject_id))

    tryCatch({
      tracking_data <- convert_ethovision_to_tracking_data(file, fps = 30,
                                                           paradigm = "light_dark")
      tracking_data$metadata$subject_id <- subject_id

      occupancy <- calculate_zone_occupancy(tracking_data, arena,
                                            body_part = "mouse_center")

      results[[subject_id]] <- list(
        paradigm = "LD",
        subject_id = subject_id,
        light_pct = occupancy$percentage[occupancy$zone_id == "light"]
      )

      generate_subject_report(tracking_data, arena,
                            output_dir = file.path(output_base, "ld", subject_id),
                            body_part = "mouse_center")

    }, error = function(e) {
      cat(sprintf("  ERROR: %s\n", e$message))
    })
  }

  return(results)
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("BATCH PROCESSING ALL PARADIGMS\n")
cat(rep("=", 70), "\n\n", sep = "")

start_time <- Sys.time()

# Process all paradigms
epm_results <- process_epm_data()
oft_results <- process_oft_data()
nort_results <- process_nort_data()
ld_results <- process_ld_data()

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("BATCH PROCESSING COMPLETE!\n")
cat(rep("=", 70), "\n\n", sep = "")

cat(sprintf("Processing time: %.2f minutes\n\n", elapsed))

cat("Summary:\n")
cat(sprintf("  EPM subjects:  %d\n", length(epm_results)))
cat(sprintf("  OFT subjects:  %d\n", length(oft_results)))
cat(sprintf("  NORT subjects: %d\n", length(nort_results)))
cat(sprintf("  LD subjects:   %d\n", length(ld_results)))

cat(sprintf("\nTotal subjects processed: %d\n",
            sum(length(epm_results), length(oft_results),
                length(nort_results), length(ld_results))))

cat(sprintf("\nAll reports saved to: %s\n", output_base))

cat("\n", rep("=", 70), "\n", sep = "")
