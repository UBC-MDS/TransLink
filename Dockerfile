# Using Rocker/tidyverse as base

FROM rocker/tidyverse 

# Update the image

RUN apt-get update 

# Install Anaconda
wget --quiet https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh && \
    ln -s /opt/conda/etc  /profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy && \
    /opt/conda/bin/conda update -n base -c defaults conda -y
    
# Set Anaconda Path
ENV PATH="/opt/conda/bin:${PATH}"

RUN conda install -y -c anaconda docopt \
                          boto3 && \
    conda install -y -c conda-forge googlemaps \
                                   lightgbm \
                                   shap
                            
# Need this package for leaflet in R  
RUN apt-get install libudunits2-dev

# Need this package for caret and leaflet in R
RUN apt install libgdal-dev -y 

# Install R Packages needed 
RUN Rscript -e "install.packages(c('caret', 'brms', 'zoo', 'shiny', 'leaflet', 'kableExtra', 'plotly', 'ggthemes', 'mapview', 'lubridate', 'htmlwidgets', 'bayesplot', 'janitor', 'VGAM', 'reticulate'))"
  
CMD ["/bin/bash"]   
