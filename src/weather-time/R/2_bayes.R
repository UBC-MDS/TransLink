library(brms)
library(recipes)
library(tsibble)
library(tidyverse)
library(forecast)

train <- read_csv("data/weather-time/train.csv") %>%
  mutate(year_week = yearweek(year_week)) %>%
  mutate(time_cont = time(year_week))

# Just for generation of Fourier terms, which is the same regardless of the
# ts values (just need frequency)

vancouver_only <- train %>%
  filter(city_of_incident == "Vancouver")

ts_van <- ts(vancouver_only$count, start = c(2011, 1), frequency = 365.25/7)
fourier_terms <- as_tibble(fourier(ts_van, K = 1)) %>%
  bind_cols(year_week = unique(train$year_week), .)

train_with_fourier <- train %>%
  left_join(., fourier_terms, by = "year_week") %>%
  janitor::clean_names()

recipe_scale <- recipe(count ~ ., data = train_with_fourier) %>%
  step_center(all_numeric(), -count, -contains("_52")) %>%
  step_scale(all_numeric(), -count, -contains("_52"))

train_param <- prep(recipe_scale, training = train_with_fourier)
train_scaled <- bake(train_param, new_data = train_with_fourier)

prior <- set_prior("normal(0, 4)", class = "b") +
  set_prior("normal(0, 8)", class = "b", coef = "stime_cont:city_of_incidentBurnaby_1") +
  set_prior("normal(0, 5)", class = "b", coef = "stime_cont:city_of_incidentDelta_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentLangley_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentMapleRidge_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentNewWestminster_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentNorthVancouver_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentPittMeadows_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentPortCoquitlam_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentPortMoody_1") +
  set_prior("normal(0, 5)", class = "b", coef = "stime_cont:city_of_incidentRichmond_1") +
  set_prior("normal(0, 5)", class = "b", coef = "stime_cont:city_of_incidentSurrey_1") +
  set_prior("normal(0, 13)", class = "b", coef = "stime_cont:city_of_incidentVancouver_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentWestVancouver_1") +
  set_prior("normal(0, 4)", class = "b", coef = "stime_cont:city_of_incidentWhiteRock_1") +
  set_prior("normal(0, 4)", class = "b", coef = "c1_52") +
  set_prior("normal(0, 4)", class = "b", coef = "s1_52") +
  set_prior("normal(0, 8)", class = "b", coef = "stotal_precip_1") 
  
my_model <- brm(
  count ~ 1 + s(time_cont, by = city_of_incident, bs = "tp") + s(total_precip) + mean_temp + (1 | city_of_incident) + s1_52 + c1_52, 
  prior = prior,
  data = train_scaled,
  chains = 4,
  family = zero_inflated_poisson(),
  control = list(adapt_delta = 0.90), seed = 200350623,
  cores = 4)