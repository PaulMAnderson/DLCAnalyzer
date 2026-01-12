library(readxl)

source("R/common/io.R")

file <- 'data/NORT/NORT 20251003/Raw data-NORT D3 20251003-Trial     1 (1).xlsx'
sheets <- excel_sheets(file)
col_names <- read_excel(file, sheet = sheets[1], skip = 36, n_max = 1)

# Check what zone columns exist
all_cols <- names(col_names)
zone_pattern <- "^In zone\\("
zone_cols <- grep(zone_pattern, all_cols, value = TRUE)
cat('All In zone(...) columns:\n')
print(zone_cols)

cat('\n\nObject-related zones:\n')
print(grep('object', zone_cols, ignore.case = TRUE, value = TRUE))

cat('\n\nNow test identify_zone_columns with paradigm = "nort":\n')
zone_info <- identify_zone_columns(all_cols, paradigm = "nort")
print(zone_info)

cat('\n\nNow test identify_zone_columns with NO paradigm filter:\n')
zone_info_all <- identify_zone_columns(all_cols, paradigm = NULL)
print(zone_info_all[grep('object', zone_info_all$zone_name, ignore.case = TRUE), ])
