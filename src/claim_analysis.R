library(shiny)
library(shinydashboard)
library(shinycssloaders)
library(RColorBrewer)
library(tidyverse)
library(sjmisc)
library(readxl)
library(wordcloud)
library(leaflet)
library(DT)
library(dplyr)

display.brewer.all()
ui <- dashboardPage(
    dashboardHeader(title = "Reasons for Incidents"),
    dashboardSidebar(collapsed = TRUE, disable = TRUE),
 dashboardBody(
    
         fluidRow(
            
                 box(leafletOutput("mymap", height = 250)),
                    box(plotOutput("plot", height = 250), title = "NOUN")
         ),
         fluidRow(
                      box(leafletOutput("my_verb_map", height = 250)),
           
                   box(plotOutput("plot_verb", height = 250), title = "VERB")
             
         )
     )
     
 )

server <- function(input, output) {
    
    # read location data
    location_data <- read_excel("../data/TransLink Raw Data/Claim_colour_df.xlsx")
    verb_data <- read_excel("../data/TransLink Raw Data/verb_colour_df.xlsx")
    
    # leaflet map
    output$mymap <- renderLeaflet({
        # Show first 20 rows from the `quakes` dataset
        leaflet() %>%
            addProviderTiles("CartoDB.Positron") %>%
            addCircleMarkers(lng=location_data$long, lat=location_data$latt, radius=4,fillOpacity=1, color = location_data$impact_colour )
    })
    #print(location_data$impact_colour)
    
    output$my_verb_map <- renderLeaflet({
        # Show first 20 rows from the `quakes` dataset
        leaflet() %>%
            addProviderTiles("CartoDB.Positron") %>%
            addCircleMarkers(lng=verb_data$long, lat=verb_data$latt, radius=4,fillOpacity=1, color = verb_data$verb_colour)
    })
    
    # plot for Impacts
    output$plot = renderPlot({
        if (isTruthy(input$mymap_bounds)) {
            bounds = input$mymap_bounds
            df <- location_data %>% filter(
                between(long, bounds$west, bounds$east),
                between(latt, bounds$south, bounds$north)
            )
            
            
            
            
            wc_df_impact <- df %>% select(impact, impact_colour)
            impact_df <- count(wc_df_impact, impact,impact_colour )
            view(impact_df)
            
            
            #basecolors = rainbow(length(unique(group)))
            
            
            
            wordcloud(impact_df$impact, impact_df$n, max.words = 300, ordered.colors=TRUE,random.color=FALSE,min.freq = 1,
                      colors = as.character(impact_df$impact_colour), scale=c(4,0.25))
            
            
            
            
        } else
            wordcloud(impact_df$impact, impact_df$n,ordered.colors=TRUE, random.color=FALSE,max.words = 300,min.freq = 1, colors = as.character(impact_df$impact_colour), scale=c(4,0.25))
    })
    
    # plot for Impacts
    output$plot_verb = renderPlot({
        if (isTruthy(input$my_verb_map_bounds)) {
            bounds = input$my_verb_map_bounds
            df <- verb_data %>% filter(
                between(long, bounds$west, bounds$east),
                between(latt, bounds$south, bounds$north)
            )
            
            
            
            minilist= list()
            for(i in df$chosen_verb_y){
                if(str_contains(i,',')){
                    minilist <- c(minilist,(strsplit(i, ',')))
                }
                else{
                    minilist <- c(minilist, i)
                    
                }
            }
            
            wc_verb_df = df %>% select(chosen_verb_x, verb_colour)
            #tibble(chosen_verb_y = as.character(flatten(minilist)))
            
            
            verb_df <- count(wc_verb_df, chosen_verb_x, verb_colour)
            #final_verb_df <- inner_join(verb_df,df, by= 'chosen_verb_y' )
            #view(verb_df)
            
            #png("wordcloud.png", width=1280,height=800) 
            #png("wordcloud_packages.png", width=12,height=10, units='in', res=300)
            wordcloud(verb_df$chosen_verb_x, verb_df$n, max.words = 100, ordered.colors=TRUE,random.color=FALSE,min.freq = 1,
                      colors = verb_df$verb_colour)
                  
            
        } else
            wordcloud(verb_df$words, verb_df$n, max.words = 100, ordered.colors=TRUE,random.color=FALSE,min.freq = 1,
                      colors = verb_df$verb_colour)
    })
}
shinyApp(ui = ui, server = server)
