# tests/test_group_comparisons.R
# Integration test for group comparison functions

# Source all R files
source("R/core/data_structures.R")
source("R/core/data_loading.R")
source("R/core/data_converters.R")
source("R/core/arena_config.R")
source("R/core/zone_geometry.R")
source("R/utils/config_utils.R")
source("R/metrics/zone_analysis.R")
source("R/metrics/movement_metrics.R")
source("R/reporting/group_comparisons.R")
source("R/reporting/generate_report.R")
# source("R/visualization/plot_comparisons.R")  # TODO: Fix syntax issue

# Load ggplot2 if available
if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
}

cat("\n=== Testing Group Comparison Functions ===\n\n")

# Create mock data for two subjects
create_mock_subject_metrics <- function(subject_id, group, mean_val = 100, sd_val = 10) {
  data.frame(
    subject_id = subject_id,
    group = group,
    total_distance = rnorm(1, mean_val, sd_val),
    mean_velocity = rnorm(1, mean_val / 20, sd_val / 20),
    max_velocity = rnorm(1, mean_val / 5, sd_val / 5),
    zone_open_time = rnorm(1, mean_val / 2, sd_val / 2),
    zone_closed_time = rnorm(1, mean_val * 1.5, sd_val * 1.5),
    stringsAsFactors = FALSE
  )
}

# Test 1: Compare two subjects
cat("Step 1: Testing compare_subjects()...\n")
tryCatch({
  metrics_a <- create_mock_subject_metrics("Subject_A", "Control", mean_val = 100)
  metrics_b <- create_mock_subject_metrics("Subject_B", "Treatment", mean_val = 120)

  comparison <- compare_subjects(metrics_a, metrics_b,
                                subject_id_a = "Subject_A",
                                subject_id_b = "Subject_B",
                                test_type = "t.test")

  cat("  Comparison Results:\n")
  print(comparison)
  cat("  SUCCESS: compare_subjects()\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 2: Compare groups
cat("Step 2: Testing compare_groups()...\n")
tryCatch({
  # Create control group (lower values)
  control_metrics <- lapply(1:5, function(i) {
    create_mock_subject_metrics(paste0("Control_", i), "Control",
                               mean_val = 100, sd_val = 15)
  })

  # Create treatment group (higher values)
  treatment_metrics <- lapply(1:5, function(i) {
    create_mock_subject_metrics(paste0("Treatment_", i), "Treatment",
                               mean_val = 140, sd_val = 20)
  })

  # Compare groups
  group_comparison <- compare_groups(control_metrics, treatment_metrics,
                                    group_a_name = "Control",
                                    group_b_name = "Treatment",
                                    test_type = "t.test",
                                    correction = "fdr")

  cat("  Group Comparison Results:\n")
  print(group_comparison)
  cat("\n  SUCCESS: compare_groups()\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 3: Calculate Cohen's d
cat("Step 3: Testing calculate_cohens_d()...\n")
tryCatch({
  values_a <- rnorm(20, mean = 100, sd = 15)
  values_b <- rnorm(20, mean = 120, sd = 15)

  cohens_d <- calculate_cohens_d(values_a, values_b)

  cat("  Cohen's d:", round(cohens_d, 3), "\n")
  cat("  Interpretation:",
      ifelse(abs(cohens_d) < 0.2, "Small effect",
      ifelse(abs(cohens_d) < 0.5, "Medium effect",
      "Large effect")), "\n")
  cat("  SUCCESS: calculate_cohens_d()\n\n")
}, error = function(e) {
  cat("  ERROR:", e$message, "\n\n")
})

# Test 4: Visualization - Group comparison plot
cat("Step 4: Testing plot_group_comparison()...\n")
if (requireNamespace("ggplot2", quietly = TRUE)) {
  tryCatch({
    # Create sample data
    metric_data <- rbind(
      data.frame(
        subject_id = paste0("Control_", 1:10),
        group = "Control",
        value = rnorm(10, 100, 15)
      ),
      data.frame(
        subject_id = paste0("Treatment_", 1:10),
        group = "Treatment",
        value = rnorm(10, 130, 20)
      )
    )

    p <- plot_group_comparison(metric_data, "Distance Traveled (cm)",
                               plot_type = "violin")

    cat("  SUCCESS: plot_group_comparison() created\n")

    # Save plot
    if (!dir.exists("reports/test_comparisons")) {
      dir.create("reports/test_comparisons", recursive = TRUE)
    }
    ggsave("reports/test_comparisons/group_comparison.png", p,
           width = 8, height = 6, dpi = 150)
    cat("  - Saved to: reports/test_comparisons/group_comparison.png\n\n")
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n\n")
  })
} else {
  cat("  SKIPPED: ggplot2 not available\n\n")
}

# Test 5: Visualization - Effect sizes
cat("Step 5: Testing plot_effect_sizes()...\n")
if (requireNamespace("ggplot2", quietly = TRUE)) {
  tryCatch({
    # Use comparison results from earlier
    if (exists("group_comparison")) {
      p <- plot_effect_sizes(group_comparison)

      cat("  SUCCESS: plot_effect_sizes() created\n")

      # Save plot
      ggsave("reports/test_comparisons/effect_sizes.png", p,
             width = 8, height = 6, dpi = 150)
      cat("  - Saved to: reports/test_comparisons/effect_sizes.png\n\n")
    }
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n\n")
  })
} else {
  cat("  SKIPPED: ggplot2 not available\n\n")
}

# Test 6: Visualization - P-values
cat("Step 6: Testing plot_pvalues()...\n")
if (requireNamespace("ggplot2", quietly = TRUE)) {
  tryCatch({
    if (exists("group_comparison")) {
      p <- plot_pvalues(group_comparison, alpha = 0.05, use_adjusted = TRUE)

      cat("  SUCCESS: plot_pvalues() created\n")

      # Save plot
      ggsave("reports/test_comparisons/pvalues.png", p,
             width = 8, height = 6, dpi = 150)
      cat("  - Saved to: reports/test_comparisons/pvalues.png\n\n")
    }
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n\n")
  })
} else {
  cat("  SKIPPED: ggplot2 not available\n\n")
}

# Test 7: Summary statistics
cat("Step 7: Summary of group comparison results...\n")
if (exists("group_comparison")) {
  cat("\n  Metrics with significant differences (p < 0.05):\n")
  significant <- group_comparison[group_comparison$p_adjusted < 0.05, ]

  if (nrow(significant) > 0) {
    for (i in seq_len(nrow(significant))) {
      cat(sprintf("    - %s: p = %.4f, Cohen's d = %.2f %s\n",
                 significant$metric[i],
                 significant$p_adjusted[i],
                 significant$cohens_d[i],
                 significant$significant[i]))
    }
  } else {
    cat("    None\n")
  }

  cat("\n  Effect size interpretation:\n")
  cat("    Small effect   (|d| < 0.5): ",
      sum(abs(group_comparison$cohens_d) < 0.5, na.rm = TRUE), "metrics\n")
  cat("    Medium effect  (0.5 <= |d| < 0.8): ",
      sum(abs(group_comparison$cohens_d) >= 0.5 &
          abs(group_comparison$cohens_d) < 0.8, na.rm = TRUE), "metrics\n")
  cat("    Large effect   (|d| >= 0.8): ",
      sum(abs(group_comparison$cohens_d) >= 0.8, na.rm = TRUE), "metrics\n")

  cat("\n")
}

cat("=== Group Comparison Testing Complete ===\n")
