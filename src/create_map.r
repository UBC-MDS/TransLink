# Author: Merve Sahin
# Date: May 25th, 2020


"This script reads in the processed data and creates an interactive map showing 
the locations of the incidents. The output is saved as a png format. 
The files are stored in the main data folder. This script assumes that the 
user runs `append_coordinates.py` script before.

Usage: src/create_map.r --input_file=<input_file> --path_out_map=<path_out_map>
Options:
--input_file=<input_file>   Path (including filename) to cleaned league and fifa file
--path_out_map=<path_out_map>    A file path specifying where to output the map. 
" -> doc
#example to run:Rscript src/create_map.r --input_file="../data/processed_data/collision_locations_with_coordinates.csv" --path_out_map="../data/static_map.png"
library(docopt)
library(leaflet)
library(mapview)
library(tidyverse)

opt <- docopt(doc)

main <- function(input_file, path_out_map){
  
  # Check if data supplied is a .csv file.
  if (!str_detect(input_file, ".csv")) {
    stop("File path to data must be a specific .csv file.")
  }
  
  # Check if the outpath is in the right format.
  if (!str_detect(path_out_map, ".png")) {
    stop("File path to save the map should be a specific .png file.")
  }
  
  
  target_location_df = read_csv(input_file)
  
  # Check for specific columns in a specific format.
  if (any(c("lat", "long", "desc") %in% colnames(target_location_df) == FALSE)) {
    stop("Data is missing specific column names required for this analysis. Columns specifically entitled
         lat, long and desc are required.")
  }
  
  # remove the null values 
  target_location_df <- target_location_df %>%
  drop_na(lat, long)
  
  # create the map
  m <- leaflet() %>%
    addProviderTiles("CartoDB.Positron") %>% 
    addMarkers(lng=target_location_df$long, 
               lat=target_location_df$lat, 
               clusterOptions = markerClusterOptions(), 
               popup=paste0("<b>", target_location_df$desc, "</b> <br>", 
                            "<b>", "Date: ", "</b> ", target_location_df$date, "<br>", 
                            "<b>","Bus Year: ", "</b> ", target_location_df$bus_year, "<br>", 
                            "<b>","Manufacturer: ", "</b> ", target_location_df$bus_manufacturer, "<br>" ))
    
  # save the map into given file
  mapshot(m, file = path_out_map)

}

main(opt[["--input_file"]], opt[["--path_out_map"]])
