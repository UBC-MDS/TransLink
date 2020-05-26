library(brms)
library(tidyverse)
library(parallel)

# This script just stores relevant helper functions for the fitting of the Bayesian
# models. Not actually ran in the pipeline (besides being sourced by 2_bayesian-models.R)

# Non-Hierarchical Bayesian Model

#' This function fits a non-hierarchical fully Bayesian regression model.
#' This is the Bayesian equivalent of the basic GLM that we fit previously.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples 
#' fit_non_hier(tau = 0.1, data = train)
fit_non_hier <- function(tau, data) {
  
  # Check for correct values of tau.
  if (!is.numeric(tau) | tau < 0) {
    stop("Invalid tau value. Tau must be positive and a number.")
  }
  
  # Check that proper column names exist in training data.
  if (any(c("experience", "cost_centre", "number_incidents", "hours_worked_div_1957") %in% colnames(data) == FALSE)) {
    stop("Specific columns are missing from the training data in the Bayesian model fit. Recheck column names!")
  }
  
  stanvars <- stanvar(tau, name = "tau")    
  prior_non_hier <- prior(normal(0, tau), class = "b")
  
  non_hierarchial <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + cost_centre + offset(log(hours_worked_div_1957)),
    prior = prior_non_hier,
    family = poisson(),
    chains = detectCores() - 2,
    iter = 4000,
    warmup = 500, 
    seed = 200350623, 
    cores = detectCores() - 2,
    data = data,
    thin = 5,
    stanvars = stanvars,
    control = list(adapt_delta = 0.95) 
  )
  
  non_hierarchial
  
}


# Random Intercept Model

#' This function fits a random effect (i.e. random intercept) Bayesian model.
#' In other words, this model allows the intercept of the regression to vary
#' between groups.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples
#' fit_rand_int(tau = 8, data = train)
fit_rand_int <- function(tau, data) {
  
  # Check for correct values of tau.
  if (!is.numeric(tau) | tau < 0) {
    stop("Invalid tau value. Tau must be positive and a number.")
  }
  
  # Check that proper column names exist in training data.
  if (any(c("experience", "cost_centre", "number_incidents", "hours_worked_div_1957") %in% colnames(data) == FALSE)) {
    stop("Specific columns are missing from the training data in the Bayesian model fit. Recheck column names!")
  }
  
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_int <- prior(normal(0, tau), class = "b")
  
  rand_int <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_int,
    family = poisson(),
    iter = 4000,
    warmup = 500,
    chains = detectCores() - 2,
    seed = 200350623, 
    cores = detectCores() - 2,
    thin = 5,
    data = data,
    stanvars = stanvars, 
    control = list(adapt_delta = 0.95) 
  )
  
  rand_int
  
}

# Random Slope and Intercept Model

#' This function fits a random effect AND random slope model (experience) in a fully Bayesian
#' framework. In other words, it allows for the intercepts and the slopes to vary 
#' between groups.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples
#' fit_rand_int_slope(tau = 13, data = train)
fit_rand_int_slope <- function(tau, data) {
  
  # Check for correct values of tau.
  if (!is.numeric(tau) | tau < 0) {
    stop("Invalid tau value. Tau must be positive and a number.")
  }
  
  # Check that proper column names exist in training data.
  if (any(c("experience", "cost_centre", "number_incidents", "hours_worked_div_1957") %in% colnames(data) == FALSE)) {
    stop("Specific columns are missing from the training data in the Bayesian model fit. Recheck column names!")
  }
  
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_slope <- prior(normal(0, tau), class = "b")
  
  rand_int_slope <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 + experience | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_slope,
    family = poisson(),
    iter = 4000,
    chains = detectCores() - 2,
    seed = 200350623, 
    warmup = 500,
    thin = 10,
    cores = detectCores() - 2,
    data = data,
    stanvars = stanvars, 
    control = list(adapt_delta = 0.95) 
  )
  
  rand_int_slope
  
}
