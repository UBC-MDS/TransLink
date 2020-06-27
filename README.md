# Vision over Transit Incidents & Claims

Contributors: 

 - Brayden Tang, brayden.tang1@gmail.com
 
 - Xugang Zhong, chuusankirk@hotmail.com
 
 - Merve Sahin, kymerve16@gmail.com
 
 - Simardeep Kaur, simardeep.kaur.jeji@gmail.com
 

This is a mentored group project for the Master of Data Science program at the University of British Columbia with the business partner Business Technology Services (BTS) and Insurance Claims groups of TransLink.
 
## Overview
  
Since 2014/2015, TransLink's insurance premium paid to ICBC has increased by over 200% as a result of increasing onboard passenger injuries, cyclist injuries, pedestrian injuries, and losses from collisions with third party vehicles. In addition, for at-fault physical damage losses to its vehicles, the premium paid to its own captive insurance company has increased by 33%.

In response to soaring insurance costs and road safety concerns, TransLink has asked us to analyze key variables of interest that may be predictive of bus incidents. These variables include bus operator characteristics (such as work experience), bus characteristics (such as bus model and bus age), weather and time related variables, and various other factors unique to TransLink, like the bus line. Finally, TransLink has also asked us to analyze the types of claims that are occurring - in particular, if there are common types of claims per location and if particular locations yield large paid costs.

## Viewing the Interactive Report and Replicating the Analysis

The interactive report must be run as an application on your computer because it runs interactive visualizations in real time.

There are three ways to actually view the report:

1) Using [Docker](https://www.docker.com/) + Amazon S3 (to download precompiled results required to run the interactive report)
2) Using Docker + Make to compile results locally (still need Amazon S3 for the raw data)
3) Using Make and installing all dependencies manually (not recommended)

If you just wish to view the report, we **highly recommend using method 1)** since it is by far the fastest method. We mainly include method 2) and 3) for the ability to reproduce all analyses in case TransLink wishes to view/use intermediate models and/or results that are not necessarily in the final interactive report.

### Method 1 (Docker + Amazon S3)

To use this method, access to the Amazon Web Services (AWS) S3 bucket (where Saeed uploaded the raw data used in this analysis) is required. This requires both an [AWS Access Key and an AWS Secret Key.](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html)

In addition, you need to have Docker and Git installed.

#### Windows Users:

Please consult this tutorial [here](doc/docker_instructions.pdf) that we have created specifically for those who are on Windows. Note that Docker on Windows [requires Windows 10 64-bit (Pro, Enterprise, or Education editions) and in addition, Hyper-V must be enabled](https://docs.docker.com/docker-for-windows/install/). 

In addition to the above instructions, we **highly recommend that you download the entire S3 bucket and then copy both the data and results folders in the repository** on TransLink's own servers so that you will always be able to view the report and replicate the analysis from scratch.

#### Linux and Mac Users:

Install Docker and Git. Next, clone this repository and then run the following command at the command line/terminal from the root directory of this project:

```docker run --rm -v "/$(pwd):/repo" btang101/tl_vision python src/get-data.py --access_key=YOUR_AWS_ACCESS_KEY --secret_key=YOUR_AWS_SECRET_KEY```

where you replace YOUR_AWS_ACCESS_KEY and YOUR_AWS_SECRET_KEY with your actual AWS access key and AWS secret key. You may need sudo privileges. This command only needs to be run once (unless you delete the data and/or the results folders for some reason, in which case this command needs to be run again).

Then, run the following command at the command line/terminal, again from the root directory of this project:

```sudo docker run --rm -p 3838:3838 -v "/$(pwd):/repo" btang101/tl_vision Rscript -e "rmarkdown::run('doc/interactive-report/interactive-report.rmd', shiny_args = list(port = 3838, host = '0.0.0.0'))"```

Navigate to the address 0.0.0.0:3838 in any web browser and after maybe 45 seconds the interactive report should be viewable. 

### Method 2 (Using Docker + Makefile)

This method actually recreates all of the analyses done for this Capstone project from scratch. Therefore, this will **take over a day to complete** and this is not recommended if you just wish to view the interactive report. In addition, a [Google Maps Geocoding API key is also required](https://developers.google.com/maps/documentation/geocoding/get-api-key) - Google provides $200 of free credit every month which should be more than enough to run this analysis.

To use this method, you just need Docker and Git. Access to the Amazon S3 bucket is also required but only to obtain the raw data. 

Finally, your computer **must** have at least:

- 16 GB of RAM
- At least 4 virtual CPU cores (view System Information to find out how many cores your computer has)

#### Windows Users:

After cloning this repository, open up the Makefile found in the root directory of this repository (called Makefile) in a text editor like Notepad. Ctrl + F for the symbols "..." (no quotations). The first two matches should bring you to this line:

```	python src/get-data.py --access_key=... --secret_key=...```

Replace "..." with your AWS S3 access key and AWS S3 secret key.

The third match should bring you to this line:

```python src/interactive_map/append_coordinates.py --input_file results/processed_data/collision_with_claim_and_employee_info.csv --api_key=...```

Replace "..." where it says `--api_key=...` with your Google Maps Geocoding API key. 

Save the Makefile and close it. Next, run the following command at the command line/terminal from the root of this repository:

```docker run --rm -v "${pwd}://repo" btang101/tl_vision make -C /repo all```

After everything has completed (which will likely take over a day), run the following command again from the root of this repository:

```docker run --rm -p 3838:3838 -v "${pwd}://repo" btang101/tl_vision Rscript -e "rmarkdown::run('doc/interactive-report/interactive-report.rmd', shiny_args = list(port = 3838, host = '0.0.0.0'))"```

Then, visit localhost:3838 in a web browser to view the interactive report.

To reset the repository to a clean state, with no intermediate or results files, run the following command at the command line/terminal from the root of this repository:

```docker run --rm -v "${pwd}://repo" btang101/tl_vision make -C /repo clean``` 

#### Linux and Mac Users:

Edit the Makefile as explained above by replacing the three dots ("...") with your AWS S3 access/secret keys and Google Maps Geocoding API key where needed. Then, after saving the Makefile run the following command at the command line/terminal from the root of this repository:

```docker run --rm -v "/$(pwd):/repo" btang101/tl_vision make -C /repo all```

Next, run the command (again from the root of this repository):

```sudo docker run --rm -p 3838:3838 -v "/$(pwd):/repo" btang101/tl_vision Rscript -e "rmarkdown::run('doc/interactive-report/interactive-report.rmd', shiny_args = list(port = 3838, host = '0.0.0.0'))"```

Then, visit 0.0.0.0:3838 in a web browser to view the interactive report.

To reset the repository to a clean state, with no intermediate or results files, run the following command at the command line/terminal from the root of this repository:

```docker run --rm -v "/$(pwd):/repo" btang101/tl_vision make -C /repo clean``` 

### Method 3 (No Docker + Make) - COMPLETELY NOT RECOMMENDED!

This method is almost the exact same thing as Method 2) but without the use of the Docker container. This is **not recommended** and we do not give any guarantee that the following steps will actually reproduce the report because different computers may require different external dependencies.

This method requires installing **all of the dependencies** listed below in this README file. Therefore, it is difficult to give specific instructions with this method because every computer will likely require different instructions depending on what is already installed or not installed.

Regardless, after installing all dependencies in the list below, edit the Makefile as explained in Method 2) and then run this command in the root of this repository:

```make all```

This will take over a day to finish. Once everything has finished running, run the command:

```Rscript -e rmarkdown::run('doc/interactive-report/interactive-report.rmd', shiny_args = list(port = 3838, host = '0.0.0.0')```

Then, visit 0.0.0.0:3838 (Linux or Mac) OR localhost:3838 (Windows) to view the interactive report.

To reset the repository to a clean state, with no intermediate or results files, run the following command at the command line/terminal from the root of this repository:

```make clean```

## Flow Diagram

The flow diagram below illustrates the overviews our analysis process and illustrates script orders and dependencies.

![](images/pipeline_draft.png)

## Dependencies

The following dependencies are required to run this analysis from scratch (i.e. if you do not plan on using Docker for some reason). These dependencies already come preinstalled on the Docker image which can be found on DockerHub [here](https://hub.docker.com/r/btang101/tl_vision). There is **no need to actually install this Docker image explicitly** - running the commands above will automatically install it for you.
 
- Python 3.7.3 and Python packages:
  - anaconda==4.8.3
  - docopt==0.6.2
  - googlemaps==2.5.1
  - boto3==1.13.11
  - lightgbm==2.3.0
  - spacy==2.3.0
  - shap==0.35.0
  - nltk==3.4.5
  
- R 3.6.3 or lower (does **not** work on R 4.0) and R packages:
  - brms==2.12.0
  - tidyverse==1.3.0
  - caret==6.0-86
  - here==0.1
  - zoo==1.8-7
  - shiny==1.4.0.2
  - leaflet==2.0.3
  - kableExtra==1.1.0
  - plotly==4.9.2.1
  - ggthemes==4.2.0
  - mapview==2.7.8
  - lubridate==1.7.8
  - htmlwidgets==1.5.1
  - bayesplot==1.7.1
  - janitor==2.0.1
  - VGAM==1.1-2
  - reticulate==1.15
  - shinydashboard==0.7.1
  - shinycssloaders==0.3
  - RColorBrewer==1.1-2
  - sjmisc==2.8.4
  - readxl==1.3.1
  - ggwordcloud==0.5.0
  - wordcloud==2.6
  - wordcloud2==0.2.1
  - PubMedWordCloud==0.3.6
  - DT==0.13
    - png==0.1-7

- GNU make 4.2.1

## Additional Links

- [Code of Conduct](https://github.com/UBC-MDS/Translink/blob/master/CONDUCT.md)
- [License](https://github.com/UBC-MDS/Translink/blob/master/LICENSE)
- [Contributing](https://github.com/UBC-MDS/Translink/blob/master/CONTRIBUTING.md)
- [Contributors](https://github.com/UBC-MDS/Translink/blob/master/CONTRIBUTORS.md)
- [Proposal](https://github.com/UBC-MDS/TransLink/blob/master/doc/proposal/Proposal.pdf)
- [Final Report]

## References

Daniel Wilson. 2018. Using Machine Learning to Predict Car Accident Risk. Redlands, USA: Esri. https://medium.com/geoai/using-machine-learning-to-predict-car-accident-risk-4d92c91a7d57.

Hébert et al. 2019. High-Resolution Road Vehicle Collision Prediction for the City of Montreal. Montreal, Canada: Department of Computer Science; Software Engineering Concordia University. https://www.groundai.com/project/high-resolution-road-vehicle-collision-prediction-for-the-city-of-montreal/1.

TransLink. 2018. 2018 Accountability Report. Vancouver, Canada: TransLink. https://view.publitas.com/translink/2018-accountability-report/page/6.



