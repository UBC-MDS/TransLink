data {
  int<lower=0> N_total;
  int<lower=0> num_cat_exp;
  int<lower=0> num_cat_cost;
  real<lower=0> tau;
  int<lower=0> K;
  matrix[N_total, K] X;
  vector<lower=0>[N_total] offset;
  int<lower=0> y[N_total];
}
  
parameters {
  real alpha;
  vector[K] beta;
}

transformed parameters {
        
  real<lower=0> mu[N_total];
  
  for (i in 1:N_total) {
    mu[i] = exp(alpha + X[i, ]*beta + log(offset[i]));
  }
}
  
model {
  
  beta ~ double_exponential(0, 1/tau);
    
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


