import pandas as pd
import numpy as np
import pickle
import shap
from lightgbm import LGBMClassifier

def get_new_prediction(bus_line, hour, month, day, bus_carrying_cap, city, temp, pressure, total_rain):
  shuttles = ["23", "31", "42", "68", "103", "105", "109", "131", "132", "146",
                     "147", "148", "157", "169", "170", "171", "172", "173", "174", "175", "180", "181",
                     "182", "184", "185", "186", "187", "189", "215", "227", "251", "252", "256", "262",
                     "280", "281", "282", "310", "322", "360", "361", "362", "363", "370", "371", "372", 
                     "373", "412", "413", "414", "416", "560", "561", "562", "563", "564", "609", "614",
                     "616", "617", "618", "619", "719", "722", "733", "741", "743", "744", "745", "746", "748", "749"]
                     
  # The values that are held constant: just use the means/modes
  new_data = pd.DataFrame({
    'hour': pd.Series(hour, dtype='int'),
    'day_of_week': pd.Series(day, dtype='str'),
    'bus_age': pd.Series(12.57, dtype='float'),
    'bus_carry_capacity': pd.Series(bus_carrying_cap if bus_carrying_cap != "NA" else np.nan, dtype='float'),
    'line_no': pd.Series(bus_line, dtype='str'),
    'city': pd.Series(city, dtype='str'),
    'pressure': pd.Series(pressure, dtype='float'),
    'rel_hum': pd.Series(93, dtype='float'),
    'elev': pd.Series(2.5, dtype='float'),
    'temp': pd.Series(temp, dtype='float'),
    'visib': pd.Series(48.3, dtype='float'),
    'wind_dir': pd.Series(0, dtype='float'),
    'wind_spd': pd.Series(2, dtype='float'),
    'total_precip': pd.Series(total_rain, dtype='float'),
    'total_rain': pd.Series(total_rain, dtype='float'),
    'total_snow': pd.Series(0, dtype='float'),
    'experience_in_months': pd.Series(110, dtype='float'),
    'is_shuttle': pd.Series(1 if bus_line in shuttles else 0, dtype='float'),
    'asset_class': pd.Series('DS40LF', dtype='str'),
    'asset_manufactmodel': pd.Series('40LFC', dtype='str'),
    'month': pd.Series(month, dtype='int')
  })
  
  for c in new_data.columns:
    col_type = new_data[c].dtype
    if col_type == 'object' or col_type.name == 'category':
      new_data[c] = new_data[c].astype('category')

  with (open("../../results/ml_model/final_fitted.pickle", 'rb')) as openfile:
    model = pickle.load(openfile)
    
  return {'shap': shap.TreeExplainer(model=model).shap_values(new_data)[1], 'predicted': model.predict_proba(new_data), 'column_names': new_data.columns.to_list()}
