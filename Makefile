#`Pull in data from S3. Replace ... with your access key and secret key.

'data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx' 'data/TransLink Raw Data/claim_vehicle_employee_line.csv' 'data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx' 'data/TransLink Raw Data/pedestrain_claims.csv' 'data/TransLink Raw Data/preventable_NonPreventable_claims.csv' data/TransLink Raw Data/Speed performance data.csv': src/get-data.py
	python src/get-data.py --access_key=... --secret_key=...

#--------------Operator Analysis-------------
# Possibly delete if ML-model works!
# Wrangle the data, split into train and test

data/operators/train.csv data/operators/test.csv: 'src/operators/R/0_wrangle.R data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx'
	Rscript src/operators/R/0_wrangle.R 'data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx' data/operators

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

#--------------Time Series Weather Analysis-------------
# Possibly delete if ml-model works!
data/weather-time/time-series-final-complete.rds data/weather-time/time_series_weather.rds data/weather-time/train.csv data/weather-time/test.csv: src/weather-time/R/0_get-weather-data.R 'data/TransLink Raw Data/claim_vehicle_employee_line.csv' data/TransLink Raw Data/preventable_NonPreventable_claims.csv'
	Rscript src/weather-time/R/0_get-weather-data.R 'data/TransLink Raw Data/claim_vehicle_employee_line.csv' data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt' data/weather-time

#-------------ML-Model--------------------------

# Get weather data and wrangle exisiting data

data/ml-model/cleaned_accident_data.rds data/ml-model/stations_per_loc_day.rds data/ml-model/stations_per_loc_hour.rds: src/ml-model/R/0_get-weather-data.R 'data/TransLink Raw Data/claim_vehicle_employee_line.csv' 'data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt' 'data/TransLink Raw Data/employee_experience_V2.csv'
	Rscript src/ml-model/R/0_get-weather-data.R 'data/TransLink Raw Data/claim_vehicle_employee_line.csv' 'data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt' 'data/TransLink Raw Data/employee_experience_V2.csv' data/ml-model
	
# Get training and testing data sets

data/ml-model/final_data_combined.csv data/ml-model/train.csv data/ml-model/test.csv: src/ml-model/R/1_sample.R data/ml-model/cleaned_accident_data.rds data/ml-model/stations_per_loc_day.rds data/ml-model/stations_per_loc_hour.rds 'data/TransLink Raw Data/Scheduled_Actual_services_2019.csv'
	Rscript src/ml-model/R/1_sample.R data/ml-model/cleaned_accident_data.rds data/ml-model/stations_per_loc_day.rds data/ml-model/stations_per_loc_hour.rds 'data/TransLink Raw Data/Scheduled_Actual_services_2019.csv' data/ml-model

#------------------Claim Analysis-----------------

# Cleaning files required for wrangling data

data/Clean_data/Speed performance data.csv data/Clean_data/Collision_preventable.csv data/Clean_data/Collision_non_preventable.csv data/Clean_data/Incident_operator.csv: data/TransLink Raw Data/Speed_performance_data.csv data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx src/clean_data.py
python src/clean_data.py \
--input_speed_path "data/TransLink Raw Data/Speed_performance_data.csv" \
--input_prev_path "data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx" \
--input_nonprev_path "data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx" \
--input_incident_path "data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx" \
--output_speed_path "data/Clean_data/Speed performance data.csv" \
--output_prev_path "data/Clean_data/Collision_preventable.csv" \
--output_nonprev_path "data/Clean_data/Collision_non_preventable.csv" \
--output_incident_path "data/Clean_data/Incident_operator.csv" 

# Merging data to include  latitudes and longitudes of places

data/TransLink Raw Data/merged_collision.xlsx: data/TransLink Raw Data/claim_vehicle_employee_line.csv data/TransLink Raw Data/collision_locations_with_coordinates.csv src/merge_claims.py
python src/merge_claims.py \
--input_claim_path "data/TransLink Raw Data/claim_vehicle_employee_line.csv" \
--input_location_path "data/TransLink Raw Data/collision_locations_with_coordinates.csv" \
--output_path "data/TransLink Raw Data/merged_collision.xlsx"

# Preprocessing data to create tables required for the dashboard

data/TransLink Raw Data/verb_colour_df.xlsx data/TransLink Raw Data/Claim_colour_df.xlsx: data/TransLink Raw Data/merged_collision.xlsx src/claim_description.py
python src/claim_description.py \
--input_merged_path "data/TransLink Raw Data/merged_collision.xlsx" \
--color_path "data/TransLink Raw Data/data.json" \
--output_verb_color_df "data/TransLink Raw Data/verb_colour_df.xlsx" \
--output_noun_color_df "data/TransLink Raw Data/Claim_colour_df.xlsx"



