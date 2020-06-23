#!/usr/bin/env python
# coding: utf-8

"""
This script takes two datasets as input and then merges the dataset to produce a final dataset that includes the latitude and longitude informatiion of all the locations where incidents took place. Final dataset is stored in Translink Raw data.  This script assumes that 'get-data.py' is run before.

Usage: merge_claims.py --input_claim_path=<input_claims> --input_location_path=<input_locations> --output_path=<outputs>

Example:
python src/merge_claims.py \
--input_claim_path "data/TransLink Raw Data/claim_vehicle_employee_line.csv" \
--input_location_path "data/TransLink Raw Data/collision_locations_with_coordinates.csv" \
--output_path "data/TransLink Raw Data/merged_collision.xlsx"

Options:
--input_claim_path=<input_claims> A file for claim data.
--input_location_path=<input_locations> A file for location data.
--output_path=<outputs> Merged data file.
"""

from docopt import docopt
import pandas as pd
import numpy as np

opt = docopt(__doc__)

def main(input_claim_path,input_location_path, output_path):
	"""
	This function merges two dataframes based on claim id in order to combine claims data with location data of all the incidents

	Parameters
	--------------
	input_claim_path A file for claim data.
	input_location_path A file for location data.
	output_path Merged data file.

	Returns
	--------
	None
	"""

	claim_vehicle_data = pd.read_csv(input_claim_path)

	collision_location_data = pd.read_csv(input_location_path)

	merged_data = pd.merge(claim_vehicle_data, collision_location_data,on=['claim_id'], how='inner')

	merged_data.to_excel(output_path , index=False)

if __name__ == "__main__":
	main(opt["--input_claim_path"], opt["--input_location_path"], opt["--output_path"])



