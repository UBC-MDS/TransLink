# Author: Brayden Tang
# Date: May 28th, 2020

"This script builds the required weather time series by reading in historical data from
Environment Canada. It then splits the data into training and test sets. Assumes
that this script will be run from the root of the repository,
Usage: 0_get-weather-data.R <path_claims_data> <path_preventables_data> <path_employee_data> <data_path_out> 

Options:
<path_claims_data>          A file path that gives the location of the claim_vehicle_employee_line.csv data file.
<path_preventables_data>    A file path that gives the location of the Preventable and Non Preventable_tabDelimited.txt data file.
<path_employee_data>        A file path that gives the location of the employee_experience_V2.csv data file.
<data_path_out>             A general file path that specifies where to output the raw time series and the training and testing sets.
" -> doc

library(tidyverse)
library(lubridate)
library(weathercan)
library(docopt)

source("src/ml-model/R/helper-scripts/build_series.R")

opt <- docopt(doc)

#' This function finds the closest weather stations within 100km of the latitude 
#' and longitude provided. It only finds weather stations that give daily data
#' and that has data up to the current time period of 2020. 
#'
#' @param lat A numeric value describing the latitude of the desired location.
#' @param long A numeric value describing the longitude of the desired location.
#' @param hour If TRUE, looks for weather stations that give hourly data. If FALSE,
#' looks for weather stations that give daily data. Default is TRUE.
#'
#' @return A numeric vector of all of the relevant weather stations within 100km of 
#' the location described by the latitude and longitude. The returned vector
#' is sorted such that the first values in the vector are the closest in distance
#' to the pinged location.
#' @export
#'
#' @examples
#' find_closest(lat = 45.121, long = -122.231)
find_closest <- function(lat, long, hour = TRUE) {
  
  # Check for bad input
  
  if (!is.numeric(lat)) {
    stop("Latitude must be numeric.")
  } else if (!is.numeric(long)) {
    stop("Longitude must be numeric.")
  } else if (long > 0) {
    warning("Check longitude. In the BC area, it is unlikely that longitude is positive.")
  }
  
  if (hour == TRUE) {
    time_unit <- "hour"
  } else {
    time_unit <- "day"
  }
  
  stations <- stations_search(coords = c(lat, long), dist = 100, interval = time_unit, ends_earliest = 2020)$station_id
  
  # For the Vancouver airport weather station, there are two stations split into 
  # 889 and 51442 for some reason. We need both and so we add that weather
  # station explicitly to the set.
  
  if (51442 %in% c(stations)) {
    out <- c(889, stations)
  } else {
    out <- stations
  }
  
}

#' This function finds the closest weather stations per a specific location, and
#' sorts the weather data from these weather stations accordingly using the data 
#' already downloaded. This is made an explicit function to save on computation time.
#' 
#' @param location A named location that can be found in location_lat_long 
#' @param location_lat_long A data frame with three columns: location, which is a specific 
#' location of interest, lat, which is the latitude of that location, and long, which is the
#' longitude of that location.
#' @param all_relevant_weather A data frame that contains all of the relevant weather data
#' from all possible weather stations out of ALL possible locations given in location_lat_long. 
#' @param hour If TRUE, looks for weather stations that give hourly data. If FALSE,
#' looks for weather stations that give daily data. Default is TRUE.
#'
#' @return A data frame that contains the relevant weather data for the particular location of interest,
#' sorted according to how close the weather station is to the location.
#' @export
#'
#' @examples
#' closest_stations_per_location(
#' location = "Burnaby",
#' location_lat_long = location_lat_long,
#' all_relevant_weather = all_relevant_weather)
closest_stations_per_location <- function(location, location_lat_long, all_relevant_weather, hour = TRUE) {
  
  if (!is.character(location)) {
    stop("Location must be a character.")
  } else if (any(is_tibble(location_lat_long) | is.data.frame(location_lat_long)) == FALSE) {
    stop("location_lat_long must be a data frame or a tibble.")
  } else if (!all(c("location", "lat", "long") %in% colnames(location_lat_long))) {
    stop("location_lat_long must have columns location, lat, long.")
  } else if (!location %in% location_lat_long$location) {
    stop("location must be a value in the location column of location_lat_long.")
  } else if (any(is_tibble(all_relevant_weather) | is.data.frame(all_relevant_weather)) == FALSE) {
    stop("all_relevant weather must be data frame or a tibble.")
  } 
  
  if (hour == TRUE) {
    time_unit <- "hour"
  } else {
    time_unit <- "day"
  }
  
  lat <- location_lat_long$lat[location_lat_long$location == location]
  lon <- location_lat_long$long[location_lat_long$location == location]
  closest_stations <- stations_search(coords = c(lat, lon), interval = time_unit, dist = 50)$station_id
  
  if (51442 %in% closest_stations) {
    closest_stations[which(closest_stations == 51442)] <- 999
  }
  
  candidate_values <- all_relevant_weather %>%
    filter(station_id %in% closest_stations) %>%
    .[order(match(.$station_id, closest_stations)), ]
}

#' This function wrangles the incident data by incorporating bus, employee, time, weather,
#' and location data all in one dataset. The idea of this script is to generate a dataset
#' in which we can then employ a sampling scheme to generate negative examples.
#'
#' @param path_claims_data A file path that gives the location of the claim_vehicle_employee_line.csv data file.
#' @param path_preventables_data A file path that gives the location of the Preventable and Non Preventable_tabDelimited.txt data file.
#' @param path_employee_data A file path that gives the location of the employee_experience_V2.csv data file.
#' @param data_path_out A general file path that specifies where to output the raw time series and the training and testing sets.
#'
#' @return None
#' @export
#'
#' @examples
#' main(
#' path_claims_data = "data/TransLink Raw Data/claim_vehicle_employee_line.csv",
#' path_preventables_data = "data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt",
#' path_employee_data = "data/TransLink Raw Data/employee_experience_V2.csv",
#' data_path_out = "data/ml-model"
#' )
main <- function(path_claims_data, path_preventables_data, path_employee_data, data_path_out) {

      if (!str_detect(path_claims_data, ".csv")) {
        stop("path_claims_data should be a specific .csv file.")
      } else if (!str_detect(path_preventables_data, ".txt")) {
        stop("path_preventables_data should be a specific .txt file.")
      } else if (!str_detect(path_employee_data, ".csv")) {
        stop("path_employee_data should be a specific .csv file.")
      } else if (str_detect(data_path_out, "\\.xlsx$|\\.csv$|\\.rds$|//.txt$")) {
        stop("The output path must be a general path, not a 
               path to a specific file. Remove the file extension.")
      } else if (endsWith(data_path_out, "/")) {
        stop("data_path_out should not end with /")
      }
        
    # Read in preventables data set to identify the preventable claims only
    preventables_data <- read_tsv(path_preventables_data) %>%
      janitor::clean_names() %>%
      distinct(claim_id, time_of_loss, .keep_all = TRUE) %>%
      select(claim_id, preventable_non_preventable, time_of_loss, loss_location_at, loss_location_on, city_of_incident) 
    
    # Read in claims dataset, and join with the above. Then, select relevant columns,
    # fix spelling errors and other issues with the city_of_incident column,
    # and fill in missing values using information related to the street of the accident
    # and/or the type of bus that was involved in the accident
    # Group together smaller towns with major centres since threre are so few incidents
    # for those cities. Finally, get counts per city_of_incident.
    
    employee_data <- read_csv(path_employee_data) %>%
      janitor::clean_names() %>%
      select(employee_id, experience_category)
      
    claims_line_data <- read_csv(path_claims_data) %>%
        janitor::clean_names() %>%
        mutate(empl_id = as.numeric(empl_id)) %>%
        inner_join(., preventables_data, by = "claim_id") %>%
        inner_join(., employee_data, by = c("empl_id" = "employee_id")) %>%
        select(
          occurrence_id,
          experience_category,
          claim_id,
          loss_date,
          time_of_loss,
          contains("bus"),
          day_of_week,
          line_no,
          time_of_loss,
          city_of_incident,
          loss_location_on,
          empl_id,
          loss_location_at) %>%
      distinct(occurrence_id, .keep_all = TRUE) %>%
      distinct(claim_id, .keep_all = TRUE) %>%
      filter(line_no != "NULL") %>%
        mutate(city_of_incident = tolower(city_of_incident)) %>%
        mutate(city_of_incident = case_when(
          city_of_incident %in% c("van", "vacovuer", "vancouer", "vancover","vancouver", "vancovuer", "ubc", "vancouver - vtc", "vtc") ~ "Vancouver",
          city_of_incident %in% c("lan", "langley", "walnut grove") ~ "Langley",
          city_of_incident %in% c("bur", "burnaby", "bunaby") ~ "Burnaby",
          city_of_incident %in% c("new westminster", "nw", "new westminister", "new westminister", "new wesminster") ~ "New Westminster",
          city_of_incident %in% c("ric", "richmond") ~ "Richmond",
          city_of_incident %in% c("wv", "west vancouver") ~ "West Vancouver",
          city_of_incident %in% c("sur", "south surrey", "surrey", "white rock / surrey", "sureey", "surrye", "cloverdale") ~ "Surrey",
          city_of_incident %in% c("pm", "port moody", "poer moody", "anmore") ~ "Port Moody",
          city_of_incident %in% c("nv", "north vancouver", "north van", "belcarra") ~ "North Vancouver",
          city_of_incident %in% c("coq", "pc", "port coquitlam", "coquitlam") ~ "Port Coquitlam",
          city_of_incident %in% c("mr", "maple ridge") ~ "Maple Ridge",
          city_of_incident %in% c("del", "delta", "ladner", "ladnar") ~ "Delta",
          city_of_incident %in% c("wr", "white rock", "whiterock") ~ "White Rock",
          city_of_incident %in% c("pit", "pitt meadows") ~ "Pitt Meadows",
          TRUE ~ city_of_incident
        )
        ) %>%
        mutate(locations_combined = tolower(paste(loss_location_on, loss_location_at))) %>%
        mutate(city_of_incident = ifelse(is.na(city_of_incident), case_when(
          str_detect(locations_combined, "vtc|metrotown|ubc|renfrew|seymour|stanley|alma|commercial|pender|dumfries|joyce|davie|hastings|49th ave|41th|2nd ave|birch|clarendon|highbury|vcc clark|georgia|marine station|dunsmuir|abbott|cambie|oak 41|powell|nanaimo|clark dr gravely|wesbrook|dunbar|fraser 13|cordova|arbutus|rupert|broadway|ontario|terminus|granview|granville|crown|burrard") ~ "Vancouver",
          bus_category == "SR2299" ~ "Vancouver",
          str_detect(locations_combined, "btc|holdom|willingdon|ave price|university dr|oxford|sperling|lougheed stn|edmonds|kingsway grange") ~ "Burnaby",
          str_detect(locations_combined, "grouse|fell|nvt|ntc|belcarra") ~ "North Vancouver",
          str_detect(locations_combined, "rtc|richmond|cambie rd|htc|no. 3|buswell|landsdowne") ~ "Richmond",
          str_detect(locations_combined, "semiahmoo|stc|152 st|newton|surrey|64th|pattullo") ~ "Surrey",
          str_detect(locations_combined, "lougheed 226|lougheed hwy 226") ~ "Maple Ridge",
          str_detect(locations_combined, "poco|glen high|mundy|ptc|maryhill|ranch") ~ "Port Coquitlam",
          str_detect(locations_combined, "56 st|112th st 84th") ~ "Delta",
          str_detect(locations_combined, "langley") ~ "Langley",
          str_detect(locations_combined, "brunette|8th street 6th") ~ "New Westminster",
          TRUE ~ city_of_incident
        ), city_of_incident)) %>%
      drop_na(city_of_incident, time_of_loss) %>%
      mutate(hour_of_loss = as.numeric(str_extract(time_of_loss, "^.{2}"))) %>%
      filter(!is.na(hour_of_loss)) %>%
      mutate(loss_date = as.Date(loss_date)) %>%
      mutate(day_of_week = wday(loss_date, label = TRUE)) %>%
      select(loss_date, time_of_loss, hour_of_loss, day_of_week, bus_no, bus_age, bus_carry_capacity, empl_id, experience_category, line_no, city_of_incident) %>%
      mutate(target = rep(1, nrow(.)))
    
    rm(preventables_data, employee_data)
    gc()
    
    # This creates a data frame of all of the locations in the dataset wrangled above ^^
    # The latitude and longitudes were derived based on Google maps.
    
    location_lat_long <- tibble(
      location = unique(claims_line_data$city_of_incident),
      lat = c(49.2488, 49.0952, 49.1042, 49.2193, 49.2057, 49.3200, 49.2191, 49.2628, 49.2849, 49.1666, 49.1913, 49.234375, 49.3286, 49.0253),
      long = c(-122.9805, -123.0265, -122.6604, -122.5984, -122.9110, -123.0724, -122.6895, -122.7811, -122.8678, -123.1336, -122.8490, -123.139556, -123.1602, -122.8030)
    )
    
    # Using the defined data frame above, find all of the weather stations that could
    # potentially contain the needed data.
    
    all_relevant_stations <- unique(unlist(pmap(
      list(lat = location_lat_long$lat, long = location_lat_long$long),
      ~find_closest(..1, ..2, hour = TRUE))))
    
    all_relevant_stations_day <- unique(unlist(pmap(
      list(lat = location_lat_long$lat, long = location_lat_long$long),
      ~find_closest(..1, ..2, hour = FALSE))))
    
      # Download data for all of the relevant stations that we found above. The 
    # reason why we do it this way is so that we do not have to keep pinging 
    # the Environment Canada site over and over again. Note that we explicitly
    # make 889 and 51442 be the same code since it is the Vancouver airport.
    print("Downloading hourly data from Environment Canada")
    all_relevant_weather <- weather_dl(all_relevant_stations, interval = "hour", start = "2011-01-01", verbose = TRUE) %>%
      mutate(station_id = ifelse(station_id == 51442 | station_id == 889, 999, station_id),
             date = ymd(date)) 
    
    # Obtain pre-sorted (by distance) weather station data for all relevant weather stations per each location.
    
    stations_per_loc <- map(
      .x = location_lat_long$location,
      .f = closest_stations_per_location,
      location_lat_long = location_lat_long,
      all_relevant_weather = all_relevant_weather,
      hour = TRUE) %>%
      set_names(location_lat_long$location)
    
    rm(all_relevant_weather)
    gc()
    
    # Get all relevant weather related data.
    weather_vars <- c("pressure", "rel_hum", "elev","temp", "visib", "wind_dir", "wind_spd")
    all_locations <- unique(claims_line_data$city_of_incident)
    print("Building hourly data.")
    data_with_weather <- map(.x = all_locations, .f = function(x) {
      build_hourly_series(
        location = x,
        variables = weather_vars,
        stations_per_loc = stations_per_loc,
        claims_line_data = claims_line_data)})
    
    saveRDS(stations_per_loc, "data/ml-model/stations_per_loc_hour.rds")
    rm(stations_per_loc)
    gc()
    # For the day data: we need precipitation data which is not tracked by the hour
    print("Downloading daily data from Environment Canada.")
    all_relevant_weather_day <- weather_dl(all_relevant_stations_day, interval = "day", start = "2011-01-01", verbose = TRUE) %>%
      mutate(station_id = ifelse(station_id == 51442 | station_id == 889, 999, station_id),
             date = ymd(date)) 
    
    stations_per_loc_day <- map(
      .x = location_lat_long$location,
      .f = closest_stations_per_location,
      location_lat_long = location_lat_long,
      all_relevant_weather = all_relevant_weather_day,
      hour = FALSE) %>%
      set_names(location_lat_long$location)
    
    rm(all_relevant_weather_day)
    gc()
    
    # Get all relevant weather related data.
    weather_vars_day <- c("total_precip", "total_rain", "total_snow")
    data_with_weather_day <- map(.x = all_locations, .f = function(x) {
      build_daily_series(
        location = x,
        variables = weather_vars_day,
        stations_per_loc = stations_per_loc_day,
        claims_line_data = claims_line_data)})
    
    saveRDS(stations_per_loc_day, "data/ml-model/stations_per_loc_day.rds")
    rm(stations_per_loc_day)
    gc()
    
    # Join all the time series derived above into a single data frame.
    
    final_data_hour <- bind_rows(data_with_weather)
    final_data_day <- bind_rows(data_with_weather_day) %>%
      select(all_of(weather_vars_day))
    print("Done.")
    final_data <- bind_cols(final_data_hour, final_data_day)
    
    saveRDS(final_data, paste0(data_path_out, "/cleaned_accident_data.rds"))
  
}

main(
  path_claims_data = opt$path_claims_data,
  path_preventables_data = opt$path_preventables_data,
  path_employee_data = opt$path_employee_data,
  data_path_out = opt$data_path_out
)