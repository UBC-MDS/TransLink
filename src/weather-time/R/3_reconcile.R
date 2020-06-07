library(hts)
library(tidyverse)
library(tscount)

source("src/weather-time/R/helper_scripts/ts_fit.R")

results <- readRDS("results/weather-time/all_results.rds")
train <- read_csv("data/weather-time/train.csv")

best_models <- results %>%
  mutate(data = map(data, function(x) x %>% arrange(AICc) %>% .[1, ])) %>%
  unnest(cols = c(data))

final_models <- pmap(.l = list(
  location = best_models$location,
  predictor_combination = best_models$combn,
  p = best_models$order,
  seas = best_models$seasonal
  ), .f = ~fit_ts(..1, ..2, ..3, ..4, train = train, return_model = TRUE)) %>%
  set_names(best_models$location)

residuals <- as.matrix.data.frame(bind_cols(Total = final_agg_model$residuals, map(final_models, function(x) x$residuals)))
forecasts <- as.matrix.data.frame(bind_cols(Total = predict(final_agg_model, n.ahead = 3)$pred, map(final_models, function(x) predict(x, n.ahead = 3)$pred)))

stuff <- train %>%
  select(year_week, city_of_incident, count) %>%
  spread(key = city_of_incident, value = count) %>%
  select(-year_week) %>%
  as.matrix.data.frame()

my_hts <- hts(stuff)
all_y <- aggts(my_hts)
cool <- MinT(fcasts = ts(forecasts), nodes = my_hts$nodes,  residual = ts(residuals))