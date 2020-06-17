library(tidyverse)
library(lubridate)
library(ggthemes)
library(scales)

train <- read_csv("data/ml-model/train.csv", na = c("", "NULL", "--"))

extra_bus_info <- read_csv("data/TransLink Raw Data/Bus_spec.csv",
                           col_types = cols_only(
                             bus_no = col_character(),
                             asset_class = col_character(),
                             asset_manufactmodel = col_character()),
                           na = c("", "NULL"))

train_with_bus_info <- train %>%
  left_join(., extra_bus_info, by = "bus_no") %>%
  mutate(season = case_when(
    month(date) %in% c(1, 2, 3) ~ "Winter",
    month(date) %in% c(4, 5, 6) ~ "Spring",
    month(date) %in% c(7, 8, 9) ~ "Summer",
    month(date) %in% c(10, 11, 12) ~ "Fall",
    TRUE ~ "FILL")) %>%
  mutate(part_of_day = case_when(
    hour %in% c(0, 1, 2, 3, 4, 5) ~ "Early Morning",
    hour %in% c(6, 7, 8, 9, 10, 11) ~ "Morning",
    hour %in% c(12, 13, 14, 15, 16, 17) ~ "Afternoon",
    hour %in% c(18, 19, 20, 21, 22, 23) ~ "Evening"
  ),
  visib = as.numeric(visib))


# Which columns have NA's?

names_na <- colnames(train_with_bus_info)[colSums(is.na(train_with_bus_info)) > 0]

# How many NA's?

num_na <- colSums(is.na(train_with_bus_info))

# Not too many NA's. Can probably impute in the modelling pipeline.

### Relationships

# Day vs. Incident Rate
# Obviously, less incidents on Saturday and Sunday.

train_with_bus_info %>%
  group_by(day_of_week) %>%
  summarize(count_incident = sum(incident)) %>%
  ggplot(., aes(x = fct_relevel(as.factor(day_of_week), c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(title = "Count of Incident per Day", x = "Day", y = "Count")

# Season?
# Even the season appears to be significant! Winter...    
train_with_bus_info %>%
  group_by(season) %>%
  summarize(count_incident = sum(incident)) %>%
  ggplot(., aes(x = fct_relevel(as.factor(season), c("Winter", "Spring", "Summer", "Fall")), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(title = "Count of Incident per Season", x = "Season", y = "Count")

# Time of day
train_with_bus_info %>%
  group_by(part_of_day) %>%
  summarize(count_incident = sum(incident)) %>%
  ggplot(., aes(x = fct_relevel(as.factor(part_of_day), c("Early Morning", "Morning", "Afternoon", "Evening")), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(title = "Count of Incident per Time of Day", x = "Time of Day", y = "Count")

# Hour of the week
# Between 7-9 am and between 3-5 peak times
train_with_bus_info %>%
  group_by(hour) %>%
  summarize(count_incident = sum(incident)) %>%
  ggplot(., aes(x = as.factor(hour), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(x = "Hour of Day", y = "Count", title = "Count of Incident per Hour")

# Month
# This doesn't look very informative at all!
train_with_bus_info %>%
  mutate(month = month(date)) %>%
  group_by(month) %>%
  summarize(count_incident = sum(incident)) %>%
  ggplot(., aes(x = as.factor(month), y = count_incident)) + 
  geom_bar(stat = "identity") + 
  theme_economist() + 
  labs(x = "Month", y = "Count", title = "Count of Incident per Month")

# What about temperature? Is this associated with incidents?
# Doesn't look like it - the distributions are practically the same!
train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = temp)) + 
  geom_boxplot() +
  theme_economist() +
  labs(x = "Incident Occurred", y = "Temperature", title = "Distribution of Temperature Per Incident")

# Looks normal - perfect
train_with_bus_info %>%
  ggplot(., aes(x = temp)) +
  theme_economist() +
  geom_histogram()

# Precipitation? 
# Doesn't look very informative either - but median is a bit higher for incidents
# vs. no incidents. A tree could easily pick this up.
train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = total_precip)) +
  geom_boxplot() +
  scale_y_continuous(trans = "log1p") +
  theme_economist() +
  labs(x = "Incident Occurred", y = "Total Precipitation, log + 1 scale (mm)", title = "Distribution of Precipitation Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

train_with_bus_info %>%
  ggplot(., aes(x = total_precip)) +
  theme_economist() +
  geom_histogram()

# Rain?
# Looks virtually identical to total precipitation!
train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = total_rain)) +
  geom_boxplot() +
  scale_y_continuous(trans = "log1p") + 
  theme_economist() +
  labs(x = "Incident Occurred", y = "Total Rain, log + 1 scale (mm)", title = "Distribution of Rain Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

# Mega right skewed - log plus one transformation likely useful.
train_with_bus_info %>%
  ggplot(., aes(x = total_rain)) +
  theme_economist() +
  geom_histogram()

# Snow
# Again, barely any difference. However, the means do differ in a way that makes sense
train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = total_snow)) +
  geom_boxplot() +
  scale_y_continuous(trans = "log1p") + 
  theme_economist() +
  labs(x = "Incident Occurred", y = "Total Snow, log + 1 scale (mm)", title = "Distribution of Snow Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

train_with_bus_info %>%
  ggplot(., aes(x = total_snow)) +
  theme_economist() +
  geom_histogram()

# Wind

train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = wind_spd)) +
  geom_boxplot() +
  scale_y_continuous(trans = "log1p") + 
  theme_economist() +
  labs(x = "Incident Occurred", y = "Wind Speed, log + 1 scale (km/h)", title = "Distribution of Wind Speed Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

  train_with_bus_info %>%
      ggplot(., aes(x = wind_spd)) +
      theme_economist() +
      geom_histogram()

# Humidity

train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = rel_hum)) +
  geom_boxplot() +
  scale_y_continuous(trans = "log1p") + 
  theme_economist() +
  labs(x = "Incident Occurred", y = "Humidity, log + 1 scale (km/h)", title = "Distribution of Humidity Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

# LEFT SKEWED!
train_with_bus_info %>%
  ggplot(., aes(x = rel_hum)) +
  theme_economist() +
  geom_histogram()

# Elevation - looks pretty useless...

train_with_bus_info %>%
  group_by(elev) %>%
  summarize(count_incident = sum(incident)/ n()) %>%
  ggplot(., aes(x = as.factor(elev), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(x = "Incident Occurred", y = "Elevation", title = "Rate of Incidence Per Elevation") +
  theme(axis.title.y = element_text(vjust = 4))

# Visibility 

train_with_bus_info %>%
  ggplot(., aes(x = as.factor(incident), y = visib)) +
  geom_boxplot() +
  theme_economist() +
  labs(x = "Incident Occurred", y = "Visibility, log + 1 scale", title = "Distribution of Visibility Per Incident") +
  theme(axis.title.y = element_text(vjust = 4))

train_with_bus_info %>%
  ggplot(., aes(x = visib)) +
  theme_economist() +
  geom_histogram()

# We already know location and operator experience are super predictive

train_with_bus_info %>%
  group_by(city) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = city, y = count_incident)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  theme_economist() + 
  labs(x = "\nCity", y = "\nRate of Incidents", title = "Incident Rate Per City Occurrence") +
  theme(axis.title.y = element_text(vjust = 4))

# Experience category. Some small differences, but differences nonethe less. Likely
# predictive.
train_with_bus_info %>%
  group_by(experience_category) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = experience_category, y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(x = "\nExperience Level", y = "Incident Rate Per Experience Level Occurrence", title = "Experience vs. Incident Rate") +
  theme(axis.title.y = element_text(vjust = 3))

# Busses

# Per bus carrying capacity
# Looks predictive
train_with_bus_info %>%
  drop_na(bus_carry_capacity) %>%
  group_by(bus_carry_capacity) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = as.factor(bus_carry_capacity), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  labs(x = "\nBus Carry Capacity", y = "Incident Rate Per Bus Carry Capacity", title = "Bus Carry Capacity vs Incidence Rate") + 
  theme(axis.title.y = element_text(vjust = 3))

# Per bus manufacturer
# Both look predictive
train_with_bus_info %>%
  drop_na(asset_manufactmodel) %>%
  group_by(asset_manufactmodel) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = as.factor(asset_manufactmodel), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  coord_flip() + 
  labs(x = "Bus Manufacturer", y = "Incident Rate Per Bus Manufacturer", title = "Bus Manufacturer vs. Incident Rate")

# Per class
train_with_bus_info %>%
  drop_na(asset_class) %>%
  group_by(asset_class) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = as.factor(asset_class), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  coord_flip() + 
  labs(x = "Bus Class", y = "Incident Rate Per Bus Class", title = "Bus Class vs. Incident Rate")

# Per age
# Could also be predictive
train_with_bus_info %>%
  drop_na(bus_age) %>%
  group_by(bus_age) %>%
  summarize(count_incident = sum(incident) / n()) %>%
  ggplot(., aes(x = as.factor(bus_age), y = count_incident)) +
  geom_bar(stat = "identity") +
  theme_economist() +
  coord_flip() + 
  labs(x = "Bus Age", y = "Incident Rate Per Bus Age", title = "Bus Age vs. Incident Rate")

# Per line
# Data is too large to use one bar plot.
# VERY PREDICTIVE!!!!!!
per_line <- train_with_bus_info %>%
  group_by(line_no) %>%
  summarize(count_incident = sum(incident) / n()) 