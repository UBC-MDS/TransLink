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
    experience = relevel(experience, ref = ">60 Months")) 

preprocess_recipe <- recipe(number_incidents ~ experience + cost_centre, data = data) %>%
  step_dummy(all_predictors(), )

train_prep <- prep(preprocess_recipe, new_data = data)
train <- bake(train_prep, new_data = data)

### STAN

fit_model <- function(tau_val) {
  
  data_list <- list(
    N_total = nrow(train),
    num_cat_exp = length(unique(data$experience)) - 1,
    num_cat_cost = length(unique(data$cost_centre)) - 1,
    tau = tau_val,
    K = ncol(train) - 1,
    X = train[!names(train) %in% c("number_incidents")],
    offset = data$hours_worked_div_1957,
    y = train$number_incidents
  )
  
  samples <- stan(
    "src/operators/stan/l1_bayesian.stan",
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

# Try these initial values for tau
tau_values <- c(1e-3, 1e-2, 1e-1, 1, 10, 100)
results <- lapply(tau_values, fit_model)

# Get "best" model
min_tau <- tau_values[which.min(looic)]

# Are there truly any differences in expected LOO prediction error between
# different tau values?

loo_compare(results)

# Conclusion: As long as we have low ish values of tau (less than or equal to 1)
# no. Large taus which means high apriori variance yields noticeably
# worse predictive models.

saveRDS(results, "results/operators/validation.rds")

