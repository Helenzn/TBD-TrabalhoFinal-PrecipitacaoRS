# server.R - logica do aplicativo
library(shiny)
library(leaflet)
library(DT)
library(sf)
source("functions.R")

function(input, output, session) {

  dados <- reactive({
    buscarPrecipitacao(input$faixa[1], input$faixa[2], input$municipios)
  })

  dados_mapa <- reactive({
    buscarMapa(input$faixa[1], input$faixa[2], input$municipios)
  })

  output$tabela <- renderDT({
    datatable(dados(), rownames = FALSE,
              colnames = c("Código IBGE", "Município", "Média (mm)",
                           "Mínima (mm)", "Máxima (mm)", "Pixels"))
  })

  output$grafico <- renderPlot({
    d <- head(dados(), input$top)
    validate(need(nrow(d) > 0, "Nenhum município encontrado com esses filtros."))
    par(mar = c(5, 12, 3, 2))
    barplot(rev(d$media_mm), names.arg = rev(d$nome), horiz = TRUE, las = 1,
            col = "steelblue", xlab = "Precipitação média (mm)",
            main = "Municípios com maior precipitação - maio/2024")
  })

  output$mapa <- renderLeaflet({
    m <- dados_mapa()
    validate(need(nrow(m) > 0, "Nenhum município encontrado com esses filtros."))
    pal <- colorNumeric("Blues", domain = m$media_mm)
    leaflet(m) |>
      addTiles() |>
      addPolygons(fillColor = ~pal(media_mm), fillOpacity = 0.8,
                  color = "white", weight = 1,
                  label = ~paste0(nome, ": ", media_mm, " mm")) |>
      addLegend(pal = pal, values = ~media_mm, title = "Chuva (mm)")
  })
}
