#!/usr/bin/env python
# coding: utf-8
"""This script creates a csv file containing incident coordinates. 
It takes the street and city names from "2020 Collisions- Preventable 
and Non Preventable UBC Set Without Claim Number.xlsx" and converts them to
formatted addresses, including long and lat of the incidents. Assumes `get-data.py`
is run before. A google maps API key is also required. 

Usage: append_coordinates.py --input_file_path=<input_file_path> --output_file_path=<output_file_path> --api_key=<api_key>

Options:

--input_file_path=<input_file_path>           A file path for street and city names of the incident locations.
--output_file_path=<output_file_path>   A file path for coordinates of the incident locations.
--api_key=<api_key>   The google maps API key to make request. 

Example: 
python src/append_coordinates.py \
    --input_file "data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx" \
    --output_file "data/processed_data/collision_locations_with_coordinates.csv" \
    --api_key ""
"""
import pandas as pd
from docopt import docopt
import glob
import os
import googlemaps
from pathlib import Path

opt = docopt(__doc__)


def get_location(google_maps_client, street2, street1, city, province = "BC"):
    '''It creates longtitude, the lattitude and formatted address of the given street, city names.
    '''
    query_format = '{0} & {1}, {2}, {3}'
    query = query_format.format(street1, street1, city, province)
    geocode_result = google_maps_client.geocode(query)
    address = geocode_result[0]['formatted_address']
    geometry = geocode_result[0]['geometry']['location']
    return{'lat':geometry['lat'], 'long':geometry['lng'], "address" : address}

def create_dirs(file_path_list):
    for path in file_path_list:
        Path(os.path.dirname(path)).mkdir(parents=True, exist_ok=True)

def main(input_file_path, output_file_path, api_key):
    
    location_extract_file_path= 'temp/locations.csv'
    #  create the parent dirs if they don't exist.
    create_dirs([location_extract_file_path,output_file_path])


    try:
        collision_preventable = pd.read_excel(input_file_path, skiprows=  3)
    except:
        raise ValueError("Input file does not exist or is not excel spreadsheet.")
    collision_locations = collision_preventable[['Loss Location At', 'Loss Location On', 'City of Incident', 'APTA']]
    collision_locations.columns = ['street1', 'street2', 'city', 'desc']
    collision_locations = collision_locations.applymap(lambda x: str(x).title())
    collision_locations.to_csv(location_extract_file_path, index=False)
    location_df = pd.read_csv(location_extract_file_path)
    if(len(glob.glob(output_file_path)) == 0):
        target_location_df = pd.read_csv(location_extract_file_path)
        target_location_df["lat"] = None
        target_location_df["long"] = None
        target_location_df["formatted_address"] = None
    else:
        # if output_file already exists, just read the coordinates.
        target_location_df = pd.read_csv(output_file_path) 
        columns_list = ['lat', 'long', 'formatted_address', 'desc','street1', 'street2', 'city']
        if not set(columns_list).issubset(target_location_df.columns):
            raise ValueError (" Target data path should contain all of: " , columns_list)
    
    google_maps_client = googlemaps.Client(key=api_key)
    
    for index, row in location_df.iterrows():
        if(target_location_df.loc[index,'lat'] != None):
            print("Processing ", (index+1), "/", location_df.shape[0], "Row already has coordinates, skipping the request.")
        else:
            print("Processing ", (index+1), "/", location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
            try:
                location = get_location(google_maps_client, row['street1'], row['street2'], row['city'])
                target_location_df.loc[index,'lat'] = location['lat']
                target_location_df.loc[index,'long'] = location['long']
                target_location_df.loc[index,'formatted_address'] = location['address']
            except Exception as e:
                print(str(e))
                print("Error in processing ", (index+1), "/", location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
    
        if(index % 40 == 0):
            target_location_df.to_csv(output_file_path, index = False)

    target_location_df.to_csv(output_file_path, index = False)
    os.remove(location_extract_file_path)

if __name__ == "__main__":
    main(opt["--input_file_path"], opt["--output_file_path"], opt["--api_key"])
