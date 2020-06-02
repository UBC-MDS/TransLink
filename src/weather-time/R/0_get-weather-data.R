# Author: Brayden Tang
# Date: May 28th, 2020

"This script builds the required weather time series by reading in historical data from
Environment Canada. It then splits the data into training and test sets. Assumes
that this script will be run from the root of the repository,
Usage: 0_get-weather-data.R <path_claims_data> <path_preventables_data> <data_path_out> 

Options:
<path_claims_data>          A file path that gives the location of the claim_vehicle_employee_line.csv data file.
<path_preventables_data>    A file path that gives the location of the preventable_NonPreventable_claims.csv data file.
<data_path_out>             A general file path that specifies where to output the raw time series and the training and testing sets.
" -> doc

library(tidyverse)
library(tsibble)
library(lubridate)
library(weathercan)
library(docopt)

opt <- docopt(doc)

#' This function finds the closest weather stations within 100km of the latitude 
#' and longitude provided. It only finds weather stations that give daily data
#' and that has data up to the current time period of 2020. 
#'
#' @param lat A numeric value describing the latitude of the desired location.
#' @param long A numeric value describing the longitude of the desired location.
#'
#' @return A numeric vector of all of the relevant weather stations within 100km of 
#' the location described by the latitude and longitude. The returned vector
#' is sorted such that the first values in the vector are the closest in distance
#' to the pinged location.
#' @export
#'
#' @examples
#' find_closest(lat = 45.121, long = -122.231)
find_closest <- function(lat, long) {
  
  # Check for bad input
  
  if (!is.numeric(lat)) {
    stop("Latitude must be numeric.")
  } else if (!is.numeric(long)) {
    stop("Longitude must be numeric.")
  } else if (long > 0) {
    warning("Check longitude. In the BC area, it is unlikely that longitude is positive.")
  }
  
  stations <- stations_search(coords = c(lat, long), dist = 100, interval = c("day"), ends_earliest = 2020)$station_id
  
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
closest_stations_per_location <- function(location, location_lat_long, all_relevant_weather) {
  
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
  
  lat <- location_lat_long$lat[location_lat_long$location == location]
  lon <- location_lat_long$long[location_lat_long$location == location]
  closest_stations <- stations_search(coords = c(lat, lon), interval = "day", dist = 50)$station_id
  
  if (51442 %in% closest_stations) {
    closest_stations[which(closest_stations == 51442)] <- 999
  }
  
  candidate_values <- all_relevant_weather %>%
    filter(station_id %in% closest_stations) %>%
    .[order(match(.$station_id, closest_stations)), ]
}

#' This function retrives a single value of a particular weather variable at a 
#' particular location and on a particular day, given a list of pre-sorted data frames.
#'
#' @param location The location of interest to obtain weather data for. 
#' @param variable The weather variable of interest to build.
#' @param year_day The date of interest: should be in the format "yyyy-mm-dd"
#' @param stations_per_loc A named list, each item containing a presorted data frame (by distance 
#' from location) of weather data.
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
build_daily_series <- function(location, variable, year_day, stations_per_loc) {
  
  if (!is.character(location)) {
    stop("location must be a character.")
  } else if (!is.character(variable)) {
    stop("variable must be a character.")
  } else if (is.na(parse_date_time(year_day, orders = "ymd"))) {
    stop("year_day is not in a year, month, day format.")
  } else if (!is.list(stations_per_loc)) {
    stop("stations_per_loc must be a list.")
  } 
  
  sorted_data <- stations_per_loc[[location]]
  
  candidate_values <- sorted_data %>% 
    subset(date == year_day) %>%
    drop_na({{variable}}) %>%
    select({{variable}}) %>%
    pull()
  
  if (length(candidate_values) == 0) {
    NA
  } else {
    candidate_values[1]
  }
}

#' This function builds the required weather time series by reading in historical data from
#' Environment Canada. It then splits the data into training and test sets.
#'
#' @param path_claims_data A file path that gives the location of the claim_vehicle_employee_line.csv data file.
#' @param path_preventables_data A file path that gives the location of the preventable_NonPreventable_claims.csv data file.
#' @param data_path_out A general file path that specifies where to output the raw time series and the training and testing sets.
#'
#' @return None
#' @export
#'
#' @examples
#' main(
#' path_claims_data = "data/TransLink Raw Data/claim_vehicle_employee_line.csv",
#' path_preventables_data = "data/TransLink Raw Data/preventable_NonPreventable_claims.csv",
#' data_path_out = "data/weather-time"
#' )
main <- function(path_claims_data, path_preventables_data, data_path_out) {

  if (!str_detect(path_claims_data, ".csv")) {
    stop("path_claims_data should be a specific .csv file.")
  } else if (!str_detect(path_preventables_data, ".csv")) {
    stop("path_preventables_data should be a specific .csv file.")
  } else if (str_detect(data_path_out, "\\.xlsx$|\\.csv$|\\.rds$|//.txt$")) {
    stop("The output path for model diagnostics must be a general path, not a 
           path to a specific file. Remove the file extension.")
  } else if (endsWith(data_path_out, "/")) {
    stop("data_path_out should not end with /")
  }
    
# Read in preventables data set to identify the preventable claims only
    
preventables_data <- read_csv(path_preventables_data) %>%
  janitor::clean_names() %>%
  distinct(claim_id, time_of_loss, .keep_all = TRUE) %>%
  select(claim_id, preventable_non_preventable, time_of_loss, loss_location_at, loss_location_on, city_of_incident) 

# Read in claims dataset, and join with the above. Then, select relevant columns,
# fix spelling errors and other issues with the city_of_incident column,
# and fill in missing values using information related to the street of the accident
# and/or the type of bus that was involved in the accident
# Group together smaller towns with major centres since threre are so few incidents
# for those cities. Finally, get counts per city_of_incident.

claims_line_data <- read_csv(path_claims_data) %>%
    janitor::clean_names() %>%
    inner_join(., preventables_data, by = "claim_id") %>%
    filter(preventable_non_preventable == "P") %>%
    select(
      occurrence_id,
      claim_id,
      loss_date,
      contains("bus"),
      day_of_week,
      line_no,
      time_of_loss,
      city_of_incident,
      loss_location_on,
      loss_location_at) %>%
    distinct(occurrence_id, claim_id, bus_no, .keep_all = TRUE) %>%
    mutate(city_of_incident = tolower(city_of_incident)) %>%
    mutate(city_of_incident = case_when(
      city_of_incident %in% c("van", "vancouver", "vancovuer", "ubc", "vancouver - vtc", "vtc") ~ "Vancouver",
      city_of_incident %in% c("lan", "langley", "walnut grove") ~ "Langley",
      city_of_incident %in% c("bur", "burnaby", "bunaby") ~ "Burnaby",
      city_of_incident %in% c("new westminster", "nw", "new westminister", "new westminister") ~ "New Westminster",
      city_of_incident %in% c("ric", "richmond") ~ "Richmond",
      city_of_incident %in% c("wv", "west vancouver") ~ "West Vancouver",
      city_of_incident %in% c("sur", "south surrey", "surrey", "white rock / surrey") ~ "Surrey",
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
      str_detect(locations_combined, "vtc|metrotown|ubc|seymour|stanley|commercial|pender|dumfries|joyce|davie|hastings|49th ave|41th|2nd ave|birch|clarendon|highbury|vcc clark|georgia|marine station|dunsmuir|abbott|cambie|oak 41|powell|nanaimo|clark dr gravely|wesbrook|dunbar|fraser 13|cordova|arbutus|rupert|broadway|terminus|granview|granville|crown|burrard") ~ "Vancouver",
      bus_category == "SR2299" ~ "Vancouver",
      str_detect(locations_combined, "btc|holdom|willingdon|ave price|university dr|oxford|sperling|lougheed stn|edmonds") ~ "Burnaby",
      str_detect(locations_combined, "grouse|fell|nvt|ntc|belcarra") ~ "North Vancouver",
      str_detect(locations_combined, "rtc|richmond|cambie rd|htc|no. 3|buswell") ~ "Richmond",
      str_detect(locations_combined, "semiahmoo|stc|152 st|newton|surrey|64th") ~ "Surrey",
      str_detect(locations_combined, "lougheed 226|lougheed hwy 226") ~ "Maple Ridge",
      str_detect(locations_combined, "poco|glen high|mundy|ptc|maryhill|ranch") ~ "Port Coquitlam",
      str_detect(locations_combined, "56 st") ~ "Delta",
      str_detect(locations_combined, "langley") ~ "Langley",
      str_detect(locations_combined, "brunette|8th street 6th") ~ "New Westminster",
      TRUE ~ city_of_incident
    ), city_of_incident)) %>%
  group_by(loss_date, city_of_incident, .drop = FALSE) %>%
  count() %>%
  ungroup() %>%
  drop_na(city_of_incident) %>%
  complete(loss_date, city_of_incident, fill = list(n = 0))

rm(preventables_data)

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
  ~find_closest(..1, ..2))))

# Download data for all of the relevant stations that we found above. The 
# reason why we do it this way is so that we do not have to keep pinging 
# the Environment Canada site over and over again. Note that we explicitly
# make 889 and 51442 be the same code since it is the Vancouver airport.

all_relevant_weather <- weather_dl(all_relevant_stations, interval = "day", start = "2011-01-01") %>%
  mutate(station_id = ifelse(station_id == 51442 | station_id == 889, 999, station_id),
         date = ymd(date)) 

# Obtain pre-sorted (by distance) weather station data for all relevant weather stations per each location.

stations_per_loc <- map(
  .x = location_lat_long$location,
  .f = closest_stations_per_location,
  location_lat_long = location_lat_long,
  all_relevant_weather = all_relevant_weather) %>%
  set_names(location_lat_long$location)

# Get all relevant weather related time series. Note that this takes maybe 30 minutes.
# I originally had spd_max_gust but I thought the data was unreliable. It is too difficult 
# to distinguish between NA values and 0. If there is no wind, then NA is given but 
# data is also naturally missing.
weather_vars <- c("mean_temp", "min_temp", "max_temp", "total_precip", "total_rain", "total_snow")
data <- as_tibble(expand.grid(
  location = unique(location_lat_long$location),
  loss_date = seq.Date(from = as.Date("2011-01-01"), to = as.Date("2020-05-01"), by = "day"), stringsAsFactors = FALSE)) 

all_weather_series <- map(.x = weather_vars, .f = function(x) { 
  pmap_dbl(
    list(location = data$location, year_day = data$loss_date),
    ~build_daily_series(..1, x, ..2, stations_per_loc = stations_per_loc))
    }
) %>%
  set_names(weather_vars) 

# Join all the time series derived above into a single data frame.

all_data_combined_weather <- bind_cols(all_weather_series) %>%
  bind_cols(data, .)

saveRDS(all_data_combined_weather, paste0(data_path_out, "/time_series_weather.rds"))

# Summarize by week since otherwise data is far too sparse

final_data_set <- claims_line_data %>%
left_join(., all_data_combined_weather, by = c("loss_date", "city_of_incident" = "location")) %>%
mutate(year_week = yearweek(loss_date)) %>%
group_by(year_week, city_of_incident) %>%
summarize(
  count = sum(n),
  min_temp = min(min_temp, na.rm = TRUE),
  max_temp = max(max_temp, na.rm = TRUE),
  mean_temp = mean(mean_temp, na.rm = TRUE),
  total_precip = sum(total_precip, na.rm = TRUE),
  total_rain = sum(total_rain, na.rm = TRUE),
  total_snow = sum(total_snow, na.rm = TRUE)) %>%
mutate_all(~ifelse(is.nan(.), NA,.)) %>%
mutate_all(~ifelse(is.infinite(.), NA, .)) 

saveRDS(final_data_set, paste0(data_path_out, "/time-series-final-complete.rds"))

# Leave the last year of data (week of 2019-04-30 to 2020-04-29) as test

train <- final_data_set %>%
  filter(year_week < yearweek("2019 W16"))

test <- final_data_set %>%
  filter(year_week >= yearweek("2019 W16"))

write_csv(train, paste0(data_path_out, "/train.csv"))
write_csv(test, paste0(data_path_out, "/test.csv"))

}

main(
  path_claims_data = opt$path_claims_data,
  path_preventables_data = opt$path_preventables_data,
  data_path_out = opt$data_path_out
)