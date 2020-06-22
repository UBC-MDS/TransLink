# Author: Brayden Tang
# Date: June 5th, 2020

"This script recreates negative instances for the purposes of creating a machine learning model,
as outlined here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57 and
here: https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1 
Usage: 1_sample.R <path_accident_data> <path_weather_stations_data_hour> <path_weather_stations_data_day> <path_sheet_data> <path_out> 

Options:
<path_accident_data> A file path that gives the location of the cleaned accident data. Should be a .rds file.
<path_weather_stations_data_hour> A file path that gives the location of the weather stations data per hour. Should be a .rds file.
<path_weather_stations_data_day> A file path that gives the location of the weather stations data per day. Should be a .rds file. 
<path_sheet_data> A file path that gives the location of the bus sheet data.
<path_out>  A file path that describes where to store the combined dataset.
" -> doc

library(tidyverse)
library(lubridate)
library(caret)
library(zoo)
library(docopt)

opt <- docopt(doc)

source("src/ml_model/R/helper-scripts/build_series.R")

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
#' path_accident_data = "data/ml_model/cleaned_accident_data.rds",
#' path_weather_stations_data_hour = "data/ml_model/stations_per_loc_hour.rds",
#' path_weather_stations_data_day = "data/ml_model/stations_per_loc_day.rds",
#' path_sheet_data = "data/TransLink Raw Data/Scheduled_Actual_services_2019.csv",
#' path_out = "data/ml_model"
#' )
main <- function(path_accident_data, path_weather_stations_data_hour, path_weather_stations_data_day,
                 path_sheet_data, path_out) {
  
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
  } else if (!str_detect(path_sheet_data, ".csv")) {
    stop("path_sheet_data should be a specific .csv file.")
  }
          
          # Read in data produced by 0_get-weather-data.R and group old lines with their replacement if any/remove
          # lines not in service anymore/Skytrains
          all_data <- readRDS(path_accident_data) %>%
            mutate(day_of_year = yday(loss_date)) %>%
            mutate(line_no = case_when(
              line_no == "135" ~ "95",
              line_no == "C21" ~ "23",
              line_no == "C1" ~ "131",
              line_no == "C15" ~ "215",
              line_no == "C20" ~ "70",
              line_no == "C23" ~ "23",
              line_no == "C5" ~ "148",
              line_no == "154" ~ "128",
              line_no == "999" ~ NA_character_,
              line_no == "N16" ~ "16",
              line_no == "C98" ~ "418",
              line_no == "97" ~ NA_character_,
              line_no == "991" ~ NA_character_,
              line_no == "895" ~ NA_character_,
              line_no == "C75" ~ "322",
              line_no == "C71" ~ "371",
              line_no == "C50" ~ "360",
              line_no == "C70" ~ "370",
              line_no == "C73" ~ "373",
              line_no == "590" ~ NA_character_,
              line_no == "C88" ~ "618",
              line_no == "C25" ~ "181",
              line_no == "C94" ~ "414",
              line_no == "C93" ~ "413",
              line_no == "C96" ~ "416",
              line_no == "C7" ~ "147",
              line_no == "C6" ~ "146",
              line_no == "C9" ~ "109",
              line_no == "177" ~ NA_character_,
              line_no == "C27" ~ "183",
              line_no == "C30" ~ "189",
              line_no == "C37" ~ "171",
              line_no == "C38" ~ "173",
              line_no == "C29" ~ "187",
              line_no == "C28" ~ "184",
              line_no == "C43" ~ "743",
              line_no == "C40" ~ "175",
              line_no == "C44" ~ "744",
              line_no == "C47" ~ "733",
              line_no == "C26" ~ "182",
              line_no == "C24" ~ "180",
              line_no == "C76" ~ "310",
              line_no == "C86" ~ "616",
              line_no == "C53" ~ "363",
              line_no == "43" ~ "R4",
              line_no == "95" ~ "R5",
              line_no == "23" ~ "123",
              line_no == "131" ~ "123",
              line_no == "239" ~ "R2",
              line_no == "70" ~ "68",
              line_no == "96" ~ "R1",
              line_no == "804" ~ "341",
              line_no == "807" ~ "562",
              TRUE ~ line_no
            )) %>%
            drop_na(line_no)
            
          
          # Read in weather data by location, per hour and per day
          stations_per_loc_hour <- readRDS(path_weather_stations_data_hour)
          stations_per_loc_day <- readRDS(path_weather_stations_data_day)
          # Randomly select rows, with replacement, from the entire dataset
          set.seed(200350623)
          sample_rows <- sample_n(all_data, size = round(nrow(all_data) * 3.3, 0), replace = TRUE)
          
          # This reads in the sheet data so that we sample hours, days, or lines that are 
          # most relevant to when busses for some line are actually on the street
          all_combinations <- read_csv(path_sheet_data,
                                       na = c("NULL", -1),
                                       col_types = cols(line_no = col_character(), bus_number = col_character())) %>%
            drop_na(line_no) %>%
            mutate(block = case_when(
              month(sheet_from_date) == 12 ~ 1,
              month(sheet_from_date) == 4 ~ 2,
              month(sheet_from_date) == 6 ~ 3,
              TRUE ~ 4
            )) %>%
            mutate(start_time_hour = hour(seconds_to_period(scheduled_trip_start_time)),
                   end_time_hour = hour(seconds_to_period(sch_trip_end_time)),
                   day_start = yday(sheet_from_date),
                   day_end = yday(sheet_to_date)) %>% 
            group_by(block, line_no, day_type_code, start_time_hour, end_time_hour) %>%
            summarise() %>%
            mutate(max_hr = ifelse(end_time_hour == 0, 0, pmax(start_time_hour, end_time_hour))) %>%
            group_by(block, day_type_code, line_no, max_hr) %>%
            summarise() %>%
            rename("start_time_hour" = max_hr)
          
          lookup_r <- tibble(
            r_bus = c("R1", "R2", "R4", "R5"),
            old = c("96", "239", "43", "95")
          )
      
      all_r_bus <- bind_rows(pmap(.l = list(x = lookup_r$r_bus, y = lookup_r$old), .f = function(x, y) {
        all_combinations %>%
          filter(line_no == {{y}}) %>%
          ungroup() %>%
          mutate(line_no = rep(x, nrow(.)))
      }))
      
      all_combinations <- all_combinations %>%
        ungroup() %>%
        filter(!line_no %in% c("96", "239", "43", "95")) %>%
        bind_rows(., all_r_bus)
      
      
    # Generate a vector indicating what variable to change 
    # 1 is line, 2 is hour, 3 is day of year. 
    # Sampling scheme taken from this article here: https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57
    # A more rigorous paper that also employs a similar sampling scheme for Montreal:
    # https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1
    
    set.seed(200350623)
    sample_rows_with_var <- sample_rows %>%
      mutate(var_to_change = sample.int(n = 3, size = nrow(sample_rows), replace = TRUE))
  
    all_negative_samples <- vector("list", 3)
    
    for (i in 1:3) {
    
      if (i == 1) {
    
        # Get all the rows that were selected to have their line changed. Then, 
        # overwrite the line with the randomly generated ones. Then, check
        # if the observation exists as a recorded accident by joining. If "no", 
        # then keep the synthetic observation otherwise throw it away.
        # The sampling is based on the implied probability of a particular line 
        # operating at a specific time, on a specific day.
        
        all_possible_busses <- all_data %>%
          group_by(line_no, bus_no, city_of_incident, bus_age, bus_carry_capacity) %>%
          summarize()
        
        set.seed(200350623)
        temp <- sample_rows_with_var %>%
          filter(var_to_change == 1) %>%
          mutate(week_day = case_when(
            wday(loss_date) %in% c(2, 3, 4, 5, 6) ~ "MF",
            wday(loss_date) %in% c(7) ~ "SAT",
            TRUE ~ "SUN"
          )) %>%
          mutate(row_num = seq(1, nrow(.)),
                 block = case_when(
                    day_of_year >= 1 & day_of_year <= 111 ~ 1,
                    day_of_year >= 112 & day_of_year <= 174 ~ 2,
                    day_of_year >= 175 & day_of_year <= 244 ~ 3,
                    TRUE ~ 4)) %>%
          left_join(., all_combinations, by = c("week_day" = "day_type_code", "hour_of_loss" = "start_time_hour", "block")) %>%
          group_by(row_num) %>%
          sample_n(size = 1) %>%
          select(-line_no.x, -block, -week_day) %>%
          rename("line_no" = line_no.y) %>%
          ungroup() %>%
          left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
          replace_na(list(check = "no")) %>%
          filter(check == "no") %>%
          mutate(target = rep(0, nrow(.)),
                 experience_in_months = (as.yearmon(loss_date) - as.yearmon(hire_date)) * 12) %>%
          select(-var_to_change, -check, -time_of_loss, -row_num, -hire_date, -termination_date)
        
        # If you change the line, then city, and bus must also change!
        # Additionally, bus year will be incorrect...so we need to fix this.
        set.seed(200350623)
        temp <- temp %>%
          select(-bus_no, -bus_age, -bus_carry_capacity, -city_of_incident) %>%
          mutate(row_no = 1:nrow(.)) %>%
          left_join(., all_possible_busses, by = "line_no") %>%
          group_by(row_no) %>%
          sample_n(1) %>%
          ungroup() %>%
          select(-row_no) 
        
        all_negative_samples[[1]] <- temp
        
      } else if (i == 2) {
        
        # Same thing as above, but since we are changing by the hour we need
        # to change the other variables that also change by the hour - so the weather variables.
        weather_vars <- c("pressure", "rel_hum", "elev","temp", "visib", "wind_dir", "wind_spd")
        
        set.seed(200350623)
        temp <- sample_rows_with_var %>%
          filter(var_to_change == 2) %>%
          mutate(week_day = case_when(
            wday(loss_date) %in% c(2, 3, 4, 5, 6) ~ "MF",
            wday(loss_date) %in% c(7) ~ "SAT",
            TRUE ~ "SUN"
          )) %>%
          mutate(row_num = seq(1, nrow(.)),
                 block = case_when(
                   day_of_year >= 1 & day_of_year <= 111 ~ 1,
                   day_of_year >= 112 & day_of_year <= 174 ~ 2,
                   day_of_year >= 175 & day_of_year <= 244 ~ 3,
                   TRUE ~ 4)) %>%
          left_join(., all_combinations, by = c("week_day" = "day_type_code", "line_no", "block")) %>%
          group_by(row_num) %>%
          sample_n(size = 1) %>%
          select(-block, -week_day, -hour_of_loss) %>%
          rename(hour_of_loss = start_time_hour) %>%
          ungroup() %>%
          mutate(hour_of_loss = ifelse(is.na(hour_of_loss), sample(c(0:1, 5:23), 1), hour_of_loss)) %>%
          left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
          replace_na(list(check = "no")) %>%
          filter(check == "no") %>%
          mutate(target = rep(0, nrow(.)),
                 experience_in_months = (as.yearmon(loss_date) - as.yearmon(hire_date)) * 12) %>%
          select(-var_to_change, -check, -time_of_loss, -row_num, -all_of(weather_vars), -hire_date, -termination_date)
        
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
        
        set.seed(200350623)
        temp <- sample_rows_with_var %>%
          filter(var_to_change == 3) %>%
          mutate(row_num = seq(1, nrow(.)),
                 termination_date = ymd(termination_date)) %>%
          left_join(., all_combinations, by = c("line_no", "hour_of_loss" = "start_time_hour")) %>%
          group_by(row_num) %>%
          sample_n(size = 1) %>%
          mutate(block = ifelse(is.na(block), sample(1:4, size = 1), block)) %>%
          select(-day_type_code) %>%
          ungroup() %>%
          mutate(day_of_year = case_when(
            block == 1 ~ sample(1:111, 1),
            block == 2 ~ sample(112:174, 1),
            block == 3 ~ sample(175:244, 1),
            TRUE ~ sample(176:366, 1)
          )) %>%
          mutate(loss_date = as.Date(day_of_year, origin = paste(year(loss_date) - 1, 12, 31, sep = "-"))) %>%
          left_join(all_data %>% transmute(line_no, hour_of_loss, day_of_year, check = "yes")) %>%
          replace_na(list(check = "no")) %>%
          filter(check == "no") %>%
          mutate(target = rep(0, nrow(.))) %>%
          select(-var_to_change, -check, -time_of_loss, -block, -row_num, -all_of(weather_vars_day), -all_of(weather_vars))
        
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
          bind_rows(., all_2020) %>%
          mutate(experience_in_months = (as.yearmon(loss_date) - as.yearmon(hire_date)) * 12)
        
        # There are no 2020 hires so safe to ignore.
        set.seed(200350623)
        all_negative_experience <- temp %>%
          filter(experience_in_months < 0) %>%
          rowwise() %>%
          mutate(day_of_year = ifelse(is.na(termination_date), sample(yday(hire_date):366, 1), day_of_year)) %>%
          mutate(day_of_year = ifelse(!is.na(termination_date) & year(termination_date) > year(hire_date), sample(yday(hire_date):366, 1), day_of_year)) %>%
          mutate(day_of_year = ifelse(!is.na(termination_date) & year(termination_date) == year(hire_date), sample(yday(hire_date):yday(termination_date), 1), day_of_year),
                  loss_date = as.Date(day_of_year, origin = paste(year(loss_date) - 1, 12, 31, sep = "-")),
                 experience_in_months = (as.yearmon(loss_date)- as.yearmon(hire_date)) * 12)
        
        temp <- temp %>%
          filter(experience_in_months >= 0) %>%
          bind_rows(., all_negative_experience) %>%
          select(-hire_date, -termination_date)
  
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
    
    all_shuttles = c("23", "31", "42", "68", "103", "105", "109", "131", "132", "146",
                     "147", "148", "157", "169", "170", "171", "172", "173", "174", "175", "180", "181",
                     "182", "184", "185", "186", "187", "189", "215", "227", "251", "252", "256", "262",
                     "280", "281", "282", "310", "322", "360", "361", "362", "363", "370", "371", "372", 
                     "373", "412", "413", "414", "416", "560", "561", "562", "563", "564", "609", "614",
                     "616", "617", "618", "619", "719", "722", "733", "741", "743", "744", "745", "746", "748", "749")
    
    # Combine all of the data and save.
    all_samples_combined <- bind_rows(all_negative_samples) %>%
      bind_rows(all_data %>% mutate(experience_in_months = (as.yearmon(loss_date) - as.yearmon(hire_date)) * 12), .) %>%
      rename(
        date = loss_date,
        hour = hour_of_loss,
        city = city_of_incident,
        incident = target
      ) %>%
      select(-time_of_loss, -hire_date, -termination_date) %>%
      mutate(is_shuttle = ifelse(line_no %in% all_shuttles, 1, 0))
  
    if (!dir.exists(path_out)) {
      dir.create(path_out)
    }
      
  write_csv(all_samples_combined, paste0(path_out, "/final_data_combined.csv"))
  
  set.seed(200350623)
  shuffle_rows <- sample(nrow(all_samples_combined))
  all_samples_combined_shuffled <- all_samples_combined[shuffle_rows, ]
  train_index <- caret::createDataPartition(y = all_samples_combined_shuffled$incident, p = 0.85)
  
  # Write train and test sets.
  write_csv(all_samples_combined_shuffled[train_index[[1]], ], paste0(path_out, "/train.csv"))
  write_csv(all_samples_combined_shuffled[-train_index[[1]], ], paste0(path_out, "/test.csv"))
  
}

main(
  path_accident_data = opt$path_accident_data,
  path_weather_stations_data_hour = opt$path_weather_stations_data_hour,
  path_weather_stations_data_day = opt$path_weather_stations_data_day,
  path_sheet_data = opt$path_sheet_data,
  path_out = opt$path_out
  )