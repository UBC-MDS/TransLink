# Using Rocker/tidyverse as base

FROM rocker/tidyverse:3.6.3 

# Update the image

RUN apt-get update 

# Install Anaconda. We need a standalone Anaconda for the actual analysis and to run get-data.py. reticulate cant seem to find this.
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy && \
    /opt/conda/bin/conda update -n base -c defaults conda -y

# Set Anaconda Path
ENV PATH="/opt/conda/bin:${PATH}"
    
# Install all required Python packages
RUN conda install -y -c anaconda docopt \
                              boto3 nltk  && \
    conda install -y -c conda-forge googlemaps \
                                       lightgbm \
                                       shap \
                                       spacy 

# RStudio authentication                            
CMD ["/bin/bash"] 

# Need this package for leaflet in R  
RUN apt-get install libudunits2-dev -y

# Need this package for caret and leaflet in R
RUN apt install libgdal-dev -y 

# Install R Packages needed 
RUN Rscript -e "install.packages(c('caret', 'brms', 'here', 'zoo', 'shiny', 'leaflet',\
'kableExtra', 'plotly', 'ggthemes', 'mapview', 'lubridate', 'htmlwidgets',\
'bayesplot', 'janitor', 'VGAM', 'reticulate', 'shinydashboard', 'shinycssloaders',\
'RColorBrewer', 'sjmisc', 'readxl', 'wordcloud', 'DT', 'ggwordcloud', 'wordcloud2',\
'PubMedWordcloud', 'png', 'grid'))"

# Copy get-data.py script from local files
# First define new directory
WORKDIR /repo

# Next, add the local files from the repository to the container.
# On the container, these files are now in /repo

COPY src/get-data.py .
COPY doc/interactive-report/ .

# We are forced to install yet another conda - this is annoying but reticulate has difficulty finding the old anaconda
RUN Rscript -e "reticulate::install_miniconda()"

# Install all the necessary python packages 
RUN Rscript -e "reticulate::conda_install(packages = c('pandas','lightgbm', 'shap'))"

# Expose port to view the interactive report 
EXPOSE 3838 
