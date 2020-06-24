# Using Rocker/tidyverse as base

FROM rocker/tidyverse 

# Update the image

RUN apt-get update 

# Install Anaconda
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh -O ~/anaconda.sh && \
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
RUN Rscript -e "install.packages(c('caret', 'brms', 'zoo', 'shiny', 'leaflet',
'kableExtra', 'plotly', 'ggthemes', 'mapview', 'lubridate', 'htmlwidgets',
'bayesplot', 'janitor', 'VGAM', 'reticulate', 'htmlwidgets', 'shinydashboard', 'shinycssloaders',
'RColorBrewer', 'sjmisc', 'readxl', 'wordcloud', 'DT', 'ggwordcloud', 'wordcloud2', 'PubMedWordcloud',
'png', 'grid'))"