library(tidyverse)

#' This function retrives a single value of a particular weather variable at a 
#' particular location and on a particular day, given a list of pre-sorted data frames.
#'
#' @param location The location of interest to obtain weather data for. 
#' @param variable The weather variable of interest to build.
#' @param year_day The date of interest: should be in the format "yyyy-mm-dd"
#' @param stations_per_loc A named list, each item containing a presorted data frame (by distance 
#' from location) of weather data.
#' @param hour If TRUE, looks for weather stations that give hourly data. If FALSE,
#' looks for weather stations that give daily data. Default is TRUE.
#'
#' @return A numeric value of the observed variable of interest at a specific time
#' given by year_day. The numeric value is derived such that the closest weather station
#' that doesn't have a missing value is returned.
#' @export
#'
#' @examples
#' build_daily_series(
#' location = "Vancouver",
#' variable = "mean_temp",
#' year_day = "2019-01-20",
#' stations_per_loc = stations_per_loc
#' )
build_hourly_series <- function(location, variables, stations_per_loc, claims_line_data) {
  
  location_only <- claims_line_data %>%
    filter(city_of_incident == {{location}}) %>%
    mutate(row_no = seq(1, nrow(.)))
  
  relevant_weather <- stations_per_loc[[location]] %>%
    select(date, hour, station_id, all_of(variables)) %>%
    mutate(hour = as.numeric(str_extract(hour, "^.{2}")))
  
  location_only_with_weather <- left_join(location_only, relevant_weather, by = c("loss_date" = "date", "hour_of_loss" = "hour")) %>%
    group_by(row_no, .drop = FALSE) %>%
    summarize_at(., .vars = variables, .funs = function(x) x %>% .[!is.na(.)] %>% .[1]) %>%
    select(-row_no)
  
  bind_cols(location_only, location_only_with_weather) %>%
    select(-row_no)
  
}

build_daily_series <- function(location, variables, stations_per_loc, claims_line_data) {
  
  location_only <- claims_line_data %>%
    filter(city_of_incident == {{location}}) %>%
    mutate(row_no = seq(1, nrow(.)))
  
  relevant_weather <- stations_per_loc[[location]] %>%
    select(date, station_id, all_of(variables)) 
  
  location_only_with_weather <- left_join(location_only, relevant_weather, by = c("loss_date" = "date")) %>%
    group_by(row_no, .drop = FALSE) %>%
    summarize_at(., .vars = variables, .funs = function(x) x %>% .[!is.na(.)] %>% .[1]) %>%
    select(-row_no)
  
  bind_cols(location_only, location_only_with_weather) %>%
    select(-row_no)
  
}