library(tidyverse)
library(recipes)
library(brms)
library(bayesplot)
        
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
        
## Non-Hierarchical Bayesian Model
        
fit_non_hier <- function(tau) {
        
  stanvars <- stanvar(tau, name = "tau")    
  prior_non_hier <- prior(normal(0, tau), class = "b")
        
  no_hierarchial <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + cost_centre + offset(log(hours_worked_div_1957)),
    prior = prior_non_hier,
    family = poisson(),
    iter = 3000,
    warmup = 500, 
    seed = 200350623, 
    cores = 4,
    data = data,
    stanvars = stanvars
    )
        
  no_hierarchial
        
}
        
        
# Random Intercept Model
        
fit_rand_int <- function(tau) {
          
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_int <- prior(normal(0, tau), class = "b")
          
  rand_int <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_int,
    family = poisson(),
    iter = 3000,
    warmup = 500,
    seed = 200350623, 
    cores = 4,
    data = data,
    stanvars = stanvars
    )
          
  rand_int
          
}
        
# Random Slope and Intercept Model
        
fit_rand_int_slope <- function(tau) {
          
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_slope <- prior(normal(0, tau), class = "b")
          
  rand_int_slope <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 + experience | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_slope,
    family = poisson(),
    iter = 3000,
    seed = 200350623, 
    warmup = 500,
    cores = 4,
    data = data,
    stanvars = stanvars
    )
          
  rand_int_slope
          
}
        
tau_val <- c(1e-2, 1e-1, 1, 5, 10)

results_NH <- lapply(tau_val, fit_non_hier) 
names(results_NH) <- paste0(tau_val, "nh")
saveRDS(results_NH, "results/operators/models/non-hierarchical.rds")
rm(results_NH)

results_rand_int <- lapply(tau_val, fit_rand_int)
names(results_rand_int) <- paste0(tau_val, "rand_int")
saveRDS(results_rand_int, "results/operators/models/rand_int.rds")
rm(results_rand_int)

# After noticing that this model below prefers lower regularization
tau_rand_int_slope <- seq(5, 20, 3)
results_rand_int_slope <- lapply(tau_rand_int_slope, fit_rand_int_slope)
names(results_rand_int_slope) <- paste0(tau_rand_int_slope, "rand_int_slope")
saveRDS(results_rand_int_slope, "results/operators/models/rand_int_slope.rds")
rm(results_rand_int_slope)