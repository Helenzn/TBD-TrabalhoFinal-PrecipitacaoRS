# ui.R - interface do aplicativo
library(shiny)
library(leaflet)
library(DT)
source("functions.R")

municipios <- listarMunicipios()
opcoes <- setNames(municipios$cod_ibge, municipios$nome)

fluidPage(
  titlePanel("Precipitação no RS - Maio de 2024 (CHIRPS + IBGE)"),
  sidebarLayout(
    sidebarPanel(
      selectizeInput("municipios", "Municípios (vazio = todos):",
                     choices = opcoes, multiple = TRUE),
      sliderInput("faixa", "Precipitação média (mm):",
                  min = 0, max = 800, value = c(0, 800)),
      sliderInput("top", "Quantidade de municípios no gráfico:",
                  min = 5, max = 30, value = 15),
      hr(),
      p("Raster: CHIRPS v3.0, Climate Hazards Center - UCSB."),
      p("Vetorial: Malha Municipal 2024, IBGE.")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Mapa", leafletOutput("mapa", height = 600)),
        tabPanel("Gráfico", plotOutput("grafico", height = 600)),
        tabPanel("Tabela", DTOutput("tabela"))
      )
    )
  )
)
