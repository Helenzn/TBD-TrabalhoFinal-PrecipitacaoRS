# functions.R - funcoes de acesso ao banco geografico
library(DBI)
library(RPostgres)
library(sf)

pdbuser     <- "postgres"
pdbpassword <- "SUA_SENHA"
pdbbanco    <- "bd_precipitacao_rs"
pdbhost     <- "localhost"
pdbport     <- 5432

conectar <- function() {
  dbConnect(RPostgres::Postgres(), user = pdbuser, password = pdbpassword,
            dbname = pdbbanco, host = pdbhost, port = pdbport)
}

# Executa uma consulta SQL e retorna um data frame (modelo do professor)
executaConsulta <- function(sql) {
  con <- conectar()
  on.exit(dbDisconnect(con))
  dbGetQuery(con, sql)
}

# Monta o WHERE a partir dos filtros escolhidos na tela
montarFiltro <- function(min_mm, max_mm, municipios = NULL) {
  filtro <- sprintf("p.media_mm BETWEEN %s AND %s", min_mm, max_mm)
  if (length(municipios) > 0) {
    lista <- paste0("'", municipios, "'", collapse = ",")
    filtro <- paste0(filtro, " AND p.cod_ibge IN (", lista, ")")
  }
  filtro
}

# Lista de municipios para o filtro
listarMunicipios <- function() {
  executaConsulta("SELECT cod_ibge, nome FROM precip_municipio ORDER BY nome")
}

# Tabela e grafico: precipitacao por municipio
buscarPrecipitacao <- function(min_mm, max_mm, municipios = NULL) {
  sql <- paste(
    "SELECT p.cod_ibge, p.nome, p.media_mm, p.min_mm, p.max_mm, p.n_pixels",
    "FROM precip_municipio p WHERE", montarFiltro(min_mm, max_mm, municipios),
    "ORDER BY p.media_mm DESC")
  executaConsulta(sql)
}

# Mapa: geometrias dos municipios (vetor) com a chuva calculada do raster
buscarMapa <- function(min_mm, max_mm, municipios = NULL) {
  sql <- paste(
    "SELECT p.cod_ibge, p.nome, p.media_mm,",
    "ST_Simplify(m.geometry, 0.005) AS geom",
    "FROM precip_municipio p",
    "JOIN municipios_ibge m ON m.\"CD_MUN\" = p.cod_ibge",
    "WHERE", montarFiltro(min_mm, max_mm, municipios))
  con <- conectar()
  on.exit(dbDisconnect(con))
  st_read(con, query = sql, quiet = TRUE)
}
