library(hts)
library(forecast)
library(tidyverse)
library(parallel)

train <- read_csv("data/weather-time/train.csv")
all_locations <- unique(train$city_of_incident)
create_ts <- function(location, train) {
  
  location_only <- train %>%
    filter(city_of_incident == {{location}}) 
  
  ts(data = location_only$count, start = c(2011, 1), frequency = 365.25/7)
  
}

# Convert the data all into a time series object

all_series <- map(all_locations, .f = function(x) create_ts(x, train = train)) %>%
  set_names(all_locations) 

combinations_of_vars <- list(
  c("mean_temp", "total_precip"),
  c("mean_temp", "total_rain", "total_snow"),
  c("min_temp", "total_precip"),
  c("min_temp", "max_temp", "total_precip"),
  c("mean_temp", "min_temp", "max_temp", "total_precip"),
  c("mean_temp", "min_temp", "max_temp", "total_snow", "total_rain"),
  c("All")
)

fit_arima <- function(location, all_series, possible_vars) {
  
  aicc <- numeric(length(possible_vars))
  
  for (i in seq_along(possible_vars)) {
  
    if (possible_vars[[i]] == "All") {
      arima_temp <- auto.arima(y = all_series[[location]])
    } else {
      xreg <- train %>%
        filter(city_of_incident == {{location}}) %>%
        select(all_of(possible_vars[[i]])) %>%
        data.matrix(.)
      
      arima_temp <- auto.arima(y = all_series[[location]], xreg = xreg)
    }
    aicc[i] <- arima_temp$aicc
  }
  
  tibble(
    variable = unlist(map(.x = possible_vars, function(x) paste(x, collapse = "|"))),
    aicc = aicc
  )
  
}

all_results <- mclapply(
  X = all_locations,
  FUN = fit_arima,
  all_series = all_series,
  possible_vars = combinations_of_vars,
  mc.cores = 4
)