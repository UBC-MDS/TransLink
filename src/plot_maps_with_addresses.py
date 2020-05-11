#!/usr/bin/env python
# coding: utf-8


import pandas as pd
source_data_path = 'data/Processed Data/collision_locations.csv'
target_data_path = 'data/Processed Data/collision_locations_with_coordinates.csv'

Collision_preventable = pd.read_excel('data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx', skiprows=  3)
collision_locations = Collision_preventable[['Loss Location At', 'Loss Location On', 'City of Incident']]
collision_locations.columns = ['street1', 'street2', 'city']
collision_locations = collision_locations.applymap(lambda x: str(x).title())
collision_locations.to_csv(source_data_path, index=False)

import glob
location_df = pd.read_csv(source_data_path)
if(len(glob.glob("data/Processed Data/"+target_data_path)) == 0):
    target_location_df = pd.read_csv(source_data_path)
    target_location_df["latt"] = None
    target_location_df["long"] = None
    target_location_df["formatted_address"] = None
else:
    target_location_df = pd.read_csv(target_data_path)


import googlemaps
gmaps = googlemaps.Client(key='Google maps API Key')

def get_location(street2, street1, city, province = "BC"):
    query_format = '{0} & {1}, {2}, {3}'
    query = query_format.format(street1, street1, city, province)
    geocode_result = gmaps.geocode(query)
    address = geocode_result[0]['formatted_address']
    geometry = geocode_result[0]['geometry']['location']
    return{'latt':geometry['lat'], 'long':geometry['lng'], "address" : address}



for index, row in location_df.iterrows():
    if(target_location_df.loc[index,'latt'] != None ):
        print("Processing ", (index+1), "/", location_df.shape[0], "Row already has coordinates, skipping the request.")
    else:
        print("Processing ", (index+1), "/", location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
        try:
            location = get_location(row['street1'], row['street2'], row['city'])
            target_location_df.loc[index,'latt'] = location['latt']
            target_location_df.loc[index,'long'] = location['long']
            target_location_df.loc[index,'formatted_address'] = location['address']
        except:
            print("Error in processing ", (index+1), "/", location_df.shape[0], "Getting coordinates for Street1:", row['street1'], ", Street2: ", row['street2'], ", City:", row['city'])
    
    if(index % 40 == 0):
        target_location_df.to_csv(target_data_path, index = False)




import folium
from folium.plugins import MarkerCluster
from folium.plugins import FastMarkerCluster
folium_map = folium.Map(location=[49.133298, -122.843092],
                        zoom_start=11,
                        tiles='CartoDB positron',
                        width=800, height=750)

target_location_df.dropna(subset=['long', 'latt'], inplace = True)
FastMarkerCluster(data=list(zip(target_location_df['latt'].values, target_location_df['long'].values))).add_to(folium_map)
folium.LayerControl().add_to(folium_map)
folium_map


