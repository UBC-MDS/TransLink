#!/usr/bin/env python
# coding: utf-8

"""This script creates a csv file containing the coordination of the incidents. 
It takes the street names and the city names from "Preventable and Non Preventable_tabDelimited.txt"
and convert them to formatted addresses including long and lat of the incidents. Assumes `get-data.py`
is run before. A google maps API key is also required. 

Usage: append_coordinates.py --input_file_path=<input_file_path> --output_file_path=<output_file_path> --api_key=<api_key>

Options:

--input_file_path=<input_file_path>           A file path containing the street and city names of the incident locations.
--output_file_path=<output_file_path>   A file path for coordinates of the incident locations.
--api_key=<api_key>   The google maps API key to make request. 

Example: 
python src/interactive_map/append_coordinates.py \
    --input_file "data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt" \
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
    It creates longtitude, lattitude and formatted address of the given street and city names.
    To speed up the process, it first looks at the cache file and if it doesn't exist in the
    cache file, then it makes a request for google maps api. 
    '''
    query_format = '{0} & {1}, {2}, {3}'
    query = query_format.format(street1, street2, city, province)

    coordinate_cache_df = pd.read_csv(
        "results/processed_data/coordinate_cache.csv")
    cached_coordinates = coordinate_cache_df.loc[coordinate_cache_df['query'] == query]
    if (cached_coordinates.empty):
        location = get_location_from_google_maps(google_maps_client, query)
        # write it to cache too
    else:
        location_from_cache = dict(cached_coordinates.iloc[0])
        location = {'lat': location_from_cache['lat'], 'long': location_from_cache['long'],
                    "address": location_from_cache['formatted_address']}

    return location


def get_location_from_google_maps(google_maps_client, query):
    '''
    It creates longtitude, lattitude and formatted address of the given street and city names
    by using google maps api.
    '''
    geocode_result = google_maps_client.geocode(query)
    address = geocode_result[0]['formatted_address']
    geometry = geocode_result[0]['geometry']['location']
    return{'lat': geometry['lat'], 'long': geometry['lng'], "address": address}


def create_dirs_if_not_exists(file_path_list):
    for path in file_path_list:
        Path(os.path.dirname(path)).mkdir(parents=True, exist_ok=True)


def get_clean_data(input_file_path):

    '''
    It reads the input file and cleans the city names to get a successful result from
    google maps.
    '''

    try:
        collision = pd.read_csv(input_file_path, delimiter="\t")
    except:
        raise ValueError("Input file does not exist or is not a txt file.")
    
    collision_preventable = collision[collision["Preventable_NonPreventable"] == "P"]
    collision_locations = collision_preventable[['Loss_Location_At', 'Loss_Location_On',
                                                 'City_of_Incident', 'Loss_Date', 'APTA_Desc', 
                                                 'Asset_Vehicle_Year', 'Asset_Manufacturer', "claim_id"]]
    collision_locations['City_of_Incident'] = collision_locations['City_of_Incident'].str.lower(
    ).str.strip()
    collision_locations['City_of_Incident'].replace(
        ["van", "vacovuer", "vancouer", "vancover", "vancouver", "vancovuer", "ubc", "vancouver - vtc", "vtc"], "Vancouver", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["bur", "burnaby", "bunaby"], "Burnaby", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["new wesminster", "nw", "new westminister", "new westminster"], "New Westminster", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["sur", "sureey", "surrye", "surrey", "cloverdale", "south surrey"], "Surrey", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["ladnar", "ladner", "del", "delta"], "Delta", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["coq", "coquitlam"], "Coquitlam", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["lan", "langley"], "Langley", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["pit", "pit meadow", "pitt meadows"], "Pitt Meadows", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["mr", "maple ridge"], "Maple Ridge", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["pm", "poer moody", "port moody"], "Port Moody", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["pc", "port coquitlam"], "Port Coquitlam", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["wr", "white rock", "white rock/surrey", "whiterock", "white rock / surrey"], "White Rock", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["wv", "west vancouver"], "West Vancouver", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["ric", "richmond"], "Richmond", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["nv", "north van", "north vancover", "north vancouver"], "North Vancouver", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["anmore"], "Anmore", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["belcarra"], "Belcarra", inplace=True)
    collision_locations['City_of_Incident'].replace(
        ["walnut grove"], "Walnut Grove", inplace=True)
    collision_locations.columns = [
        'street1', 'street2', 'city', 'date', 'desc', 'bus_year', 'bus_manufacturer', 'claim_id']
    collision_locations = collision_locations.applymap(
        lambda x: str(x).title())

    return collision_locations


def check_if_file_does_not_exists(file_path):
    return len(glob.glob(file_path)) == 0


def main(input_file_path, output_file_path, api_key):

    # create given output file if it doesn't exist
    create_dirs_if_not_exists([output_file_path])

    if(check_if_file_does_not_exists(output_file_path)):
        # get cleaned data
        target_location_df = get_clean_data(input_file_path)

        # prepare data frame
        target_location_df["lat"] = None
        target_location_df["long"] = None
        target_location_df["formatted_address"] = None
        target_location_df.to_csv(output_file_path, index=False)

    # read current output_file
    target_location_df = pd.read_csv(output_file_path)
    # check whether it has all required columns
    columns_list = ['lat', 'long', 'formatted_address', 'date', 'desc',
                    'bus_year', 'bus_manufacturer', 'street1', 'street2', 'city', 'claim_id']
    if not set(columns_list).issubset(target_location_df.columns):
        raise ValueError(
            " Target data path should contain all of: ", columns_list)

    google_maps_client = googlemaps.Client(key=api_key)

    error_count = 0
    skipped_count = 0
    # to see the process of the requests
    printProgressBar(
        0, target_location_df.shape[0], error_count, skipped_count)
    for index, row in target_location_df.iterrows():
        printProgressBar(
            index, target_location_df.shape[0], error_count, skipped_count)
        current_lat_value = target_location_df.loc[index, 'lat']
        if((current_lat_value == None) | (np.isnan(current_lat_value))):
            # print("Processing ", (index+1), "/", target_location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
            try:
                location = get_location(
                    google_maps_client, row['street1'], row['street2'], row['city'])
                target_location_df.loc[index, 'lat'] = location['lat']
                target_location_df.loc[index, 'long'] = location['long']
                target_location_df.loc[index,
                                       'formatted_address'] = location['address']
            except Exception as e:
                error_count += 1
                error_message = 'Error in processing {0}/{1}, while getting coordinates for Street1:{2} & Street2:{3} and City:{4}'.format(
                    index+1, target_location_df.shape[0], row['street1'], row['street2'], row['city'])
                print('\r', error_message, " " * (200-len(error_message)))
        else:
            skipped_count += 1
            # print("Processing ", (index+1), "/", target_location_df.shape[0], "Row already has coordinates, skipping the request.")

        # writing batches of 40 to avoid too much I/O time, if script terminates in the middle, next execution can continue where previous attempt interrupted.
        if(index % 40 == 0):
            target_location_df.to_csv(output_file_path, index=False)

    target_location_df.to_csv(output_file_path, index=False)


def printProgressBar(iteration, total, error_count, skipped_count, prefix='Progress:', suffix='Completed', decimals=1, length=100, fill='█', printEnd="\r"):
    """
    Call in a loop to create terminal progress bar
    
    Attributes
    ----------
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
        printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 *
                                                     (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print('\r%s |%s| %s%% %s %s/%s Errors:%s Skipped:%s' % (prefix, bar, percent,
                                                            suffix, iteration, total, error_count, skipped_count), end=printEnd)
    # Print New Line on Complete
    if iteration == total:
        print()


if __name__ == "__main__":
    main(opt["--input_file_path"], opt["--output_file_path"], opt["--api_key"])
