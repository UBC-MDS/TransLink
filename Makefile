#`Pull in data from S3. Replace ... with your access key and secret key.

data/TransLink\ Raw\ Data/2020\ Collisions-\ Preventable\ and\ Non\ Preventable\ UBC\ Set\ Without\ Claim\ Number.xlsx data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx data/TransLink\ Raw\ Data/pedestrain_claims.csv data/TransLink\ Raw\ Data/preventable_NonPreventable_claims.csv data/TransLink\ Raw\ Data/Speed\ performance\ data.csv: src/get-data.py
	python src/get-data.py --access_key=... --secret_key=...

#--------------Operator Analysis-------------

# Wrangle the data, split into train and test

data/operators/train.csv data/operators/test.csv: src/operators/R/0_wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx
	Rscript src/operators/R/0_wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx data/operators

# Run basic GLM

results/operators/report-tables/basic-glm-aic_table.rds results/operators/models/basic-glm.rds: src/operators/R/1_basic-glm.R data/operators/train.csv
	Rscript src/operators/R/1_basic-glm.R data/operators/train.csv results/operators/report-tables/basic-glm-aic_table.rds results/operators/models/basic-glm.rds

# Run Bayesian models

results/operators/report-tables/loo-model-cv-summary-bayes.rds results/operators/models/all-bayes-models.rds results/operators/models/best-bayes-model.rds: src/operators/R/2_bayesian-models.R src/operators/R/helper_scripts/bayesian-fit.R data/operators/train.csv
	Rscript src/operators/R/2_bayesian-models.R data/operators/train.csv results/operators/report-tables/loo-model-cv-summary-bayes.rds results/operators/models/all-bayes-models.rds results/operators/models/best-bayes-model.rds

# Validate all models

results/operators/report-tables/validation-results.rds results/operators/bayes-diagnostics/acf_plot_globals.png results/operators/bayes-diagnostics/summary_stats_bayes.rds results/operators/bayes-diagnostics/trace_plot_globals.png: src/operators/R/3_validation.R results/operators/models/basic-glm.rds results/operators/models/best-bayes-model.rds data/operators/test.csv
	Rscript src/operators/R/3_validation.R --path_to_glm=results/operators/models/basic-glm.rds --path_to_bayesian=results/operators/models/best-bayes-model.rds data/operators/test.csv results/operators/report-tables/validation-results.rds results/operators/bayes-diagnostics

# Fit the final model on the entire dataset, and generate relevant figures for report

results/operators/models/final-model.rds results/operators/report-tables/posterior_samples.rds: src/operators/R/4_final-model.R src/operators/R/helper_scripts/bayesian-fit.R data/operators/train.csv data/operators/test.csv results/operators/models/best-bayes-model.rds
	Rscript src/operators/R/4_final-model.R data/operators/train.csv data/operators/test.csv results/operators/models/best-bayes-model.rds results/operators/models/final-model.rds results/operators/report-tables/posterior_samples.rds
