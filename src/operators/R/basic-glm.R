library(tidyverse)
library(VGAM)

# Read in data, preprocess
# If cost centre is NA, just fill with the most common value.
data <- read_csv("data/operators/train.csv") %>%
  mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
  mutate(
    experience_ordered = factor(experience, ordered = TRUE, levels = c("<6 Months", ">6 & 18 Months", ">18 & <60 Months", ">60 Months")), 
    cost_centre = factor(cost_centre),
    log_hours_worked = log(total_hours_last3yr / 1957)) %>%
  mutate(cost_centre = relevel(cost_centre, ref = "VTC")) 

predictor_combinations <- c(
  "~ experience_ordered + offset(log_hours_worked)",
  "~ cost_centre + offset(log_hours_worked)",
  "~ experience_ordered + cost_centre + offset(log_hours_worked)"
)

fit_model <- function(predictors, data) {
  
  model <- vglm(
    as.formula(paste0("number_incidents", predictors)), 
    family = pospoisson(),
    data = data
  )
  
}


## AICC was developed in the context of linear models
# https://bbolker.github.io/mixedmodels-misc/glmmFAQ.html#can-i-use-aic-for-mixed-models-how-do-i-count-the-number-of-degrees-of-freedom-for-a-random-effect
# Might be wise to stick with AIC for now
all_models <- map(predictor_combinations, fit_model, data = data)
aic <- map(all_models, AIC)