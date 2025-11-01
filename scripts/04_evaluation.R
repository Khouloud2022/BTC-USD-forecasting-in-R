# -------------------------------------------------------------------------
# SCRIPT 04: EVALUATION (Version finale avec graphiques améliorés)
# -------------------------------------------------------------------------
# This script loads all saved forecasts, calculates metrics,
# and saves the final comparison plots (faceted, metrics, residuals).
# -------------------------------------------------------------------------

# 1. LOAD LIBRARIES -------------------------------------------------------
library(tidyverse)
library(here)
library(forecast) # For accuracy()
library(Metrics)  # For rmse() and mae()
library(ggplot2)  # For plotting
library(patchwork)# For combining plots


# 2. LOAD TEST DATA -------------------------------------------------------
btc_features <- readRDS(here::here("data", "processed", "btc_features.rds"))

split_point <- floor(0.8 * nrow(btc_features))
train_data <- btc_features[1:split_point, ]
test_data  <- btc_features[(split_point + 1):nrow(btc_features), ]

# Get the actual closing prices from the test set
actuals <- test_data$close
actual_dates <- test_data$date

print("Test data loaded.")


# 3. LOAD SAVED FORECASTS -------------------------------------------------
# --- Load R model forecasts (.rds) ---
arimax_forecast <- readRDS(here::here("output", "models", "arimax_forecast.rds"))
prophet_forecast <- readRDS(here::here("output", "models", "prophet_forecast.rds"))
xgb_forecast_values <- readRDS(here::here("output", "models", "xgb_forecast.rds"))
garch_forecast <- readRDS(here::here("output", "models", "garch_forecast.rds"))

# --- Load Python model forecasts (.csv) ---
lstm_forecast_df <- read.csv(here::here("output", "models", "lstm_predictions.csv"))
hybrid_forecast_df <- read.csv(here::here("output", "models", "hybrid_predictions.csv"))

# --- Extract and Align Forecast Values ---
arimax_values <- as.vector(arimax_forecast$mean)
prophet_values <- prophet_forecast$yhat

# Align LSTM/Hybrid forecasts (pad with NAs)
len_actuals <- length(actuals)
lstm_values <- c(
  rep(NA, len_actuals - nrow(lstm_forecast_df)), 
  lstm_forecast_df$lstm_pred
)
hybrid_values <- c(
  rep(NA, len_actuals - nrow(hybrid_forecast_df)), 
  hybrid_forecast_df$hybrid_pred
)

print("All model forecasts loaded and aligned.")


# 4. CALCULATE PERFORMANCE METRICS (RMSE & MAE) ---------------------------
# --- Filter NAs *before* calculating ---
idx_lstm <- !is.na(lstm_values) 
idx_hybrid <- !is.na(hybrid_values)

# --- Create the final metrics data frame ---
metrics_df <- data.frame(
  Model = c("ARIMAX", "Prophet", "XGBoost (with GARCH)", "LSTM (Scaled)", "Hybrid (ARIMA-LSTM)"),
  RMSE = c(
    rmse(actuals, arimax_values),
    rmse(actuals, prophet_values),
    rmse(actuals, xgb_forecast_values),
    rmse(actuals[idx_lstm], lstm_values[idx_lstm]),
    rmse(actuals[idx_hybrid], hybrid_values[idx_hybrid])
  ),
  MAE = c(
    mae(actuals, arimax_values),
    mae(actuals, prophet_values),
    mae(actuals, xgb_forecast_values),
    mae(actuals[idx_lstm], lstm_values[idx_lstm]),
    mae(actuals[idx_hybrid], hybrid_values[idx_hybrid])
  )
)

print("--- Model Performance Metrics ---")
print(metrics_df)

# Save the metrics table
saveRDS(metrics_df, here::here("output", "model_metrics.rds"))
write.csv(metrics_df, here::here("output", "model_metrics.csv"), row.names = FALSE)


# 5. CREATE COMPARISON DATAFRAME FOR PLOTTING -----------------------------
plot_df_long <- data.frame(
  Date = actual_dates,
  Actual = actuals,
  ARIMAX = arimax_values,
  Prophet = prophet_values,
  XGBoost = xgb_forecast_values,
  LSTM = lstm_values,
  Hybrid_ARIMA_LSTM = hybrid_values
) %>%
  pivot_longer(cols = -c(Date, Actual), names_to = "Model", values_to = "Price")

print("Plotting dataframe created.")


# 6. PLOT 1: PRICE FORECAST COMPARISON (FACETED) --------------------------
print("Generating Faceted Forecast Plot...")

# We use the 'Actual' column from plot_df_long for the black line
price_plot_faceted <- ggplot(plot_df_long, aes(x = Date)) +
  # Ligne "Actual" en noir (légèrement transparente)
  geom_line(aes(y = Actual), color = "black", alpha = 0.8) +
  # Ligne de prévision du modèle (en couleur)
  geom_line(aes(y = Price, color = Model), linewidth = 0.8) +
  # Crée un mini-graphique pour chaque modèle
  facet_wrap(~ Model, scales = "free_y", ncol = 2) + 
  scale_color_manual(values = c(
    "ARIMAX" = "#0072B2",
    "Prophet" = "#009E73",
    "XGBoost" = "#D55E00",
    "LSTM" = "#CC79A7",
    "Hybrid_ARIMA_LSTM" = "#F0E442"
  )) +
  labs(
    title = "Comparaison des prévisions de modèles (couleur) par rapport au prix réel (noir)",
    subtitle = "Chaque graphique montre un modèle contre la vérité. Notez les échecs de XGBoost et LSTM.",
    x = "Date",
    y = "Prix (USD)"
  ) +
  theme_minimal() +
  theme(legend.position = "none") # Les titres des facettes servent de légende

# Sauvegarder le graphique
ggsave(
  here::here("output", "plots", "price_forecast_faceted.png"),
  price_plot_faceted,
  width = 12, height = 10, dpi = 300
)

print("Faceted price forecast plot saved.")


# 7. PLOT 2: GARCH VOLATILITY FORECAST ------------------------------------
print("Generating GARCH Volatility Plot...")

vol_df <- data.frame(
  Date = actual_dates,
  Actual_Log_Returns = test_data$log_returns,
  Forecasted_Volatility = as.vector(sigma(garch_forecast))
)

vol_plot <- ggplot(vol_df, aes(x = Date)) +
  geom_line(aes(y = Actual_Log_Returns, color = "Actual Log Returns"), alpha = 0.5) +
  geom_line(aes(y = Forecasted_Volatility, color = "Forecasted Volatility (GARCH)"), linewidth = 1) +
  geom_line(aes(y = -Forecasted_Volatility, color = "Forecasted Volatility (GARCH)"), linewidth = 1) +
  scale_color_manual(values = c(
    "Actual Log Returns" = "grey70",
    "Forecasted Volatility (GARCH)" = "firebrick"
  )) +
  labs(
    title = "GARCH(1,1) Volatility Forecast",
    subtitle = "Forecasted volatility (risk) vs. actual log returns",
    x = "Date",
    y = "Log Return / Volatility"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", legend.title = element_blank())

# Save the volatility plot
ggsave(
  here::here("output", "plots", "garch_volatility_forecast.png"),
  vol_plot,
  width = 12, height = 7, dpi = 300
)

print("GARCH volatility plot saved.")


# 8. PLOT 3: METRICS COMPARISON (BAR CHART) -------------------------------
print("Generating Metrics Bar Chart...")

# Nous devons "pivoter" le dataframe des métriques pour ggplot
metrics_plot_df <- metrics_df %>%
  pivot_longer(cols = c("RMSE", "MAE"), names_to = "Metric", values_to = "Value")

metrics_plot <- ggplot(metrics_plot_df, aes(x = reorder(Model, Value), y = Value, fill = Model)) +
  geom_bar(stat = "identity") +
  facet_wrap(~ Metric, scales = "free_y") + # Crée deux graphiques séparés (RMSE, MAE)
  coord_flip() + # Retourne le graphique pour une meilleure lisibilité
  labs(
    title = "Comparaison des performances des modèles",
    subtitle = "Une valeur plus basse est meilleure. XGBoost et LSTM ont des échelles d'erreur beaucoup plus grandes.",
    x = "Modèle",
    y = "Erreur (en USD)"
  ) +
  theme_minimal() +
  theme(legend.position = "none") 

# Sauvegarder le graphique
ggsave(
  here::here("output", "plots", "metrics_comparison_barchart.png"),
  metrics_plot,
  width = 12, height = 7, dpi = 300
)

print("Bar chart of metrics saved.")


# 9. PLOT 4: RESIDUALS OVER TIME (ERRORS) ---------------------------------
print("Generating Residuals Plot...")

# Créer un dataframe des erreurs (Résidus)
residuals_df <- plot_df_long %>%
  mutate(Error = Actual - Price) %>%
  filter(!is.na(Error)) # Enlever les NAs (des LSTMs)

# Créer le graphique
residuals_plot <- ggplot(residuals_df, aes(x = Date, y = Error, color = Model)) +
  geom_line(alpha = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") + # Ligne de base (erreur zéro)
  facet_wrap(~ Model, scales = "free_y", ncol = 2) + # Echelles Y séparées
  labs(
    title = "Résidus (Erreurs) du modèle au fil du temps",
    subtitle = "Un bon modèle doit avoir des erreurs petites et aléatoires centrées sur 0.",
    x = "Date",
    y = "Erreur de prévision (USD)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Sauvegarder le graphique
ggsave(
  here::here("output", "plots", "residuals_over_time.png"),
  residuals_plot,
  width = 12, height = 10, dpi = 300
)

print("Residuals plot saved.")
print("--- ALL EVALUATION COMPLETE ---")