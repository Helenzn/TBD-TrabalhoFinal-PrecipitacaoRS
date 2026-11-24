# Precipitação no RS — maio de 2024

Trabalho final de **Tópicos em Banco de Dados** · Bacharelado em Ciência da Computação · IFSul Campus Passo Fundo
Aluna: **Helen Zanco Neis** · Prof. Alexandre Tagliari Lazzaretti · Apresentação: 24/11/2026

Aplicação em **R + Shiny** que acessa um banco geográfico **PostgreSQL/PostGIS** com um dado raster (chuva do CHIRPS) e um dado vetorial (municípios do IBGE), e mostra a precipitação de maio de 2024 por município do Rio Grande do Sul em **tabela, gráfico e mapa (Leaflet)**, com filtros.

## Por que este tema

Em maio de 2024 o Rio Grande do Sul viveu as maiores enchentes da sua história. Com dados públicos de satélite e um banco geográfico, dá para ver, município por município, onde choveu mais — e isso ajuda na prevenção.

## Requisitos do trabalho

| Requisito | Como foi atendido |
|---|---|
| Aplicação na linguagem R | App Shiny com `ui.R`, `server.R` e `functions.R` |
| Acessa o banco geográfico | PostgreSQL 18 + PostGIS 3.7, banco `bd_precipitacao_rs` |
| Filtros nos dados | Por município, faixa de precipitação média e quantidade no gráfico |
| Tabela, gráfico e mapa | Tabela com DT, gráfico de barras e mapa com Leaflet |
| Dado raster com fonte | CHIRPS v3.0, maio de 2024 · Climate Hazards Center (UCSB) |
| Dado vetorial com fonte | Malha Municipal 2024 do RS · IBGE |

## Fontes dos dados

- **Raster — CHIRPS v3.0, maio de 2024.** Climate Hazards Center, University of California, Santa Barbara. Precipitação estimada por satélite e estações, em mm por pixel de 0,05°.
  Arquivo: `chirps-v3.0.2024.05.tif` — https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/global/tifs/chirps-v3.0.2024.05.tif
- **Vetorial — Malha Municipal 2024 do RS.** IBGE, Malhas Territoriais. Shapefile em SIRGAS 2000 geográfico (EPSG 4674).
  Arquivo: `RS_Municipios_2024.zip` — https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/RS/RS_Municipios_2024.zip

## Como tudo se conecta

1. **Arquivos:** `chirps_2024_05.tif` (raster) e `RS_Municipios_2024.shp` (vetorial).
2. **Carga:** o raster entra com `raster2pgsql` (Prompt de Comando); os municípios entram pelo R com `sf::st_write`, convertidos de 4674 para 4326.
3. **PostGIS:** tabelas `raster_data` e `municipios_ibge`; a transformação gera `precip_municipio` (chuva média, mínima e máxima por município).
4. **App Shiny:** `functions.R` faz as consultas; `ui.R` e `server.R` mostram tabela, gráfico e mapa.

## Passo a passo

### 1. Instalações

| Ferramenta | Versão | Como foi instalada |
|---|---|---|
| PostgreSQL e pgAdmin 4 | 18 | Já estava no computador |
| PostGIS Bundle | 3.7.0 | Stack Builder › Spatial Extensions |
| R for Windows | 4.6.2 | cran.r-project.org |
| RStudio Desktop | atual | posit.co |
| Pacotes do R | CRAN | shiny, leaflet, DBI, RPostgres, sf e DT |

```r
install.packages(c("shiny", "leaflet", "DBI", "RPostgres", "sf", "DT"))
library(shiny); library(leaflet); library(DBI); library(RPostgres); library(sf); library(DT)
```

### 2. Banco de dados (pgAdmin, Query Tool)

```sql
CREATE DATABASE bd_precipitacao_rs;

-- conectado no bd_precipitacao_rs
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_raster;
CREATE TABLE raster_data (
  id bigserial PRIMARY KEY,
  date date DEFAULT current_date,
  rast raster,
  filename text
);
SELECT PostGIS_Full_Version();
```

### 3. Download do raster (console do R)

No trabalho de fontes raster foi usado o CHIRPS 2.0; agora o Climate Hazards Center publica a versão 3.0.

```r
dir.create("C:/dados")
url3 <- "https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/global/tifs/chirps-v3.0.2024.05.tif"
download.file(url3, "C:/dados/chirps_2024_05.tif", mode = "wb")
file.exists("C:/dados/chirps_2024_05.tif")  # TRUE
```

### 4. Dado vetorial (console do R)

```r
url_ibge <- "https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/RS/RS_Municipios_2024.zip"
download.file(url_ibge, "C:/dados/RS_Municipios_2024.zip", mode = "wb")
unzip("C:/dados/RS_Municipios_2024.zip", exdir = "C:/dados/municipios")

shp <- list.files("C:/dados/municipios", pattern = "\\.shp$", full.names = TRUE)
mun <- st_read(shp)
mun <- st_transform(mun, 4326)  # SIRGAS 2000 -> WGS 84

con <- dbConnect(RPostgres::Postgres(), dbname = "bd_precipitacao_rs",
                 host = "localhost", port = 5432, user = "postgres", password = "SUA_SENHA")
st_write(mun, con, "municipios_ibge", delete_layer = TRUE)
dbGetQuery(con, "SELECT COUNT(*), ST_SRID(geometry) FROM municipios_ibge GROUP BY 2")
```

Resultado: **499 feições com SRID 4326** — os 497 municípios do RS mais a Lagoa dos Patos e a Lagoa Mirim.

### 5. Importação do raster (Prompt de Comando)

```bat
cd "C:\Program Files\PostgreSQL\18\bin"
raster2pgsql -s 4326 -I -M -F -t 200x200 -a C:\dados\chirps_2024_05.tif public.raster_data | psql -U postgres -d bd_precipitacao_rs
```

| Opção | O que faz |
|---|---|
| `-s 4326` | Define o SRID do raster (WGS 84) |
| `-I` e `-M` | Cria índice espacial e analisa a tabela depois da carga |
| `-F` | Guarda o nome do arquivo na coluna `filename` |
| `-t 200x200` | Divide a imagem em blocos de 200 por 200 pixels |
| `-a public.raster_data` | Adiciona os blocos à tabela que já existe |
| `\| psql` | Envia o SQL gerado direto para o banco |

### 6. Transformação: chuva por município

A primeira versão (com `ST_SummaryStatsAgg`) gerou médias perto de −1,4 × 10³⁸, porque os pixels sem dado (NoData, −3,4 × 10³⁸) entraram na conta. A versão corrigida considera só pixels válidos:

```sql
CREATE TABLE precip_municipio AS
SELECT m."CD_MUN" AS cod_ibge,
       m."NM_MUN" AS nome,
       COUNT(*) AS n_pixels,
       ROUND(AVG(p.val)::numeric, 1) AS media_mm,
       ROUND(MIN(p.val)::numeric, 1) AS min_mm,
       ROUND(MAX(p.val)::numeric, 1) AS max_mm
FROM municipios_ibge m
JOIN raster_data r
  ON ST_Intersects(r.rast, m.geometry)
CROSS JOIN LATERAL
  ST_PixelAsPoints(ST_Clip(r.rast, m.geometry), 1) p
WHERE p.val >= 0
GROUP BY m."CD_MUN", m."NM_MUN";
```

## O aplicativo

| Arquivo | Papel |
|---|---|
| `functions.R` | Conexão e consultas ao banco: `executaConsulta()` (modelo do professor), `conectar()`, `montarFiltro()`, `listarMunicipios()`, `buscarPrecipitacao()` e `buscarMapa()` |
| `ui.R` | Interface: filtros na lateral (municípios, faixa de 0 a 800 mm, quantidade no gráfico) e abas Mapa, Gráfico e Tabela |
| `server.R` | Lógica reativa: `reactive()` refaz a consulta quando um filtro muda; `renderDT`, `renderPlot` e `renderLeaflet` montam as saídas |

### Como rodar

1. Crie o banco e carregue os dados seguindo o passo a passo acima.
2. Em `functions.R`, troque `SUA_SENHA` pela senha do seu PostgreSQL.
3. No R:

```r
shiny::runApp("C:/dados/app")
```

## Análise: onde mais choveu em maio de 2024

| Município | Precipitação média (mm) |
|---|---|
| Anta Gorda | 757,0 |
| Dois Lajeados | 725,4 |
| Ilópolis | 709,1 |
| Arvorezinha | 689,0 |
| Guaporé | 674,1 |
| Itapuca | 666,1 |
| União da Serra | 659,4 |
| Nova Alvorada | 657,9 |
| Putinga | 656,8 |
| Vespasiano Corrêa | 655,5 |

Os dez ficam no Vale do Taquari e na Serra, a região mais atingida pelas cheias. Em Uruguaiana, na Fronteira Oeste, o pixel mais chuvoso marcou 89,4 mm.

- **Monitorar:** o CHIRPS é público e mensal; trocando o arquivo, o mesmo processo vale para qualquer mês.
- **Prevenir:** saber onde a chuva se concentra ajuda a planejar alertas e a defesa civil.
- **Comunicar:** filtros, mapa e gráfico levam o dado do banco a quem não sabe SQL.

## Conteúdos do semestre usados

| Conteúdo | Onde aparece |
|---|---|
| Subconsultas | `CREATE TABLE … AS SELECT` e `CROSS JOIN LATERAL` para calcular a chuva de cada município |
| COPY | Na aula, o `shp2pgsql` carregou os municípios no banco com o comando COPY |
| Modelos geográficos | Raster (pixels com mm de chuva) e vetor (polígonos) no mesmo SRID 4326 |
| PostGIS | `postgis` e `postgis_raster`; `ST_Intersects`, `ST_Clip`, `ST_PixelAsPoints` e `ST_Simplify` |
| Dados e fontes raster | CHIRPS v3.0 (UCSB), GeoTIFF carregado com `raster2pgsql` em blocos de 200×200 |
| Shapefiles e vetores | Malha Municipal 2024 do IBGE, lida com `sf::st_read` e gravada com `st_write` |
| Linguagem R | `dir.create`, `download.file`, `unzip` e o pacote `sf` para baixar e preparar os dados |
| Funções em R | `functions.R` com `executaConsulta()`, no modelo do professor, chamado por `source()` |
| Pacote Shiny | `ui.R` e `server.R` com filtros, `reactive`, mapa Leaflet, gráfico e tabela DT |
