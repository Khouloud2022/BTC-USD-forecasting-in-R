# -------------------------------------------------------------------------
# SCRIPT 03: MODELING 
# -------------------------------------------------------------------------
# This script loads the processed data, splits it into training and
# test sets, trains all models, and saves the models and their
# forecasts to the 'output/' folder.
# -------------------------------------------------------------------------

# 1. LOAD LIBRARIES -------------------------------------------------------
library(tidyverse)
library(here)
library(forecast)    # For ARIMAX
library(prophet)     # For Prophet
library(rugarch)     # For GARCH
library(vars)        # For VAR
library(xgboost)     # For XGBoost
library(caret)       # For preprocessing (scaling)


# 2. LOAD PROCESSED DATA --------------------------------------------------
btc_features <- readRDS(here::here("data", "processed", "btc_features.rds"))

print("Loaded processed data with features.")


# 3. SPLIT DATA INTO TRAIN & TEST -----------------------------------------
# We'll use 80% of the data for training.
# IMPORTANT: Do NOT shuffle time series data.
split_point <- floor(0.8 * nrow(btc_features))
train_data <- btc_features[1:split_point, ]
test_data  <- btc_features[(split_point + 1):nrow(btc_features), ]

# How many steps do we need to forecast?
h <- nrow(test_data)

print(paste("Data split into", nrow(train_data), "train and", h, "test samples."))


# 4. PREPARE EXOGENOUS REGRESSORS (Xreg) ----------------------------------
# These are the features for ARIMAX and XGBoost
# Note: For a real forecast, you'd have to forecast these features too.
# For this project, we assume we have the 'future' xreg values.
train_xreg <- train_data %>%
  dplyr::select(rsi_14, sma_20, sma_50, macd, macd_signal, volume) %>%
  as.matrix()

test_xreg <- test_data %>%
  dplyr::select(rsi_14, sma_20, sma_50, macd, macd_signal, volume) %>%
  as.matrix()


# =========================================================================
# MODEL 1: ARIMAX (auto.arima)
# =========================================================================
print("Starting Model 1: ARIMAX...")

# Train the model
# We model the 'close' price using our xreg features
arimax_fit <- auto.arima(
  train_data$close,
  xreg = train_xreg,
  stepwise = TRUE,       # Use stepwise selection for speed
  approximation = FALSE, # More accurate
  trace = TRUE           # Show progress
)

# Forecast
arimax_forecast <- forecast(arimax_fit, xreg = test_xreg, h = h)

# Save the model and forecast
saveRDS(arimax_fit, here::here("output", "models", "arimax_fit.rds"))
saveRDS(arimax_forecast, here::here("output", "models", "arimax_forecast.rds"))

print("ARIMAX model trained and saved.")

saveRDS(arimax_forecast, here::here("output", "models", "arimax_forecast.rds"))
saveRDS(as.vector(residuals(arimax_fit)), here::here("output", "models", "arimax_residuals.rds"))
print("ARIMAX model and residuals trained and saved.")
saveRDS(as.vector(arimax_forecast$mean), here::here("output", "models", "arimax_test_forecast.rds"))
# =========================================================================
# MODEL 2: PROPHET
# =========================================================================
print("Starting Model 2: Prophet...")

# 1. Format data for Prophet (ds, y)
prophet_train_df <- train_data %>%
  dplyr::select(date, close, rsi_14, sma_20, sma_50, volume) %>%
  dplyr::rename(ds = date, y = close)

# 2. Initialize model and add regressors
m_prophet <- prophet() %>%
  add_regressor('rsi_14') %>%
  add_regressor('sma_20') %>%
  add_regressor('sma_50') %>%
  add_regressor('volume')

# 3. Fit the model
prophet_fit <- fit.prophet(m_prophet, prophet_train_df)

# 4. Create "future" dataframe for prediction
# This must include the dates and regressor values for the test period
future_df <- test_data %>%
  dplyr::select(date, rsi_14, sma_20, sma_50, volume) %>%
  dplyr::rename(ds = date)

# 5. Predict
prophet_forecast_df <- predict(prophet_fit, future_df)

# Save the model and forecast
saveRDS(prophet_fit, here::here("output", "models", "prophet_fit.rds"))
saveRDS(prophet_forecast_df, here::here("output", "models", "prophet_forecast.rds"))

print("Prophet model trained and saved.")


# =========================================================================
# MODEL 3: VAR (Vector Autoregression)
# =========================================================================
print("Starting Model 3: VAR...")

# VAR models interdependencies. We'll model log_returns and volume.
# VAR works best on stationary data.
var_data <- train_data %>%
  dplyr::select(log_returns, volume) %>%
  na.omit()

# Find the best lag order (p)
var_select <- VARselect(var_data, lag.max = 10)
p <- var_select$selection["AIC(n)"] # Select lag based on AIC

# Fit the VAR model
var_fit <- VAR(var_data, p = p, type = "const")

# Forecast
var_forecast <- predict(var_fit, n.ahead = h)

# Save the model and forecast
saveRDS(var_fit, here::here("output", "models", "var_fit.rds"))
saveRDS(var_forecast, here::here("output", "models", "var_forecast.rds"))

print("VAR model trained and saved.")


# =========================================================================
# MODEL 4: GARCH (Volatility Model)
# =========================================================================
print("Starting Model 4: GARCH...")

# GARCH models volatility (risk), not price. We model the log_returns.
# 1. Specify a GARCH(1,1) model (most common)
garch_spec <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(1, 1)),
  distribution.model = "std" # Student-t distribution for fat tails
)

# 2. Fit the model
garch_fit <- ugarchfit(spec = garch_spec, data = train_data$log_returns)

# 3. Forecast the volatility (sigma)
garch_forecast <- ugarchforecast(garch_fit, n.ahead = h)

# Save the model and forecast
saveRDS(garch_fit, here::here("output", "models", "garch_fit.rds"))
saveRDS(garch_forecast, here::here("output", "models", "garch_forecast.rds"))

print("GARCH model trained and saved.")


# =========================================================================
# MODEL 5: XGBOOST (Machine Learning)
# =========================================================================
print("Starting Model 5: XGBoost...")

# 1. Get GARCH volatility to use as a feature
# We get the fitted volatility for the train set
train_vol <- as.vector(sigma(garch_fit))
# We get the forecasted volatility for the test set
test_vol <- as.vector(sigma(garch_forecast))

# 2. Create final train/test matrices
# We add the new 'volatility' feature
xgb_train_x <- train_xreg %>%
  as_tibble() %>%
  mutate(volatility = train_vol) %>%
  as.matrix()

xgb_test_x <- test_xreg %>%
  as_tibble() %>%
  mutate(volatility = test_vol) %>%
  as.matrix()

# Our target variable (y)
xgb_train_y <- train_data$close

# 3. Format data for xgboost
dtrain <- xgb.DMatrix(data = xgb_train_x, label = xgb_train_y)
dtest <- xgb.DMatrix(data = xgb_test_x)

# 4. Set parameters and train
params <- list(
  objective = "reg:squarederror",
  eta = 0.05,       # learning rate
  max_depth = 5,
  nrounds = 100
)

xgb_fit <- xgb.train(
  params = params,
  data = dtrain,
  nrounds = params$nrounds,
  verbose = 0
)

# 5. Predict
xgb_forecast_values <- predict(xgb_fit, dtest)

# Save the model and forecast
xgb.save(xgb_fit, here::here("output", "models", "xgb_fit.model"))
saveRDS(xgb_forecast_values, here::here("output", "models", "xgb_forecast.rds"))

print("XGBoost model trained and saved.")
print("--- ALL MODELING COMPLETE ---")