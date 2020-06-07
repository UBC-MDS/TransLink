# Author: Brayden Tang
# Date: June 5th, 2020

"This script recreates negative instances for the purposes of creating a machine learning model,
as outlined here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57 and
here: https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1 
Usage: 1_sample.R <path_accident_data> <path_weather_stations_data_hour> <path_weather_stations_data_day> <path_out> 

Options:
<path_accident_data> A file path that gives the location of the cleaned accident data. Should be a .rds file.
<path_weather_stations_data_hour> A file path that gives the location of the weather stations data per hour. Should be a .rds file.
<path_weather_stations_data_day> A file path that gives the location of the weather stations data per day. Should be a .rds file. 
<path_out>  A file path that describes where to store the combined dataset.
" -> doc

library(tidyverse)
library(lubridate)
library(caret)
library(docopt)

opt <- docopt(doc)

source("src/ml-model/R/helper-scripts/build_series.R")

#' This script recreates negative instances for the purposes of creating a machine learning model,
#' as outlined here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57 and
#' here: https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1 
#'
#' @param path_accident_data A file path that gives the location of the cleaned accident data. Should be a .rds file.
#' @param path_weather_stations_data_hour A file path that gives the location of the weather stations data per hour. Should be a .rds file.
#' @param path_weather_stations_data_day A file path that gives the location of the weather stations data per day. Should be a .rds file.
#' @param path_out A file path that describes where to store the combined dataset.
#'
#' @return None.
#' @export
#'
#' @examples
#' main(
#' path_accident_data = "data/ml-model/cleaned_accident_data.rds",
#' path_weather_stations_data_hour = "data/ml-model/stations_per_loc_hour.rds",
#' path_weather_stations_data_day = "data/ml-model/stations_per_loc_day.rds",
#' path_out = "data/ml-model"
#' )
main <- function(path_accident_data, path_weather_stations_data_hour, path_weather_stations_data_day, path_out) {
  
  if (!str_detect(path_accident_data, ".rds")) {
    stop("path_accident_data should be a specific .rds file.")
  } else if (!str_detect(path_weather_stations_data_hour, ".rds")) {
    stop("path_weather_stations_data_hour should be a specific .rds file.")
  } else if (!str_detect(path_weather_stations_data_day, ".rds")) {
    stop("path_weather_stations_data_day should be a specific .rds file.")
  } else if (str_detect(path_out, "\\.xlsx$|\\.csv$|\\.rds$|//.txt$")) {
    stop("The output path must be a general path, not a 
             path to a specific file. Remove the file extension.")
  } else if (endsWith(path_out, "/")) {
    stop("path_out should not end with /")
  }
  
  # Read in data produced by 0_get-weather-data.R
  all_data <- readRDS(path_accident_data) %>%
    mutate(day_of_year = yday(loss_date))
  
  # Read in weather data by location, per hour and per day
  stations_per_loc_hour <- readRDS(path_weather_stations_data_hour)
  stations_per_loc_day <- readRDS(path_weather_stations_data_day)
  # Randomly select rows, with replacement, from the entire dataset
  set.seed(200350623)
  sample_rows <- sample_n(all_data, size = round(nrow(all_data) * 3.3, 0), replace = TRUE)
  
  # Specify the total possible values we could possibly change 
  all_lines <- unique(all_data$line_no)
  all_days <- 1:366
  all_hours <- 0:23
  
  # Generate a vector indicating what variable to change 
  # 1 is line, 2 is hour, 3 is day of year. 
  # Sampling scheme taken from this article here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57
  # A more rigorous paper that also employs a similar sampling scheme for Montreal:
  # https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1
  
  set.seed(200350623)
  sample_rows_with_var <- sample_rows %>%
    mutate(var_to_change = sample.int(n = 3, size = nrow(sample_rows), replace = TRUE))
  
  # Get count of scenarios
  counts <- sample_rows_with_var %>%
    group_by(var_to_change) %>%
    count()
  
  # Generate the replacement values for each observation sampled above, drawn uniformly and randomly
  set.seed(200350623)
  lines <- sample(all_lines, size = counts$n[which(counts$var_to_change == 1)], replace = TRUE)
  hours <- sample(all_hours, size = counts$n[which(counts$var_to_change == 2)], replace = TRUE)
  days <- sample(all_days, size = counts$n[which(counts$var_to_change == 3)], replace = TRUE)
  
  all_negative_samples <- vector("list", 3)
  
  for (i in 1:3) {
  
    if (i == 1) {
  
      # Get all the rows that were selected to have their line changed. Then, 
      # overwrite the line with the randomly generated ones. Then, check
      # if the observation exists as a recorded accident by joining. If "no", 
      # then keep the synthetic observation otherwise throw it away.
      
      all_negative_samples[[1]] <- sample_rows_with_var %>%
        filter(var_to_change == 1) %>%
        mutate(line_no = lines) %>%
        left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
        replace_na(list(check = "no")) %>%
        filter(check == "no") %>%
        mutate(target = rep(0, nrow(.))) %>%
        select(-var_to_change, -check)
      
    } else if (i == 2) {
      
      # Same thing as above, but since we are changing by the hour we need
      # to change the other variables that also change by the hour - so the weather variables.
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
      
      # If we change the day of the year, the hourly weather data AND the day weather data
      # also change.
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
  
  # Combine all of the data and save.
  all_samples_combined <- bind_rows(all_negative_samples) %>%
    bind_rows(all_data, .) %>%
    rename(
      date = loss_date,
      time = time_of_loss,
      hour = hour_of_loss,
      city = city_of_incident,
      incident = target
    )
    
  write_csv(all_samples_combined, paste0(path_out, "/final_data_combined.csv"))
  
  set.seed(200350623)
  shuffle_rows <- sample(nrow(all_samples_combined))
  all_samples_combined_shuffled <- all_samples_combined[shuffle_rows, ]
  train_index <- caret::createDataPartition(y = all_samples_combined_shuffled$incident, p = 0.85)
  
  # Write train and test sets.
  write_csv(all_samples_combined_shuffled[train_index[[1]], ], paste0(path_out, "/train.csv"))
  write_csv(all_samples_combined_shuffled[-train_index[[1]], ], paste0(path_out, "/test.csv"))
  
}