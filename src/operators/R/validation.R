library(tidyverse)
library(parallel)
library(brms)

# First, get the best Bayesian model.

results_combined <- c(
  readRDS("results/operators/models/non-hierarchical.rds"),
  readRDS("results/operators/models/rand_int.rds"),
  readRDS("results/operators/models/rand_int_slope.rds")) 

results_loo <- lapply(results_combined, LOO, cores = detectCores() - 2)
loo_values <- loo_compare(results_loo)

# Best model is the random intercept and slope model with tau = 10.
# Get predictions from this model, discard the rest.

final_bayes_model <- results_combined[[rownames(loo_values)[1]]]
final_glm <- readRDS("results/operators/models/basic-glm.rds")

test_data <- read_csv("data/operators/test.csv") %>%
  mutate(hours_worked_div_1957 = total_hours_last3yr / 1957)

test_results_glm <- predict(final_glm, newdata = test_data, type = "response")
test_results_bayes <- predict(final_bayes_model, newdata = test_data, )

results <- tibble(
  model = c("Best Simple GLM", "Best Bayesian"),
  RMSE = c(sqrt(mean((test_results_glm - test_data$number_incidents)^2)), 
           sqrt(mean((test_results_bayes[, 1] - test_data$number_incidents)^2)))
  )