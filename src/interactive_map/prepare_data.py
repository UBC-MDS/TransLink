#!/usr/bin/env python
# coding: utf-8

"""
This script joins the following datasets`claim_vehicle_employee_line.csv`, 
`Preventable and Non Preventable_tabDelimited.txt` and `Employee_Experience.csv`
to create a CSV file that contains the required information for the interactive plot.
It also cleans the resulting CSV file to get a successful result from the Google 
Maps API. Assumes `get-data.py` is run before. 

Usage: prepare_data.py --claims_file_path=<claims_file_path> --collisions_file_path=<collisions_file_path> --employee_file_path=<employee_file_path> --output_file_path=<output_file_path>

Options:

--claims_file_path=<claims_file_path>   A file path for claims dataset that contains information about the claims.
--collisions_file_path=<collisions_file_path>   A file path for collisions dataset that contains information about the collisions.
--employee_file_path=<employee_file_path>   A file path for employees dataset that contains information about the employees.
--output_file_path=<output_file_path>   A file path for resulting joined dataset.

Example: 

python src/interactive_map/prepare_data.py \
    --claims_file_path "data/TransLink Raw Data/claim_vehicle_employee_line.csv" \
    --collisions_file_path  "data/TransLink Raw Data/Preventable and Non Preventable_tabDelimited.txt"\
    --employee_file_path "data/TransLink Raw Data/Employee_Experience.csv"\
    --output_file_path "results/processed_data/collision_with_claim_and_employee_info.csv" 
    
"""

import pandas as pd
import numpy as np
from docopt import docopt
import glob
import os
import googlemaps
from pathlib import Path

opt = docopt(__doc__)

def create_dirs_if_not_exists(file_path_list):
    """
    It creates directories if they don't aldready exist. 

    Parameters:
    file_path_list (list): A list of paths to be created if they don't exist.
    """
    for path in file_path_list:
        Path(os.path.dirname(path)).mkdir(parents=True, exist_ok=True)

def compare_loss_date(row):
    """
    A helper function to be used in the main function
    """
    if (row['loss_date_x'] is not pd.NaT) & (row['loss_date_y'] is pd.NaT):
        val =  row.loss_date_x
    else:
        val =  row.loss_date_y
    return val

def main(claims_file_path, collisions_file_path, employee_file_path, output_file_path):

    #read the collisions dataset
    collision = pd.read_csv(collisions_file_path, delimiter="\t")
    collision.columns = map(str.lower, collision.columns)
    #take only the required information
    collision = collision[['loss_location_at','preventable_nonpreventable', 'loss_location_on',
    'city_of_incident', 'loss_date','apta_desc', 'asset_vehicle_year', 'asset_manufacturer', "claim_id"]]
    #convert `loss_date` to date_time
    collision['loss_date'] = pd.to_datetime(collision['loss_date'], format="%d/%m/%Y")

    #read the claims dataset
    claims = pd.read_csv(claims_file_path)
    #take only the required information
    claims = claims[['claim_id', 'paid_cost$', 'empl_id', 'loss_date']]
    #give a better name for join
    claims = claims.rename(columns = {'empl_id': 'employee_id'})
    #convert `loss_date` to date_time
    claims['loss_date'] = pd.to_datetime(claims['loss_date'], format="%Y-%m-%d")

    #read the employees dataset
    employee = pd.read_csv(employee_file_path)
    #take only the required information
    employee = employee[['employee_id', 'Experience_Category']]

    #first merge claims and employees' information with respect to employee_id column
    claims_with_employee = pd.merge(employee, claims, on=['employee_id'], how='right')

    # merge the above dataset and collisions information with respect to claim_id column
    combined_df = pd.merge(claims_with_employee, collision, on=['claim_id'], how='left')

    #there are two `loss_date`s coming from claims and also collisions datasets.
    #Take the not null one.
    combined_df['loss_date'] = combined_df.apply(compare_loss_date, axis = 1)
    #drop unnecessary columns
    combined_df = combined_df.drop(columns = ['loss_date_x', 'loss_date_y'])
    #we are only interested in preventable collisions
    combined_df_preventable = combined_df[combined_df["preventable_nonpreventable"] == "P"]
    combined_df_preventable = combined_df_preventable.drop(columns = ['preventable_nonpreventable'])

    #remove the rows if both street names are null.
    combined_df_preventable = combined_df_preventable.dropna(subset=["loss_location_at", "loss_location_on"], how = 'all')

    #clean city names to get a successful result from Google Maps API
    combined_df_preventable['city_of_incident'] = combined_df_preventable['city_of_incident'].str.lower().str.strip()
    combined_df_preventable['city_of_incident'].replace(["van", "vacovuer", "vancouer", "vancover", "vancouver", "vancovuer", "ubc", "vancouver - vtc", "vtc"], "Vancouver", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["bur", "burnaby", "bunaby"], "Burnaby", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["new wesminster", "nw", "new westminister", "new westminster"], "New Westminster", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["sur", "sureey", "surrye", "surrey", "cloverdale", "south surrey"], "Surrey", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["ladnar", "ladner", "del", "delta"], "Delta", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["coq", "coquitlam"], "Coquitlam", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["lan", "langley"], "Langley", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["pit", "pit meadow", "pitt meadows"], "Pitt Meadows", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["mr", "maple ridge"], "Maple Ridge", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["pm", "poer moody", "port moody"], "Port Moody", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["pc", "port coquitlam"], "Port Coquitlam", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["wr", "white rock", "white rock/surrey", "whiterock", "white rock / surrey"], "White Rock", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["wv", "west vancouver"], "West Vancouver", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["ric", "richmond"], "Richmond", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["nv", "north van", "north vancover", "north vancouver"], "North Vancouver", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["anmore"], "Anmore", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["belcarra"], "Belcarra", inplace=True)
    combined_df_preventable['city_of_incident'].replace(["walnut grove"], "Walnut Grove", inplace=True)

    # trim street names
    combined_df_preventable['loss_location_at'] = combined_df_preventable['loss_location_at'].str.strip()
    combined_df_preventable['loss_location_on'] = combined_df_preventable['loss_location_on'].str.strip()

    #write the resulting dataframe into the output_file_path.
    create_dirs_if_not_exists([output_file_path])
    combined_df_preventable.to_csv(output_file_path, index=False)

if __name__ == "__main__":
    main(opt["--claims_file_path"], opt["--collisions_file_path"], opt["--employee_file_path"], opt["--output_file_path"])
    