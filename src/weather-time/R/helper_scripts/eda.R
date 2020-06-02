# This script is purely for modelling purposes.

library(tidyverse)
library(forecast)
library(ggthemes)

train <- read_csv("data/weather-time/train.csv")

all_locations <- unique(train$city_of_incident)

# Graph all the series

ggplot(train, aes(x = final_date, y = count)) +
  geom_line() +
  facet_wrap(vars(city_of_incident)) +
  theme_economist() + 
  labs(x = "Time", y = "Count")

create_ts <- function(location, train) {
  
  location_only <- train %>%
    filter(city_of_incident == {{location}}) 
  
  ts(data = location_only$count, start = c(2011, 1), frequency = 365.25/7)
  
}

# Convert the data all into a time series object

all_series <- map(all_locations, .f = function(x) create_ts(x, train = train)) %>%
  set_names(all_locations) 

aggregated_series <- reduce(all_series, function(x, y) x + y)
 
# Aggregated

autoplot(aggregated_series, xlab = "Time", ylab = "Count", main = "All Regions Combined") + theme_economist() 

# Seasonal plot...if there isn't, then graph should look really messy.

forecast::ggseasonplot(aggregated_series) + theme_economist()

# Doesn't appear to have any consistent seasonality, which is a bit surprising