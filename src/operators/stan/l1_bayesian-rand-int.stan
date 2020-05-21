data {
  int<lower=0> N_total;
  int<lower=0> num_cat_exp;
  int<lower=0> J;
  int<lower=0, upper=J> cost_centre[N_total];
  real<lower=0> tau;
  matrix[N_total, num_cat_exp] X;
  vector<lower=0>[N_total] offset;
  int<lower=0> y[N_total];
}
  
parameters {
  vector[J] alpha;
  vector[num_cat_exp] beta;
  real mu_alpha;
  real<lower=0> sigma_alpha;
}

transformed parameters {
        
  real<lower=0> mu[N_total];
  
  for (i in 1:N_total) {
    mu[i] = exp(alpha[cost_centre[i]] + X[i, ]*beta + log(offset[i]));
  }
}
  
model {
  
  beta ~ double_exponential(0, 1/tau);
  alpha ~ normal(mu_alpha, sigma_alpha);
  sigma_alpha ~ exponential(0.2);
    
  for (i in 1:N_total) {
    y[i] ~ poisson(mu[i]) T[1, ];
  }
}

generated quantities {
  vector[N_total] log_lik;
  for (n in 1:N_total) {
    log_lik[n] = poisson_lpmf(y[n] | mu[n]) - log_diff_exp(0, poisson_lpmf(0 | mu[n]));
  }    
}


