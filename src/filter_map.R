library(tidyverse)
library(sjmisc)
library(readxl)
library(wordcloud)
# Define UI for application that draws a histogram
library(shiny)
library(leaflet)
library(DT)
data(quakes)
library(dplyr)

# Define UI
ui <- fluidPage(
    fluidRow(
        column(12,
               "title"),
        fluidRow(
            column(
                6,
                leafletOutput("mymap", height = 300)),
            column(6,
                   plotOutput("plot", height = 300))
        ),
        fluidRow(
            column(  6,
                     leafletOutput("my_verb_map", height = 300)),
            column(6,
                   plotOutput("plot_verb", height = 300))
            
        )
    )
    
)
    # leaflet box
 


# Define server logic 
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
            
            
            
            wordcloud(impact_df$impact, impact_df$n, max.words = 300, ordered.colors=TRUE,random.color=FALSE,
                      colors = as.character(impact_df$impact_colour), scale=c(3.5,0.25))
            
            
                

        } else
            wordcloud(impact_df$impact, impact_df$n,ordered.colors=TRUE, random.color=FALSE,max.words = 300, colors = as.character(impact_df$impact_colour), scale=c(3.5,0.25))
        })
    
    # plot for Impacts
    output$plot_verb = renderPlot({
        if (isTruthy(input$mymap_bounds)) {
            bounds = input$mymap_bounds
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
            
            
            wordcloud(verb_df$chosen_verb_x, verb_df$n, max.words = 100, ordered.colors=TRUE,
                      colors = verb_df$verb_colour)
            
            
        } else
            wordcloud(verb_df$words, verb_df$n, max.words = 100, ordered.colors=TRUE,
                      colors = verb_df$verb_colour)
    })
}
shinyApp(ui = ui, server = server)