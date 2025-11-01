# -------------------------------------------------------------------------
# SCRIPT 02: FEATURE ENGINEERING
# -------------------------------------------------------------------------
# This script loads the raw data, creates all technical indicators
# and features, and saves the final, clean data set to the
# 'data/processed' folder.
# -------------------------------------------------------------------------

# 1. LOAD LIBRARIES -------------------------------------------------------
library(tidyverse) # For data manipulation (mutate, lag, etc.)
library(TTR)       # For technical indicators (SMA, RSI, MACD)
library(here)      # For robust file paths


# 2. LOAD RAW DATA --------------------------------------------------------
# Load the 'btc_raw.rds' file we created in the last script
btc_raw <- readRDS(here::here("data", "raw", "btc_raw.rds"))

print("Raw data loaded.")


# 3. CREATE TECHNICAL INDICATORS & FEATURES -------------------------------

# Calculate MACD. It returns a data.frame, so we handle it separately.
# We use the 'close' price
macd_data <- TTR::MACD(btc_raw$close) %>%
  as_tibble() %>%
  # Rename columns to be clear
  rename(macd = macd, macd_signal = signal)


# Create all other features using mutate
btc_features <- btc_raw %>%
  mutate(
    # Create log returns (helps with stationarity)
    log_returns = log(close / lag(close)),
    
    # Create Relative Strength Index (RSI)
    rsi_14 = TTR::RSI(close, n = 14),
    
    # Create Simple Moving Averages (SMA)
    sma_20 = TTR::SMA(close, n = 20), # 20-day
    sma_50 = TTR::SMA(close, n = 50)  # 50-day
  ) %>%
  # Add the MACD columns we created
  bind_cols(macd_data) %>%
  
  # CRITICAL: Remove NA values
  # The lag() and TTR functions create NAs at the start of the series.
  # We must remove them before modeling.
  na.omit()


# 4. CHECK AND SAVE PROCESSED DATA ----------------------------------------

# Check the final data
print("Feature engineering complete. Final data structure:")
print(head(btc_features))
print(tail(btc_features))

# Define the save path
save_path <- here::here("data", "processed", "btc_features.rds")

# Save the final, featured data set
saveRDS(btc_features, file = save_path)

print(paste("Processed data with features saved to:", save_path))
