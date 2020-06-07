library(hts)
library(forecast)
library(tsibble)
library(tscount)
library(tidyverse)
library(parallel)

source("src/weather-time/R/helper_scripts/ts_fit.R")

train <- read_csv("data/weather-time/train.csv")
all_locations <- c("All", unique(train$city_of_incident))

predictor_combinations <- list(
  c("mean_temp", "total_precip"),
  c("mean_temp", "total_snow", "total_rain"),
  c("total_precip"),
  c("max_temp"),
  c("mean_temp"),
  c("min_temp", "total_snow", "total_rain"),
  c("max_temp", "total_precip"),
  c("min_temp", "total_precip"),
  c("max_temp", "total_snow", "total_rain"),
  c("None")
)

p <- 3:8
K <- 0:6

all_combinations <- expand.grid(
  location = all_locations,
  combn = predictor_combinations,
  order = p,
  seasonal = K, 
  stringsAsFactors = FALSE
)

all_results <- mcmapply(
  FUN = fit_ts,
  location = all_combinations$location,
  predictor_combination = all_combinations$combn, 
  p = all_combinations$order, 
  seas = all_combinations$seasonal,
  MoreArgs = list(train = train),
  mc.cores = detectCores() - 2
)

all_combined <- bind_cols(all_combinations, AICc = all_results) %>%
  group_by(location) %>%
  nest() %>%
  mutate(data = map(data, function(x) x %>% mutate(rel_like = exp(-(min(AICc) - AICc) / 2))))


saveRDS(all_combined, "results/weather-time/all_results.rds")

# Forecast the aggregate series 

all_locations <- train %>%
  group_by(year_week) %>%
  summarize(count = sum(count))

agg_ts <- ts(all_locations$count, start = c(2011, 1), frequency = 365.25/7)
all_combinations_agg <- as_tibble(expand.grid(order = p, seasonal = K, stringsAsFactors = FALSE))

fit_agg_ts <- function(x, p, K) {
  
  fourier_terms <- fourier(x = x, K = K)
  
  model <- tsglm(
    ts = x, model = list(past_obs = 1:p, past_mean = 52, external = TRUE),
    xreg = fourier_terms,
    link = "log",
    distr = "poisson"
    )
 
  m <- length(model$coefficients)
  AIC(model) + (2 * m + 2 * m^2) / (nrow(train) - m - 1)
   
}

all_results_agg <- unlist(pmap(
  .l = list(p = all_combinations_agg$order, K = all_combinations_agg$seasonal),
  .f = ~fit_agg_ts(x = agg_ts, p = ..1, K = ..2) 
))

final_agg_model <- tsglm(
  ts = agg_ts, model = list(past_obs = 1:8, past_mean = 52, external = TRUE),
  xreg = fourier(x = agg_ts, K = 6),
  link = "log",
  distr = "poisson"
)