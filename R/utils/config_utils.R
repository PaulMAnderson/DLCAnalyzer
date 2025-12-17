#' Configuration Utilities for DLCAnalyzer
#'
#' Functions to read, validate, and merge YAML configuration files.
#'
#' @name config_utils
NULL

#' Read a YAML configuration file
#'
#' Loads a YAML configuration file and returns it as a list. The yaml package
#' must be installed to use this function.
#'
#' @param config_file Character. Path to YAML configuration file
#'
#' @return List containing configuration parameters
#'
#' @examples
#' \dontrun{
#' config <- read_config("config/arena_definitions/open_field_template.yml")
#' }
#'
#' @export
read_config <- function(config_file) {
  # Check if yaml package is available
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required for configuration files.\n",
         "Please install it with: install.packages('yaml')",
         call. = FALSE)
  }

  # Validate file exists
  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file,
         "\nPlease check the file path and try again.", call. = FALSE)
  }

  # Try to read the YAML file
  tryCatch({
    config <- yaml::yaml.load_file(config_file)
    return(config)
  }, error = function(e) {
    stop("Failed to read configuration file: ", config_file,
         "\nError: ", conditionMessage(e),
         "\nPlease ensure the file is valid YAML format.",
         call. = FALSE)
  })
}

#' Merge multiple configuration lists
#'
#' Merges configuration lists with later configs overriding earlier ones.
#' This implements the configuration cascade: system defaults < template < user config < function args.
#'
#' @param ... Configuration lists to merge (in order of priority, lowest to highest)
#'
#' @return Merged configuration list
#'
#' @examples
#' \dontrun{
#' system_defaults <- list(fps = 30, units = "pixels")
#' user_config <- list(fps = 25, subject_id = "mouse_01")
#' final_config <- merge_configs(system_defaults, user_config)
#' # Result: list(fps = 25, units = "pixels", subject_id = "mouse_01")
#' }
#'
#' @export
merge_configs <- function(...) {
  configs <- list(...)

  # Remove NULL configs
  configs <- configs[!sapply(configs, is.null)]

  if (length(configs) == 0) {
    return(list())
  }

  if (length(configs) == 1) {
    return(configs[[1]])
  }

  # Merge recursively
  result <- configs[[1]]

  for (i in 2:length(configs)) {
    result <- merge_two_configs(result, configs[[i]])
  }

  return(result)
}

#' Merge two configuration lists
#'
#' Helper function to recursively merge two configuration lists.
#'
#' @param config1 First configuration list (lower priority)
#' @param config2 Second configuration list (higher priority)
#'
#' @return Merged configuration list
#'
#' @keywords internal
merge_two_configs <- function(config1, config2) {
  if (!is.list(config1) || !is.list(config2)) {
    # If either is not a list, config2 wins
    return(config2)
  }

  # Start with config1
  result <- config1

  # Add or override with config2 values
  for (name in names(config2)) {
    if (name %in% names(config1) && is.list(config1[[name]]) && is.list(config2[[name]])) {
      # Both are lists, merge recursively
      result[[name]] <- merge_two_configs(config1[[name]], config2[[name]])
    } else {
      # Override with config2 value
      result[[name]] <- config2[[name]]
    }
  }

  return(result)
}

#' Get a configuration value by path
#'
#' Retrieves a configuration value using a path string (e.g., "arena.dimensions.width").
#' Returns a default value if the path doesn't exist.
#'
#' @param config List. Configuration object
#' @param path Character. Path to the value, using dots as separators
#' @param default Default value to return if path not found
#'
#' @return The configuration value, or default if not found
#'
#' @examples
#' \dontrun{
#' config <- list(arena = list(dimensions = list(width = 500)))
#' width <- get_config_value(config, "arena.dimensions.width", default = 600)
#' # Returns: 500
#'
#' height <- get_config_value(config, "arena.dimensions.height", default = 600)
#' # Returns: 600 (not found, uses default)
#' }
#'
#' @export
get_config_value <- function(config, path, default = NULL) {
  if (!is.list(config)) {
    return(default)
  }

  # Split path by dots
  keys <- strsplit(path, "\\.")[[1]]

  # Navigate through the config
  current <- config

  for (key in keys) {
    if (is.list(current) && key %in% names(current)) {
      current <- current[[key]]
    } else {
      # Path not found, return default
      return(default)
    }
  }

  return(current)
}

#' Set a configuration value by path
#'
#' Sets a configuration value using a path string (e.g., "arena.dimensions.width").
#' Creates intermediate lists as needed.
#'
#' @param config List. Configuration object
#' @param path Character. Path to the value, using dots as separators
#' @param value Value to set
#'
#' @return Modified configuration list
#'
#' @examples
#' \dontrun{
#' config <- list()
#' config <- set_config_value(config, "arena.dimensions.width", 500)
#' # Result: list(arena = list(dimensions = list(width = 500)))
#' }
#'
#' @export
set_config_value <- function(config, path, value) {
  if (!is.list(config)) {
    config <- list()
  }

  # Split path by dots
  keys <- strsplit(path, "\\.")[[1]]

  if (length(keys) == 1) {
    # Simple assignment
    config[[keys[1]]] <- value
    return(config)
  }

  # Navigate to the parent of the target
  current <- config

  for (i in 1:(length(keys) - 1)) {
    key <- keys[i]

    if (!(key %in% names(current))) {
      current[[key]] <- list()
    }

    # Create reference for next iteration
    if (i == 1) {
      config[[key]] <- current[[key]]
    }

    current <- current[[key]]
  }

  # Set the final value
  final_key <- keys[length(keys)]
  current[[final_key]] <- value

  # Rebuild the config structure
  for (i in (length(keys) - 1):1) {
    parent_keys <- keys[1:i]
    child_key <- keys[i + 1]

    # Navigate to parent
    parent <- config
    for (pk in parent_keys[-length(parent_keys)]) {
      parent <- parent[[pk]]
    }

    parent[[keys[i]]][[child_key]] <- current[[child_key]]

    if (i == 1) {
      config[[keys[1]]] <- parent[[keys[1]]]
    }

    current <- parent
  }

  return(config)
}

#' Load configuration with defaults
#'
#' Loads a user configuration file and merges it with system defaults.
#'
#' @param config_file Character. Path to user configuration file (can be NULL)
#' @param defaults List. Default configuration values
#'
#' @return Merged configuration list
#'
#' @examples
#' \dontrun{
#' defaults <- list(fps = 30, likelihood_threshold = 0.9)
#' config <- load_config_with_defaults("my_config.yml", defaults)
#' }
#'
#' @export
load_config_with_defaults <- function(config_file = NULL, defaults = list()) {
  if (is.null(config_file)) {
    return(defaults)
  }

  user_config <- read_config(config_file)
  merged <- merge_configs(defaults, user_config)

  return(merged)
}

#' Write configuration to YAML file
#'
#' Saves a configuration list to a YAML file.
#'
#' @param config List. Configuration to save
#' @param output_file Character. Path to output YAML file
#' @param ... Additional arguments passed to yaml::write_yaml
#'
#' @return Invisible NULL
#'
#' @examples
#' \dontrun{
#' config <- list(fps = 30, subject_id = "mouse_01")
#' write_config(config, "output_config.yml")
#' }
#'
#' @export
write_config <- function(config, output_file, ...) {
  # Check if yaml package is available
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to write configuration files.\n",
         "Please install it with: install.packages('yaml')",
         call. = FALSE)
  }

  tryCatch({
    yaml::write_yaml(config, output_file, ...)
    message("Configuration saved to: ", output_file)
    invisible(NULL)
  }, error = function(e) {
    stop("Failed to write configuration file: ", output_file,
         "\nError: ", conditionMessage(e),
         call. = FALSE)
  })
}

#' Get default preprocessing configuration
#'
#' Returns the system default preprocessing configuration.
#'
#' @return List with default preprocessing parameters
#'
#' @examples
#' \dontrun{
#' defaults <- get_default_preprocessing_config()
#' }
#'
#' @export
get_default_preprocessing_config <- function() {
  list(
    likelihood_threshold = list(
      enabled = TRUE,
      threshold = 0.9,
      method = "hard"
    ),
    interpolation = list(
      enabled = TRUE,
      method = "linear",
      max_gap = 5
    ),
    smoothing = list(
      enabled = TRUE,
      method = "savitzky_golay",
      window_length = 11,
      polyorder = 3
    ),
    outlier_detection = list(
      enabled = TRUE,
      method = "displacement",
      threshold = 100
    )
  )
}

#' Get default arena configuration for a paradigm
#'
#' Returns the system default arena configuration for a specific paradigm.
#'
#' @param paradigm Character. Paradigm name ("open_field", "epm", "nor", "ldb")
#'
#' @return List with default arena configuration
#'
#' @examples
#' \dontrun{
#' defaults <- get_default_arena_config("open_field")
#' }
#'
#' @export
get_default_arena_config <- function(paradigm = "open_field") {
  switch(paradigm,
    open_field = list(
      paradigm = "open_field",
      dimensions = list(width = 500, height = 500, units = "pixels"),
      zones = list(
        center = list(
          type = "rectangle",
          definition = list(
            method = "proportion",
            x_min = 0.25,
            x_max = 0.75,
            y_min = 0.25,
            y_max = 0.75
          )
        )
      )
    ),
    epm = ,
    elevated_plus_maze = list(
      paradigm = "elevated_plus_maze",
      dimensions = list(width = 800, height = 800, units = "pixels"),
      zones = list()
    ),
    nor = ,
    novel_object = list(
      paradigm = "novel_object_recognition",
      dimensions = list(width = 500, height = 500, units = "pixels"),
      zones = list()
    ),
    ldb = ,
    light_dark = list(
      paradigm = "light_dark_box",
      dimensions = list(width = 600, height = 300, units = "pixels"),
      zones = list()
    ),
    # Default: generic arena
    list(
      paradigm = paradigm,
      dimensions = list(width = 500, height = 500, units = "pixels"),
      zones = list()
    )
  )
}
