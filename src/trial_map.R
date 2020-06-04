location_data <- read_excel("../data/TransLink Raw Data/Claim_colour_df.xlsx")

# leaflet map

  # Show first 20 rows from the `quakes` dataset
  leaflet() %>%
    addProviderTiles("CartoDB.Positron") %>%
    addCircleMarkers(lng=location_data$long, lat=location_data$latt, radius=4,fillOpacity=0.5, color = location_data$claim_colour)
  
  if (isTruthy(input$mymap_bounds)) {
    bounds = input$mymap_bounds
    df <- location_data %>% filter(
      between(long, bounds$west, bounds$east),
      between(latt, bounds$south, bounds$north)
    )
    
    
    wc_df_impact <- df %>% select(impact)
    impact_df <- count(wc_df_impact, impact)
    #basecolors = rainbow(length(unique(group)))
    final_df <- inner_join(impact_df,df, by= impact )
    view(final_df)

    
    
    wordcloud(final_df$impact, final_df$n, max.words = 100, ordered.colors=TRUE,
              colors = final_df$claim_colour)
  } else
    wordcloud(impact_df$impact, impact_df$n, max.words = 100, colors = df$claim_colour)
  