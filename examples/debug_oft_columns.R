# Debug script to inspect OFT file structure
# This helps understand zone columns before implementing oft_load.R

library(readxl)

# Path to OFT test file
oft_file <- "data/OFT/OF 20250929/Raw data-OF RebeccaAndersonWagner-Trial     1 (3).xlsx"

cat("=== Inspecting OFT File ===\n")
cat("File:", oft_file, "\n\n")

# Get sheet names
sheets <- excel_sheets(oft_file)
cat("Sheet names:\n")
print(sheets)
cat("\n")

# Read the first sheet to inspect structure
cat("=== Reading first sheet ===\n")
first_sheet <- sheets[1]
cat("Sheet:", first_sheet, "\n\n")

# Read column names (typically at row 37)
col_names <- read_excel(oft_file, sheet = first_sheet, skip = 36, n_max = 1)
all_cols <- names(col_names)

cat("Total columns:", length(all_cols), "\n\n")

# Find zone columns
zone_cols <- grep("zone", all_cols, ignore.case = TRUE, value = TRUE)
cat("=== Zone Columns Found ===\n")
cat("Total zone columns:", length(zone_cols), "\n")
for (col in zone_cols) {
  cat("  -", col, "\n")
}
cat("\n")

# Find coordinate columns
coord_cols <- grep("^[XY] ", all_cols, ignore.case = FALSE, value = TRUE)
cat("=== Coordinate Columns ===\n")
for (col in coord_cols) {
  cat("  -", col, "\n")
}
cat("\n")

# Find time columns
time_cols <- grep("time", all_cols, ignore.case = TRUE, value = TRUE)
cat("=== Time Columns ===\n")
for (col in time_cols) {
  cat("  -", col, "\n")
}
cat("\n")

# Find distance/velocity columns
dist_vel_cols <- grep("distance|velocity", all_cols, ignore.case = TRUE, value = TRUE)
cat("=== Distance/Velocity Columns ===\n")
for (col in dist_vel_cols) {
  cat("  -", col, "\n")
}
cat("\n")

# Read first few rows of data to see structure
cat("=== First 5 Rows of Data ===\n")
data_sample <- read_excel(oft_file, sheet = first_sheet, skip = 37, n_max = 5)
cat("Columns after R name conversion:\n")
print(head(names(data_sample), 20))
cat("\n")

# Check zone column values
if (length(zone_cols) > 0) {
  cat("=== Sample Zone Values (first zone column) ===\n")
  first_zone <- zone_cols[1]
  # Convert to R name format
  r_name <- make.names(first_zone)
  if (r_name %in% names(data_sample)) {
    cat("Column:", first_zone, "->", r_name, "\n")
    print(table(data_sample[[r_name]], useNA = "ifany"))
  }
}

cat("\n=== Done ===\n")
