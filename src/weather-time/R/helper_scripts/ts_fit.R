library(tscount)
library(tidyverse)

fit_ts <- function(location, predictor_combination, p, seas, train = train, return_model = FALSE) {
  
  system(paste("echo 'Model row processing:", location, predictor_combination, p, seas, "'"))
  
  if (location == "All") {
    location_only <- train %>%
      group_by(year_week) %>%
      summarize(count = sum(count))
  } else {
    location_only <- train %>%
      filter(city_of_incident == {{location}})
  }
  location_ts <- ts(location_only$count, start = c(2011, 1), frequency = 365.25/7)
  
  if (any(predictor_combination == "All")) {
    
    weather_reg <- location_only %>%
      .[, 4:ncol(train)] 
    
    if (seas != 0) {
      
      fourier_terms  <- as_tibble(fourier(x = location_ts, K = seas))
      xreg <- bind_cols(weather_reg, fourier_terms) %>%
        as.matrix.data.frame()
      
    } else {
      
      xreg <- weather_reg %>%
        as.matrix.data.frame()
    }
    
  } else if (any(predictor_combination == "None")) {
    
    if (seas != 0) {
      
      fourier_terms  <- as_tibble(fourier(x = location_ts, K = seas))
      xreg <- fourier_terms %>%
        as.matrix.data.frame()
      
    } else {
      
      xreg <-  NULL
      
    }
    
  } else {
    
    weather_reg <- location_only %>%
      select(all_of(predictor_combination))
    
    if (seas != 0) {
      
      fourier_terms  <- as_tibble(fourier(x = location_ts, K = seas))
      xreg <- bind_cols(weather_reg, fourier_terms) %>%
        as.matrix.data.frame()
      
    } else {
      
      xreg <- weather_reg %>%
        as.matrix.data.frame()
    }
    
  }
  
  if (return_model == TRUE) {
  
  model <- tsglm(
    ts = location_ts, 
    model = list(past_obs = 1:p, past_mean = 52, external = TRUE),
    xreg = xreg, 
    link = "log",
    distr = "poisson"
  )
  
  } else {
  
  m <- length(model$coefficients)
  AIC(model) + (2 * m + 2 * m^2) / (nrow(train) - m - 1)
  
  }
}