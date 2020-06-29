# The Makefile - use to generate EVERYTHING that was done in this entire analysis
# Before you do this, CTRL + F for "..." and replace with the required keys Google Maps Geocoding API Key!
# Assumes that a folder called "data" exists in the root of the repository containing the raw data
# with exactly the same names as what was originally on S3. This folder can be obtained from AWS S3 or 
# potentially from a local copy that has been (hopefully) stored somewhere.

# This is the all command - use to recreate this entire analysis!
all: results/claim_analysis/report/claim_colour_df.xlsx results/claim_analysis/report/verb_colour_df.xlsx results/ml_model/report/class1_shap.csv results/ml_model/report/final_fitted.pickle results/ml_model/full_data.csv results/operators/data/train.csv results/operators/models/best-bayes-model.rds results/operators/report-tables/posterior_samples.rds results/operators/report-tables/validation-results.rds

#--------------Operator Analysis-------------
# Wrangle the data, split into train and test

results/operators/data/train.csv results/operators/data/test.csv: src/operators/R/0_wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx
	Rscript src/operators/R/0_wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx results/operators/data

# Run basic GLM

results/operators/report-tables/basic-glm-aic_table.rds results/operators/models/basic-glm.rds: src/operators/R/1_basic-glm.R results/operators/data/train.csv
	Rscript src/operators/R/1_basic-glm.R results/operators/data/train.csv results/operators/report-tables results/operators/models

# Run Bayesian models

results/operators/report-tables/loo-model-cv-summary-bayes.rds results/operators/models/all-bayes-models.rds results/operators/models/best-bayes-model.rds: src/operators/R/2_bayesian-models.R src/operators/R/helper_scripts/bayesian-fit.R results/operators/data/train.csv
	Rscript src/operators/R/2_bayesian-models.R results/operators/data/train.csv results/operators/report-tables results/operators/models results/operators/models

# Validate all models

results/operators/report-tables/validation-results.rds results/operators/bayes-diagnostics/acf_plot_globals.png results/operators/bayes-diagnostics/summary_stats_bayes.rds results/operators/bayes-diagnostics/trace_plot_globals.png: src/operators/R/3_validation.R results/operators/models/basic-glm.rds results/operators/models/best-bayes-model.rds results/operators/data/test.csv
	Rscript src/operators/R/3_validation.R --path_to_glm=results/operators/models/basic-glm.rds --path_to_bayesian=results/operators/models/best-bayes-model.rds results/operators/data/test.csv results/operators/report-tables results/operators/bayes-diagnostics

# Fit the final model on the entire dataset, and generate relevant figures for report

results/operators/models/final-model.rds results/operators/report-tables/posterior_samples.rds: src/operators/R/4_final-model.R src/operators/R/helper_scripts/bayesian-fit.R results/operators/data/train.csv results/operators/data/test.csv results/operators/models/best-bayes-model.rds
	Rscript src/operators/R/4_final-model.R results/operators/data/train.csv results/operators/data/test.csv results/operators/models/best-bayes-model.rds results/operators/models results/operators/report-tables

#-------------ML-Model--------------------------

# Get weather data and wrangle exisiting data

results/ml_model/data/cleaned_accident_data.rds results/ml_model/data/stations_per_loc_day.rds results/ml_model/data/stations_per_loc_hour.rds: src/ml_model/R/0_get-weather-data.R data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv data/TransLink\ Raw\ Data/Preventable\ and\ Non\ Preventable_tabDelimited.txt data/TransLink\ Raw\ Data/employee_experience_V2.csv
	Rscript src/ml_model/R/0_get-weather-data.R data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv data/TransLink\ Raw\ Data/Preventable\ and\ Non\ Preventable_tabDelimited.txt data/TransLink\ Raw\ Data/employee_experience_V2.csv results/ml_model/data
	
# Get training and testing data sets

results/ml_model/data/final_data_combined.csv results/ml_model/data/train.csv results/ml_model/data/test.csv: src/ml_model/R/1_sample.R results/ml_model/data/cleaned_accident_data.rds results/ml_model/data/stations_per_loc_day.rds results/ml_model/data/stations_per_loc_hour.rds data/TransLink\ Raw\ Data/Scheduled_Actual_services_2019.csv
	Rscript src/ml_model/R/1_sample.R results/ml_model/data/cleaned_accident_data.rds results/ml_model/data/stations_per_loc_hour.rds results/ml_model/data/stations_per_loc_day.rds data/TransLink\ Raw\ Data/Scheduled_Actual_services_2019.csv results/ml_model/data

# Validate model

results/ml_model/models/final_model_after_optimization.pickle: src/ml_model/python/2_model_optimizer.py results/ml_model/data/train.csv results/ml_model/data/test.csv data/TransLink\ Raw\ Data/Bus_spec.csv
	python src/ml_model/python/2_model_optimizer.py --train_file_path=results/ml_model/data/train.csv --bus_file_path=data/TransLink\ Raw\ Data/Bus_spec.csv --test_file_path=results/ml_model/data/test.csv --path_out=results/ml_model/models
	
# Fit final model and save outputs

results/ml_model/report/class1_shap.csv results/ml_model/report/final_fitted.pickle results/ml_model/report/full_data.csv: src/ml_model/python/3_model_generator.py results/ml_model/data/train.csv results/ml_model/data/test.csv data/TransLink\ Raw\ Data/Bus_spec.csv results/ml_model/models/final_model_after_optimization.pickle
	python src/ml_model/python/3_model_generator.py --train_file_path=results/ml_model/data/train.csv --bus_file_path=data/TransLink\ Raw\ Data/Bus_spec.csv --test_file_path=results/ml_model/data/test.csv --model_file_path=results/ml_model/models/final_model_after_optimization.pickle --path_out=results/ml_model/report

#------------------Claim Descriptions-----------------

# Merging data to include latitudes and longitudes of places

results/claim_analysis/data/merged_collision.xlsx: data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv results/processed_data/collision_locations_with_coordinates.csv src/claim_analysis/merge_claims.py
	python src/claim_analysis/merge_claims.py \
--input_claim_path "data/TransLink Raw Data/claim_vehicle_employee_line.csv" \
--input_location_path "results/processed_data/collision_locations_with_coordinates.csv" \
--output_path "results/claim_analysis/data"

# Preprocessing data to create tables required for the dashboard

results/claim_analysis/report/verb_colour_df.xlsx results/claim_analysis/report/claim_colour_df.xlsx: results/claim_analysis/data/merged_collision.xlsx src/claim_analysis/claim_description.py
	python src/claim_analysis/claim_description.py \
--input_merged_path "results/claim_analysis/data/merged_collision.xlsx" \
--color_path "src/claim_analysis/data.json" \
--output_path "results/claim_analysis/report" 

#------------------Claim Analysis-----------------

# Prepering data that will be appear in the map

results/processed_data/collision_with_claim_and_employee_info.csv: src/interactive_map/prepare_data.py data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv data/TransLink\ Raw\ Data/Preventable\ and\ Non\ Preventable_tabDelimited.txt data/TransLink\ Raw\ Data/employee_experience_V2.csv
	python src/interactive_map/prepare_data.py --claims_file_path "data/TransLink Raw Data/claim_vehicle_employee_line.csv" --collisions_file_path "data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt" --employee_file_path "data/TransLink Raw Data/employee_experience_V2.csv" --output_file_path "results/processed_data/collision_with_claim_and_employee_info.csv"
	
# Append the longitudes and latitudes of each location, required google maps geocoding api key

results/processed_data/collision_locations_with_coordinates.csv: src/interactive_map/append_coordinates.py results/processed_data/collision_with_claim_and_employee_info.csv
	python src/interactive_map/append_coordinates.py --input_file results/processed_data/collision_with_claim_and_employee_info.csv --output_file_path results/processed_data/collision_locations_with_coordinates.csv --api_key=AIzaSyD0z4QGi9X9zo9o2v9DWVMnjA90YOT2ElM

#----------------CLEAN Command---------------------

clean:
	rm -rf results/claim_analysis/report/*
	rm -rf results/claim_analysis/data/*
	rm -rf results/processed_data/collision_with_claim_and_employee_info.csv
	rm -rf results/processed_data/collision_locations_with_coordinates.csv
	rm -rf results/ml_model/report/*
	rm -rf results/ml_model/models/*
	rm -rf results/ml_model/data/*
	rm -rf results/operators/data*
	rm -rf results/operators/bayes-diagnostics/*
	rm -rf results/operators/models/*
	rm -rf results/operators/report-tables/*
