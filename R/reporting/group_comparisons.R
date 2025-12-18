# R/reporting/group_comparisons.R
# Functions for statistical comparison between subjects and groups

#' Compare metrics between two subjects
#'
#' Performs statistical comparison of metrics between two subjects
#'
#' @param metrics_a Data frame with metrics for subject A
#' @param metrics_b Data frame with metrics for subject B
#' @param subject_id_a ID for subject A
#' @param subject_id_b ID for subject B
#' @param metrics Character vector of metric names to compare
#' @param test_type Statistical test: "t.test", "wilcox.test" (default: "t.test")
#'
#' @return Data frame with comparison results
#'
#' @export
compare_subjects <- function(metrics_a, metrics_b,
                            subject_id_a = "Subject_A",
                            subject_id_b = "Subject_B",
                            metrics = NULL,
                            test_type = "t.test") {
  # Validate inputs
  if (!is.data.frame(metrics_a) || !is.data.frame(metrics_b)) {
    stop("metrics_a and metrics_b must be data frames")
  }

  if (!test_type %in% c("t.test", "wilcox.test")) {
    stop("test_type must be 't.test' or 'wilcox.test'")
  }

  # Determine which metrics to compare
  if (is.null(metrics)) {
    metrics <- intersect(names(metrics_a), names(metrics_b))
    # Remove non-numeric columns
    metrics <- metrics[sapply(metrics, function(m) {
      is.numeric(metrics_a[[m]]) && is.numeric(metrics_b[[m]])
    })]
  }

  if (length(metrics) == 0) {
    stop("No numeric metrics found for comparison")
  }

  # Perform comparisons
  results_list <- lapply(metrics, function(metric_name) {
    # Get values
    values_a <- metrics_a[[metric_name]]
    values_b <- metrics_b[[metric_name]]

    # Remove NAs
    values_a <- values_a[!is.na(values_a)]
    values_b <- values_b[!is.na(values_b)]

    if (length(values_a) == 0 || length(values_b) == 0) {
      return(data.frame(
        metric = metric_name,
        mean_a = NA,
        mean_b = NA,
        difference = NA,
        p_value = NA,
        test_type = test_type,
        stringsAsFactors = FALSE
      ))
    }

    # Calculate descriptive statistics
    mean_a <- mean(values_a)
    mean_b <- mean(values_b)
    diff <- mean_a - mean_b

    # Perform statistical test
    test_result <- tryCatch({
      if (test_type == "t.test") {
        t.test(values_a, values_b)
      } else {
        wilcox.test(values_a, values_b)
      }
    }, error = function(e) {
      list(p.value = NA)
    })

    data.frame(
      metric = metric_name,
      mean_a = mean_a,
      mean_b = mean_b,
      difference = diff,
      p_value = test_result$p.value,
      test_type = test_type,
      stringsAsFactors = FALSE
    )
  })

  # Combine results
  results <- do.call(rbind, results_list)

  # Add subject IDs
  results$subject_a <- subject_id_a
  results$subject_b <- subject_id_b

  # Reorder columns
  results <- results[, c("metric", "subject_a", "mean_a", "subject_b",
                        "mean_b", "difference", "p_value", "test_type")]

  return(results)
}


#' Compare metrics between two groups
#'
#' Performs statistical comparison between groups with effect size calculation
#'
#' @param group_a_data List of metric data frames for group A subjects
#' @param group_b_data List of metric data frames for group B subjects
#' @param group_a_name Name for group A (default: "Group_A")
#' @param group_b_name Name for group B (default: "Group_B")
#' @param metrics Character vector of metric names to compare (default: NULL, all numeric)
#' @param test_type Statistical test: "t.test", "wilcox.test", "anova" (default: "t.test")
#' @param correction Multiple comparison correction: "bonferroni", "fdr", "none" (default: "fdr")
#'
#' @return Data frame with comparison results including effect sizes
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Compare two groups
#' group_a_metrics <- list(subject1_metrics, subject2_metrics, subject3_metrics)
#' group_b_metrics <- list(subject4_metrics, subject5_metrics, subject6_metrics)
#'
#' results <- compare_groups(group_a_metrics, group_b_metrics,
#'                          group_a_name = "Control",
#'                          group_b_name = "Treatment")
#' }
compare_groups <- function(group_a_data, group_b_data,
                          group_a_name = "Group_A",
                          group_b_name = "Group_B",
                          metrics = NULL,
                          test_type = "t.test",
                          correction = "fdr") {
  # Validate inputs
  if (!is.list(group_a_data) || !is.list(group_b_data)) {
    stop("group_a_data and group_b_data must be lists of data frames")
  }

  if (length(group_a_data) == 0 || length(group_b_data) == 0) {
    stop("Groups must contain at least one subject")
  }

  if (!test_type %in% c("t.test", "wilcox.test", "anova")) {
    stop("test_type must be 't.test', 'wilcox.test', or 'anova'")
  }

  if (!correction %in% c("bonferroni", "fdr", "none")) {
    stop("correction must be 'bonferroni', 'fdr', or 'none'")
  }

  # Determine metrics to compare
  if (is.null(metrics)) {
    # Get common metrics across all subjects
    all_names <- unique(c(
      unlist(lapply(group_a_data, names)),
      unlist(lapply(group_b_data, names))
    ))

    # Keep only numeric metrics that exist in all data frames
    metrics <- all_names[sapply(all_names, function(m) {
      all_have <- all(sapply(c(group_a_data, group_b_data), function(df) m %in% names(df)))
      if (!all_have) return(FALSE)

      # Check if numeric in all
      all_numeric <- all(sapply(c(group_a_data, group_b_data), function(df) {
        is.numeric(df[[m]])
      }))
      return(all_numeric)
    })]
  }

  if (length(metrics) == 0) {
    stop("No common numeric metrics found")
  }

  # Perform comparisons
  results_list <- lapply(metrics, function(metric_name) {
    # Extract metric values for each group
    values_a <- unlist(lapply(group_a_data, function(df) df[[metric_name]]))
    values_b <- unlist(lapply(group_b_data, function(df) df[[metric_name]]))

    # Remove NAs
    values_a <- values_a[!is.na(values_a)]
    values_b <- values_b[!is.na(values_b)]

    if (length(values_a) == 0 || length(values_b) == 0) {
      return(data.frame(
        metric = metric_name,
        n_a = 0,
        n_b = 0,
        mean_a = NA,
        mean_b = NA,
        sd_a = NA,
        sd_b = NA,
        difference = NA,
        cohens_d = NA,
        p_value = NA,
        test_type = test_type,
        stringsAsFactors = FALSE
      ))
    }

    # Calculate descriptive statistics
    mean_a <- mean(values_a)
    mean_b <- mean(values_b)
    sd_a <- sd(values_a)
    sd_b <- sd(values_b)
    diff <- mean_a - mean_b

    # Calculate Cohen's d
    pooled_sd <- sqrt(((length(values_a) - 1) * sd_a^2 +
                       (length(values_b) - 1) * sd_b^2) /
                      (length(values_a) + length(values_b) - 2))
    cohens_d <- diff / pooled_sd

    # Perform statistical test
    test_result <- tryCatch({
      if (test_type == "t.test") {
        t.test(values_a, values_b)
      } else if (test_type == "wilcox.test") {
        wilcox.test(values_a, values_b)
      } else {
        # ANOVA (combine into one data frame)
        combined <- data.frame(
          value = c(values_a, values_b),
          group = c(rep("A", length(values_a)), rep("B", length(values_b)))
        )
        aov_result <- aov(value ~ group, data = combined)
        summary(aov_result)[[1]][1, "Pr(>F)"]
        list(p.value = summary(aov_result)[[1]][1, "Pr(>F)"])
      }
    }, error = function(e) {
      list(p.value = NA)
    })

    data.frame(
      metric = metric_name,
      n_a = length(values_a),
      n_b = length(values_b),
      mean_a = mean_a,
      mean_b = mean_b,
      sd_a = sd_a,
      sd_b = sd_b,
      difference = diff,
      cohens_d = cohens_d,
      p_value = test_result$p.value,
      test_type = test_type,
      stringsAsFactors = FALSE
    )
  })

  # Combine results
  results <- do.call(rbind, results_list)

  # Apply multiple comparison correction
  if (correction != "none" && !all(is.na(results$p_value))) {
    if (correction == "bonferroni") {
      results$p_adjusted <- p.adjust(results$p_value, method = "bonferroni")
    } else if (correction == "fdr") {
      results$p_adjusted <- p.adjust(results$p_value, method = "fdr")
    }
  } else {
    results$p_adjusted <- results$p_value
  }

  # Add significance indicators
  results$significant <- ifelse(is.na(results$p_adjusted), "",
                               ifelse(results$p_adjusted < 0.001, "***",
                               ifelse(results$p_adjusted < 0.01, "**",
                               ifelse(results$p_adjusted < 0.05, "*", ""))))

  # Add group names
  results$group_a <- group_a_name
  results$group_b <- group_b_name

  # Reorder columns
  results <- results[, c("metric", "group_a", "n_a", "mean_a", "sd_a",
                        "group_b", "n_b", "mean_b", "sd_b",
                        "difference", "cohens_d", "p_value", "p_adjusted",
                        "significant", "test_type")]

  return(results)
}


#' Calculate effect size (Cohen's d)
#'
#' Calculates Cohen's d effect size between two groups
#'
#' @param values_a Numeric vector for group A
#' @param values_b Numeric vector for group B
#' @param pooled Logical, use pooled SD (default: TRUE)
#'
#' @return Cohen's d value
#'
#' @export
calculate_cohens_d <- function(values_a, values_b, pooled = TRUE) {
  # Remove NAs
  values_a <- values_a[!is.na(values_a)]
  values_b <- values_b[!is.na(values_b)]

  if (length(values_a) == 0 || length(values_b) == 0) {
    return(NA)
  }

  mean_diff <- mean(values_a) - mean(values_b)

  if (pooled) {
    # Pooled standard deviation
    sd_a <- sd(values_a)
    sd_b <- sd(values_b)
    n_a <- length(values_a)
    n_b <- length(values_b)

    pooled_sd <- sqrt(((n_a - 1) * sd_a^2 + (n_b - 1) * sd_b^2) / (n_a + n_b - 2))
    return(mean_diff / pooled_sd)
  } else {
    # Use control group SD
    return(mean_diff / sd(values_b))
  }
}


#' Extract metrics from tracking data
#'
#' Helper function to extract all available metrics from tracking data
#'
#' @param tracking_data tracking_data object
#' @param arena_config arena_config object (optional, for zone-based metrics)
#' @param body_part Body part to analyze (default: "mouse_center")
#' @param scale_factor Scale factor for distance/velocity (default: NULL)
#'
#' @return Data frame with all calculated metrics
#'
#' @export
extract_all_metrics <- function(tracking_data, arena_config = NULL,
                                body_part = "mouse_center",
                                scale_factor = NULL) {
  metrics <- list()

  # Basic movement metrics
  tryCatch({
    metrics$total_distance <- calculate_distance_traveled(tracking_data, body_part, scale_factor)
  }, error = function(e) {
    metrics$total_distance <<- NA
  })

  # Movement summary
  tryCatch({
    summary <- calculate_movement_summary(tracking_data, body_part, scale_factor)
    metrics$mean_velocity <<- summary$mean_velocity
    metrics$median_velocity <<- summary$median_velocity
    metrics$max_velocity <<- summary$max_velocity
    metrics$percent_time_moving <<- summary$percent_time_moving
    metrics$duration_seconds <<- summary$duration_seconds
  }, error = function(e) {
    # Add NAs for missing values
  })

  # Zone-based metrics (if arena provided)
  if (!is.null(arena_config)) {
    tryCatch({
      occupancy <- calculate_zone_occupancy(tracking_data, arena_config, body_part)
      for (i in seq_len(nrow(occupancy))) {
        zone_id <- occupancy$zone_id[i]
        metrics[[paste0("zone_", zone_id, "_time")]] <<- occupancy$time_in_zone[i]
        metrics[[paste0("zone_", zone_id, "_pct")]] <<- occupancy$percentage[i]
      }
    }, error = function(e) {
      # Skip zone metrics if error
    })

    tryCatch({
      entries <- calculate_zone_entries(tracking_data, arena_config, body_part)
      for (i in seq_len(nrow(entries))) {
        zone_id <- entries$zone_id[i]
        metrics[[paste0("zone_", zone_id, "_entries")]] <<- entries$n_entries[i]
      }
    }, error = function(e) {
      # Skip
    })

    tryCatch({
      latency <- calculate_zone_latency(tracking_data, arena_config, body_part)
      for (i in seq_len(nrow(latency))) {
        zone_id <- latency$zone_id[i]
        metrics[[paste0("zone_", zone_id, "_latency")]] <<- latency$latency[i]
      }
    }, error = function(e) {
      # Skip
    })
  }

  # Convert to data frame
  metrics_df <- as.data.frame(metrics, stringsAsFactors = FALSE)
  return(metrics_df)
}
