#!/usr/bin/env python
# coding: utf-8
"""This script takes different data sets as input.
It cleans different data sets by removing extra rows from the top of the dataset.
Cleaned data is stored by creating a folder named "Clean_data". This script assumes that 'get-data.py' is run before.
Usage: clean_data.py --input_speed_path=<input_speed_path>  --input_prev_path=<input_prev_path>  --input_nonprev_path=<input_nonprev_path>  --input_incident_path=<input_incident_path> --output_speed_path=<output_speed_path>  --output_prev_path=<output_prev_path>  			--output_nonprev_path=<output_nonprev_path>  --output_incident_path=<output_incident_path> 

Options:
--input_speed_path=<input_speed_path> A file path for speed data
--input_prev_path=<input_prev_path> A file path for data of preventable incidents
--input_nonprev_path=<input_nonprev_path> A file path for data of non preventable incidents
--input_incident_path=<input_incident_path> A file path for incident data
--output_speed_path=<output_speed_path>   A file path to store the speed data
--output_prev_path=<output_prev_path>   A file path to store the data of preventable incidents
--output_nonprev_path=<output_nonprev_path>   A file path to store the data of non preventable incidents
--output_incident_path=<output_incident_path>   A file path to store the incident data

Example: 
python src/clean_data.py \
--input_speed_path "data/TransLink Raw Data/Speed_performance_data.csv" \
--input_prev_path "data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx" \
--input_nonprev_path "data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx" \
--input_incident_path "data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx" \
--output_speed_path "data/Clean_data/Speed performance data.csv" \
--output_prev_path "data/Clean_data/Collision_preventable.csv" \
--output_nonprev_path "data/Clean_data/Collision_non_preventable.csv" \
--output_incident_path "data/Clean_data/Incident_operator.csv" 

"""

from docopt import docopt
import pandas as pd

opt = docopt(__doc__)

def main(input_speed_path, input_prev_path, input_nonprev_path, input_incident_path, output_speed_path, output_prev_path, output_nonprev_path, output_incident_path):
    """ 
    This function removes unwanted rows from the row data and stores the clean data at the specified place
    
    Parameters
    ----------
    input_speed_path
	 A file path for speed data
    input_prev_path
	A file path for data of preventable incidents
    input_nonprev_path
	A file path for data of non preventable incidents
    input_incident_path
	A file path for incident data
    output_speed_path
	   A file path to store the speed data
    output_prev_path
	   A file path to store the data of preventable incidents
    output_nonprev_path
	   A file path to store the data of non preventable incidents
    output_incident_path
	   A file path to store the incident data
    
    Returns
    ---------
    None

    """
	Speed_performance = pd.read_csv(input_speed_path, low_memory=False)

	Collision_preventable = pd.read_excel(input_prev_path, skiprows=  3)

	Collision_non_preventable = pd.read_excel(input_nonprev_path, skiprows=  3, sheet_name=1)

	Incident_operator = pd.read_excel(input_incident_path, sheet_name=1)

	Speed_performance.to_csv(output_speed_path, index=False)
	Collision_preventable.to_csv(output_prev_path, index=False)
	Collision_non_preventable.to_csv(output_nonprev_path, index=False)
	Incident_operator.to_csv(output_incident_path, index=False)

if __name__ == "__main__":
	main(opt["--input_speed_path"], opt["--input_prev_path"], opt["--input_nonprev_path"], opt["--input_incident_path"],\
 opt["--output_speed_path"], opt["--output_prev_path"], opt["--output_nonprev_path"], opt["--output_incident_path"])




