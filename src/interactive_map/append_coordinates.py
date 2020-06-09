#!/usr/bin/env python
# coding: utf-8

"""This script creates a csv file containing the coordination of the incidents. 
It takes the street names and the city names and convert them to formatted addresses
including long and lat of the incidents. Assumes `get-data.py` and `prepare_data.py`
are run before. A google maps API key is also required. 

Usage: append_coordinates.py --input_file_path=<input_file_path> --output_file_path=<output_file_path> --api_key=<api_key>

Options:

--input_file_path=<input_file_path>     A file path containing the street and city names of the incident locations.
--output_file_path=<output_file_path>       A file path for coordinates of the incident locations.
--api_key=<api_key>   The google maps API key to make request. 

Example: 
python src/interactive_map/append_coordinates.py \
    --input_file "results/processed_data/collision_with_claim_and_employee_info.csv" \
    --output_file "results/processed_data/collision_locations_with_coordinates.csv" \
    --api_key ""
"""

import pandas as pd
import numpy as np
from docopt import docopt
import glob
import os
import googlemaps
from pathlib import Path

opt = docopt(__doc__)



def get_location(google_maps_client, street1, street2, city, province="BC"):
    '''
    It creates longitude, latitude, and formatted address of the given 2 streets
    that intersect and the city name of these streets. It also requires the province
    name of the incident's location. To speed up the process, it first looks at the
    cache file and if it doesn't exist in the cache file, then it requests google maps API.  

    Parameters:
    google_maps_client (googlemaps.client.Client): client to make queries to Google GeoCoding API
    street1 (str): The name of the first street of the intersection point. 
    street2 (str): The name of the second street of the intersection point.
    city (str): The city that the incident happened. 
    province (str): The province that the incident happened.

    Returns:
    locations (dict):  A dictionary contains latitude, longitude, and the formatted 
    address of the incident's location.


    Example: get_location("Dunsmuir St", "Granville St", "Vancouver") = 
    {'lat': 49.2836214,
    'long': -123.1164681,
    'address': 'Granville St & Dunsmuir St, Vancouver, BC V7Y 1K4, Canada'}

    '''
    query_format = '{0} & {1}, {2}, {3}'
    query = query_format.format(street1, street2, city, province)
    # look up the cached file to speed up the process
    coordinate_cache_df = pd.read_csv(
        "results/processed_data/coordinate_cache.csv")
    cached_coordinates = coordinate_cache_df.loc[coordinate_cache_df['query'] == query]
    if (cached_coordinates.empty):
        location = get_location_from_google_maps(google_maps_client, query)
        location["source"] = "google"
        # write it to cache too
    else:
        location_from_cache = dict(cached_coordinates.iloc[0])
        location = {'lat': location_from_cache['lat'], 'long': location_from_cache['long'],
                    "address": location_from_cache['formatted_address'], "source": "cache"}

    return location


def get_location_from_google_maps(google_maps_client, query):
    '''
    It is a helper function to create longitude, latitude, and formatted address
    of the given 2 streets that intersect and the city name of these streets to
    request google maps API. It also requires the province name of the incident's
    location.  

    Parameters:
    google_maps_client (): 
    query (str): The address of the incident in the 'street1 & street2, city, province' format. 

    Returns:
    location (dict): A dictionary contains latitude, longitude, and the formatted 
    address of the incident's location.


    Example: get_location("Dunsmuir St & Granville St, Vancouver") = 
    {'lat': 49.2836214,
    'long': -123.1164681,
    'address': 'Granville St & Dunsmuir St, Vancouver, BC V7Y 1K4, Canada'}

    '''
    geocode_result = google_maps_client.geocode(query)
    address = geocode_result[0]['formatted_address']
    geometry = geocode_result[0]['geometry']['location']
    location  = {'lat': geometry['lat'], 'long': geometry['lng'], "address": address}
    return location


def create_dirs_if_not_exists(file_path_list):
    """
    It creates directories if they don't aldready exist. 

    Parameters:
    file_path_list (list): A list of paths to be created if they don't exist.
    """
    for path in file_path_list:
        Path(os.path.dirname(path)).mkdir(parents=True, exist_ok=True)


def check_if_file_does_not_exists(file_path):
    return len(glob.glob(file_path)) == 0


def printProgressBar(iteration, total, prefix='Progress:', suffix='Completed', decimals=1, length=50, fill='█', printEnd="\r"):
    """
    A helper function to follow the process while getting the long and lat of the locations. 
    Call in a loop to create terminal progress bar.

    Parameters:
    ----------
        iteration       - Required  : current iteration (Int)
        total           - Required  : total iterations (Int)
        prefix          - Optional  : prefix string (Str)
        suffix          - Optional  : suffix string (Str)
        decimals        - Optional  : positive number of decimals in percent complete (Int)
        length          - Optional  : character length of bar (Int)
        fill            - Optional  : bar fill character (Str)
        printEnd        - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 *
                                                     (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print('\r%s |%s| %s%% %s' % (prefix, bar, percent, suffix), end=printEnd)
    # Print New Line on Complete
    if iteration == total:
        print()

def main(input_file_path, output_file_path, api_key):
    '''
    It takes a path for the input file and creates longitude, latitude, and formatted
    addresses of the locations of the incidents and then writes the resulting data frame
    to the given output file path. It requires a valid google maps API key.

    Parameters:
    input_file_path (str): A path of the input file that contains street and city information.
    output_file_path (str): A file path for resulting dataset.
    '''

    # create given output file if it doesn't exist
    create_dirs_if_not_exists([output_file_path])

    if(check_if_file_does_not_exists(output_file_path)):
        # get cleaned data
        try:
            target_location_df = pd.read_csv(input_file_path)
        except:
            raise ValueError("The input file does not exist or is not tab seperated.")
        # target_location_df = get_clean_data_v2(input_file_path)

        # prepare data frame
        target_location_df["lat"] = None
        target_location_df["long"] = None
        target_location_df["formatted_address"] = None
        target_location_df.to_csv(output_file_path, index=False)

    # read current output_file
    target_location_df = pd.read_csv(output_file_path)
    # check whether it has all required columns
    columns_list = ['employee_id', 'hire_date', 'claim_id', 'paid_cost$', 'day_of_week',
       'claim_status', 'line_no', 'bus_no', 'bus_fuel_type',
       'bus_carry_capacity', 'loss_location_at', 'preventable_nonpreventable',
       'loss_location_on', 'city_of_incident', 'apta_desc',
       'asset_vehicle_year', 'asset_manufacturer', 'time_of_loss', 'loss_date',
       'experience_in_months', 'lat', 'long', 'formatted_address']
    if not set(columns_list).issubset(target_location_df.columns):
        raise ValueError(
            " Target data path should contain all of: ", columns_list)

    try:
        google_maps_client = googlemaps.Client(key=api_key)
    except:
        raise ValueError("You should use a valid Google maps API key.")
    
    # to follow whether the process is working properly.
    error_count = 0
    cache_hit_count = 0
    skipped_count = 0
    total = target_location_df.shape[0]
    suffix_format = "Completed {0}/{1} Errors:{2} CacheHit:{3} Skipped:{4}"
    # to see the process of the requests
    printProgressBar(0, total, suffix=suffix_format.format(0, total, error_count, cache_hit_count, skipped_count))
    for index, row in target_location_df.iterrows():
        suffix = "Errors:{1} CacheHit:{2} Skipped:{3}"
        printProgressBar(index, total, suffix=suffix_format.format(index, total, error_count, cache_hit_count, skipped_count))
        current_lat_value = target_location_df.loc[index, 'lat']
        if((current_lat_value == None) | (np.isnan(current_lat_value))):
            # print("Processing ", (index+1), "/", target_location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
            try:
                location = get_location(google_maps_client, row['loss_location_at'], row['loss_location_on'], row['city_of_incident'])
                if(location["source"] == "cache"):
                    cache_hit_count += 1
                target_location_df.loc[index, 'lat'] = location['lat']
                target_location_df.loc[index, 'long'] = location['long']
                target_location_df.loc[index, 'formatted_address'] = location['address']
            except Exception as e:
                error_count += 1
                error_message = 'Error in processing {0}/{1}, while getting coordinates for Street1:{2} & Street2:{3} and City:{4}'.format(
                    index+1, target_location_df.shape[0], row['loss_location_at'], row['loss_location_on'], row['city_of_incident'])
                print('\r', error_message, " " * (200-len(error_message)))
        else:
            skipped_count += 1
            # print("Processing ", (index+1), "/", target_location_df.shape[0], "Row already has coordinates, skipping the request.")

        # writing batches of 40 to avoid too much I/O time, if script terminates in the middle, next execution can continue where previous attempt interrupted.
        if(index % 40 == 0):
            target_location_df.to_csv(output_file_path, index=False)

    target_location_df.to_csv(output_file_path, index=False)





if __name__ == "__main__":
    main(opt["--input_file_path"], opt["--output_file_path"], opt["--api_key"])
