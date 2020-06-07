library(tidyverse)
library(lubridate)

source("src/ml-model/R/helper-scripts/build_series.R")

all_data <- readRDS("data/ml-model/final_data.rds") %>%
  mutate(day_of_year = yday(loss_date))

stations_per_loc_hour <- readRDS("data/ml-model/stations_per_loc_hour.rds")
stations_per_loc_day <- readRDS("data/ml-model/stations_per_loc_day.rds")
# Randomly select rows, with replacement, from the entire dataset
set.seed(200350623)
sample_rows <- sample_n(all_data, size = round(nrow(all_data) * 3.3, 0), replace = TRUE)

all_lines <- unique(all_data$line_no)
all_days <- 1:366
all_hours <- 0:23

# For each row, generate a vector indicating what variable to change 
# 1 is line, 2 is hour, 3 is day of year. 
# Sampling scheme taken from this article here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57
# A more rigorous paper that also employs a similar sampling scheme for Montreal:
# https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1

set.seed(200350623)
sample_rows_with_var <- sample_rows %>%
  mutate(var_to_change = sample.int(n = 3, size = nrow(sample_rows), replace = TRUE))

counts <- sample_rows_with_var %>%
  group_by(var_to_change) %>%
  count()

lines <- sample(all_lines, size = counts$n[which(counts$var_to_change == 1)], replace = TRUE)
hours <- sample(all_hours, size = counts$n[which(counts$var_to_change == 2)], replace = TRUE)
days <- sample(all_days, size = counts$n[which(counts$var_to_change == 3)], replace = TRUE)

all_negative_samples <- vector("list", 3)

for (i in 1:3) {

  if (i == 1) {

    all_negative_samples[[1]] <- sample_rows_with_var %>%
      filter(var_to_change == 1) %>%
      mutate(line_no = lines) %>%
      left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
      replace_na(list(check = "no")) %>%
      filter(check == "no") %>%
      mutate(target = rep(0, nrow(.))) %>%
      select(-var_to_change, -check)
    
  } else if (i == 2) {
    
    weather_vars <- c("pressure", "rel_hum", "elev","temp", "visib", "wind_dir", "wind_spd")
    
    temp <- sample_rows_with_var %>%
      filter(var_to_change == 2) %>%
      mutate(hour_of_loss = hours) %>%
      left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
      replace_na(list(check = "no")) %>%
      filter(check == "no") %>%
      mutate(target = rep(0, nrow(.))) %>%
      select(-all_of(weather_vars), -check, -var_to_change)
    
    all_locations <- unique(temp$city_of_incident)
    
    data_with_weather <- map(.x = all_locations, .f = function(x) {
      build_hourly_series(
        location = x,
        variables = weather_vars,
        stations_per_loc = stations_per_loc_hour,
        claims_line_data = temp)})
    
    all_negative_samples[[2]] <- bind_rows(data_with_weather)
    
    rm(data_with_weather, temp)
    gc()
    
  } else {
    
    weather_vars <- c("pressure", "rel_hum", "elev","temp", "visib", "wind_dir", "wind_spd")
    weather_vars_day <- c("total_precip", "total_rain", "total_snow")
    
    temp <- sample_rows_with_var %>%
      filter(var_to_change == 3) %>%
      mutate(day_of_year = days,
             loss_date = as.Date(day_of_year, origin = paste(year(loss_date) - 1, 12, 31, sep = "-"))) %>%
      left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
      replace_na(list(check = "no")) %>%
      filter(check == "no") %>%
      mutate(target = rep(0, nrow(.))) %>%
      select(-all_of(weather_vars), -all_of(weather_vars_day), -check, -var_to_change)
    
    set.seed(200350623)
    all_2020 <- temp %>%
      filter(year(loss_date) == 2020) %>%
      mutate(day_of_year = sample(1:122, size = nrow(.), replace = TRUE),
             loss_date = as.Date(day_of_year, origin = paste(year(loss_date) - 1, 12, 31, sep = "-"))) %>%
      left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
      replace_na(list(check = "no")) %>%
      filter(check == "no") %>%
      mutate(target = rep(0, nrow(.))) %>%
      select(-check)
    
    temp <- temp %>%
      filter(year(loss_date) != 2020) %>%
      bind_rows(., all_2020)
      
    all_locations <- unique(temp$city_of_incident)
    
    data_with_weather <- map(.x = all_locations, .f = function(x) {
      build_hourly_series(
        location = x,
        variables = weather_vars,
        stations_per_loc = stations_per_loc_hour,
        claims_line_data = temp)}) %>%
      bind_rows(.)
    
    data_with_weather_day <- map(.x = all_locations, .f = function(x) {
      build_daily_series(
        location = x,
        variables = weather_vars_day,
        stations_per_loc = stations_per_loc_day,
        claims_line_data = temp)}) %>%
      bind_rows(.) %>%
      select(all_of(weather_vars_day))
    
    all_negative_samples[[3]] <- bind_cols(data_with_weather, data_with_weather_day) %>%
      mutate(day_of_week = wday(loss_date, label = TRUE))
    
  }

}

all_samples_combined <- bind_rows(all_negative_samples) %>%
  bind_rows(all_data, .) %>%
  rename(
    date = loss_date,
    time = time_of_loss,
    hour = hour_of_loss,
    city = city_of_incident,
    incident = target
  )
  
write_csv(all_samples_combined, "data/ml-model/final_data_combined.csv")