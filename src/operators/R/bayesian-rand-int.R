library(tidyverse)
library(recipes)
library(rstan)
library(parallel)
library(loo)
library(bayesplot)

# Read in data, preprocess
# If cost centre is NA, just fill with the most common value.
data <- read_csv("data/operators/train.csv") %>%
  mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
  mutate(
  #  experience_ordered = factor(experience, ordered = TRUE, levels = c("<6 Months", ">6 & 18 Months", ">18 & <60 Months", ">60 Months")), 
    experience = factor(experience),
    cost_centre = factor(cost_centre),
    hours_worked_div_1957 = total_hours_last3yr / 1957) %>%
  mutate(
    cost_centre = relevel(cost_centre, ref = "VTC"),
    experience = relevel(experience, ref = ">60 Months")) %>%
  mutate(cost_centre = as.integer(cost_centre))

preprocess_recipe <- recipe(number_incidents ~ experience + cost_centre, data = data) %>%
  step_dummy(experience)

train_prep <- prep(preprocess_recipe, new_data = data)
train <- bake(train_prep, new_data = data)

# ### JAGS
# data_list <- list(
#   N_total = nrow(data),
#   num_experience_cat = length(unique(data$experience)),
#   num_cost_cat = length(unique(data$cost_centre)),
#   y = data$number_incidents,
#   offset = data$hours_worked_div_1957,
#   experience = as.integer(data$experience),
#   cost_centre = as.integer(data$cost_centre),
#   lambda = 10
# )
# 
# model_fit <- jags.model(file = "src/operators/jags/l1_bayesian.txt", data = data_list, n.chains = 1, n.adapt = 1000)
# model_samples <- coda.samples(model_fit, thin = 1, n.iter = 10000, variable.names = c("b_0", "b_experience", "b_cost_centre"))

### STAN

fit_model <- function(tau_val) {
  
  num_cat_exp = length(train %>%
    select(contains("experience")) %>%
    colnames())
  
  data_list <- list(
    N_total = nrow(train),
    num_cat_exp = num_cat_exp,
    J = length(unique(train$cost_centre)),
    cost_centre = train$cost_centre,
    tau = tau_val,
    X = train[!names(train) %in% c("number_incidents", "cost_centre")],
    offset = data$hours_worked_div_1957,
    y = train$number_incidents
  )
  
  samples <- stan(
    "src/operators/stan/l1_bayesian-rand-int.stan",
    data = data_list,
    iter = 4000, 
    refresh = 1,
    cores = detectCores() - 2,
    warmup = 1000
  )
  
  ll <- extract_log_lik(samples, merge_chains = FALSE)  
  r_eff <- relative_eff(exp(ll), cores = detectCores() - 2)
  loo_model <- loo(ll, r_eff = r_eff, cores = detectCores() - 2)
  
  loo_model
  
}

tau_values <- c(1e-4, 1e-3, 1e-2, 1e-1, 1, 10)
results <- lapply(tau_values, fit_model)
saveRDS(results, "results/operators/validation-rand-int.rds")