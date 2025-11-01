# -------------------------------------------------------------------------
# SCRIPT 01: DATA ACQUISITION
# -------------------------------------------------------------------------
# This script downloads the daily BTC-USD data and saves the raw,
# untouched version to the 'data/raw' folder.
# -------------------------------------------------------------------------

# 1. LOAD LIBRARIES -------------------------------------------------------
# We only load the libraries needed for this specific script
library(quantmod)
library(tidyquant)
library(tidyverse)
library(here) # For building file paths


# 2. DOWNLOAD DATA --------------------------------------------------------
# Use quantmod's getSymbols to download BTC-USD data from Yahoo Finance
# We'll get all available data from 2018-01-01 to today
btc_symbol <- "BTC-USD"
start_date <- "2018-01-01"

# Download the data. 'auto.assign = FALSE' returns it as an xts object
btc_xts <- getSymbols(btc_symbol,
                      src = "yahoo",
                      from = start_date,
                      auto.assign = FALSE)


# 3. CONVERT AND CLEAN ----------------------------------------------------
# Convert the 'xts' object to a modern 'tibble' (data frame)
btc_raw_df <- btc_xts %>%
  as_data_frame(rownames = "date") %>%
  mutate(date = as.Date(date)) %>%
  # Rename columns to be simple and clean
  select(
    date,
    open = contains("Open"),
    high = contains("High"),
    low = contains("Low"),
    close = contains("Close"),
    volume = contains("Volume"),
    adjusted = contains("Adjusted")
  ) %>%
  # Ensure there are no missing values
  na.omit()

# Check the data
print(head(btc_raw_df))
print(tail(btc_raw_df))


# 4. SAVE RAW DATA --------------------------------------------------------
# Save the raw data frame as an .rds file. This is faster and more
# efficient for R than a CSV.
# The 'here::here()' function automatically finds your 'data/raw' folder.

save_path <- here::here("data", "raw", "btc_raw.rds")

saveRDS(btc_raw_df, file = save_path)

print(paste("Raw BTC data saved to:", save_path))
