# BTC-USD Price & Volatility Forecasting in R

![Project Status: Active](https://img.shields.io/badge/status-active-brightgreen?style=for-the-badge)
![Language: R](https://img.shields.io/badge/R-4.4.1-276DC3?style=for-the-badge&logo=r)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

A comprehensive analysis and comparison of classical, machine learning, and deep learning models for forecasting the price and volatility of BTC-USD.

This project uses a reproducible workflow with `renv` and is structured to compare the performance of various models, from traditional ARIMA and GARCH to modern approaches like Prophet and LSTM.

## 📚 Table of Contents
* [Project Goal](#-project-goal)
* [Models Implemented](#-models-implemented)
* [Project Structure](#-project-structure)
* [Installation & Usage](#-installation--usage)
* [Results](#-results)
* [Core Reference](#-core-reference)
* [License](#-license)

## 🎯 Project Goal

The primary goal of this project is to identify the most effective model for forecasting the daily closing price of BTC-USD. A secondary goal is to model the asset's volatility (risk) using a GARCH model.

Models are benchmarked against each other based on standard performance metrics (RMSE, MAE) to determine the best-fit model for such a historically volatile asset.

## 🤖 Models Implemented

This project compares a wide range of time series models:

1.  **Classical & Econometric:**
    * **ARIMAX/Dynamic Regression:** ARIMA with exogenous (external) regressors.
    * **VAR:** Vector Autoregression to model multiple variables (e.g., price and volume) simultaneously.
    * **GARCH(1,1):** Used specifically to model and forecast volatility (risk), not price.
2.  **Automated:**
    * **Prophet:** Facebook's automated forecasting tool, adept at handling seasonality and holidays.
3.  **Machine Learning:**
    * **XGBoost:** A powerful gradient-boosting model using technical indicators and GARCH volatility as features.
4.  **Deep Learning:**
    * **LSTM:** Long Short-Term Memory, a recurrent neural network (RNN) designed to handle long-term dependencies in sequential data.
    * **Hybrid (ARIMA-LSTM):** [*Optional, if you build it*] A model that combines ARIMA's linear modeling with LSTM's ability to model non-linear errors.

## 📂 Project Structure

The repository is organized to ensure reproducibility and a clear separation of concerns:
```
/BTC-Forecasting-Project
|
|--- 📂 data/
|    |--- 📂 raw/
|    |    |--- btc_raw.rds      (Original downloaded data)
|    |--- 📂 processed/
|    |    |--- btc_features.rds (Data with engineered features)
|
|--- 📂 R/
|    |--- utils.R              (Helper functions, e.g., for LSTM data shaping)
|
|--- 📂 scripts/
|    |--- 01_data_acquisition.R   (Downloads and saves raw data)
|    |--- 02_feature_engineering.R(Cleans data, adds indicators)
|    |--- 03_modeling.R           (Trains all models)
|    |--- 04_evaluation.R         (Compares models, generates plots)
|
|--- 📂 output/
|    |--- 📂 plots/
|    |    |--- forecast_comparison.png (Plot of test data vs. predictions)
|    |    |--- volatility_plot.png     (Plot of GARCH volatility forecast)
|    |--- 📂 models/
|    |    |--- arimax_fit.rds          (Saved model objects)
|    |    |--- lstm_model.h5
|
|--- .gitignore
|--- renv.lock
|--- .Rprofile
|--- BTC-Forecasting-Project.Rproj
|--- README.md
```



