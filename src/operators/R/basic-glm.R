library(tidyverse)
library(VGAM)

# Read in data, preprocess
# If cost centre is NA, just fill with the most common value.
data <- read_csv("data/operators/train.csv") %>%
  mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
  mutate(
    experience = factor(experience), 
    cost_centre = factor(cost_centre),
    hours_worked_div_1957 = total_hours_last3yr / 1957) %>%
  mutate(
    cost_centre = relevel(cost_centre, ref = "VTC"),
    experience = relevel(experience, ref = ">60 Months")) 

predictor_combinations <- c(
  "~ experience + offset(log(hours_worked_div_1957))",
  "~ cost_centre + offset(log(hours_worked_div_1957))",
  "~ experience + cost_centre + offset(log(hours_worked_div_1957))"
)

fit_model <- function(predictors, data) {
  
  model <- vglm(
    as.formula(paste0("number_incidents", predictors)), 
    family = pospoisson(),
    data = data, 
  )
  
}

## AICC was developed in the context of linear models
# https://bbolker.github.io/mixedmodels-misc/glmmFAQ.html#can-i-use-aic-for-mixed-models-how-do-i-count-the-number-of-degrees-of-freedom-for-a-random-effect
# Might be wise to stick with AIC for now
all_models <- map(predictor_combinations, fit_model, data = data)
results_basic_glm <- tibble(
  "Set of Predictors" = c("Experience Only", "Cost Centre Only", "Experience and Cost Centre"),
  AIC = map(all_models, AIC)
  )

saveRDS(results_basic_glm, "results/operators/report-tables/basic-glm-modelselection.rds")
best_basic_glm <- fit_model(predictor_combinations[3], data = data)
saveRDS(best_basic_glm, "results/operators/models/basic-glm.rds")