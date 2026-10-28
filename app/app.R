# ==============================================================================
# Application Shiny — Prévision des DMTO en Loire-Atlantique
# ------------------------------------------------------------------------------
# L'app lit les résultats produits par run_all.R (fichier donnees_app.rds) :
# elle n'estime aucun modèle, ce qui la rend rapide et facile à mettre en ligne.
#
# Lancement (depuis la racine du projet) :  shiny::runApp("app")
# ==============================================================================

library(shiny)
library(shinythemes)
library(plotly)

fichier <- "donnees_app.rds"
if (!file.exists(fichier)) {
  stop("donnees_app.rds introuvable : lance d'abord source(\"run_all.R\") ",
       "depuis la racine du projet.", call. = FALSE)
}
d <- readRDS(fichier)

# ---- Petites fonctions d'affichage -------------------------------------------
millions <- function(x, decimales = 1) {
  paste(formatC(x / 1e6, format = "f", digits = decimales, decimal.mark = ","), "M€")
}
pourcent <- function(x, decimales = 1) {
  paste0(formatC(x, format = "f", digits = decimales, decimal.mark = ","), " %")
}

carte_kpi <- function(valeur, libelle, couleur) {
  div(style = paste0("background:", couleur, "; color:white; padding:16px;",
                     "border-radius:8px; text-align:center; margin-bottom:10px"),
      h3(valeur, style = "margin:0; font-size:28px"),
      p(libelle, style = "margin:4px 0 0; font-size:12px; opacity:0.9"))
}

mise_en_page <- function(p, titre) {
  layout(p,
         title = list(text = titre, font = list(size = 14)),
         xaxis = list(title = ""),
         yaxis = list(title = "Montant (€)", tickformat = ",.0f"),
         hovermode = "x unified",
         legend = list(orientation = "h", y = -0.15))
}

choix_modeles <- setNames(names(d$noms_modeles), d$noms_modeles)

# ---- Interface ---------------------------------------------------------------
ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel(div(
    h3("Prévision des DMTO en Loire-Atlantique", style = "margin-bottom:4px"),
    p("Mémoire de Master 1 Économétrie appliquée — IAE Nantes | David DIOP",
      style = "color:#7f8c8d; font-size:14px")
  ), windowTitle = "Prévision DMTO 44"),

  tabsetPanel(
    # -- Onglet 1 : la série et ses points atypiques --
    tabPanel("Série et points atypiques", br(),
      plotlyOutput("graph_serie", height = "420px"), br(),
      fluidRow(
        column(4, carte_kpi(d$nb_obs, "observations mensuelles", "#2e86de")),
        column(4, carte_kpi(nrow(d$outliers), "points atypiques détectés et corrigés",
                            "#c0392b")),
        column(4, carte_kpi(pourcent(d$part_saison),
                            "de la variance due à la saisonnalité (X13)", "#1e8449"))
      )
    ),

    # -- Onglet 2 : comparaison des modèles sur la période de test --
    tabPanel("Comparaison des modèles", br(),
      fluidRow(
        column(3, wellPanel(
          h5("Modèles à afficher"),
          checkboxGroupInput("modeles", NULL, choices = choix_modeles,
                             selected = c("naive", "hw", "ets")),
          hr(),
          h5("Performances (période de test)"),
          tableOutput("tableau_perf"),
          p("R²OOS : réduction de l'erreur par rapport à la naïve saisonnière.",
            style = "color:#7f8c8d; font-size:11px")
        )),
        column(9, plotlyOutput("graph_prev", height = "460px"))
      )
    ),

    # -- Onglet 3 : prévision finale --
    tabPanel("Prévision 12 mois", br(),
      fluidRow(
        column(3, wellPanel(
          checkboxInput("ic80", "Intervalle de confiance 80 %", TRUE),
          checkboxInput("ic95", "Intervalle de confiance 95 %", TRUE),
          checkboxInput("reel", "Montants réellement perçus", TRUE),
          hr(),
          h5("Total prévu sur 12 mois"),
          h3(paste("≈", millions(d$total_annuel, 0)),
             style = "color:#1e8449; font-weight:bold"),
          p(paste("Modèle :", d$nom_modele_final), style = "font-size:12px"),
          hr(),
          h5("Validation partielle"),
          uiOutput("texte_validation")
        )),
        column(9, plotlyOutput("graph_finale", height = "460px"))
      )
    )
  )
)

# ---- Serveur -----------------------------------------------------------------
server <- function(input, output, session) {

  output$graph_serie <- renderPlotly({
    plot_ly(d$serie, x = ~date, y = ~valeur, type = "scatter", mode = "lines",
            name = "DMTO mensuels", line = list(color = "#2e86de", width = 1.2)) |>
      add_trace(data = d$outliers, x = ~date, y = ~valeur, text = ~label,
                type = "scatter", mode = "markers", name = "Point atypique",
                hoverinfo = "text", marker = list(color = "#c0392b", size = 9),
                inherit = FALSE) |>
      mise_en_page("DMTO mensuels — série brute")
  })

  output$tableau_perf <- renderTable({
    perf <- d$performances
    data.frame(Modèle = perf$Modèle,
               MAPE   = pourcent(perf$MAPE),
               R2OOS  = formatC(perf$R2OOS, format = "f", digits = 3,
                                decimal.mark = ","))
  }, striped = TRUE, spacing = "xs")

  output$graph_prev <- renderPlotly({
    p <- plot_ly(d$test, x = ~date, y = ~reel, type = "scatter",
                 mode = "lines+markers", name = "Réel",
                 line = list(color = "black", width = 2.5),
                 marker = list(color = "black", size = 6))
    for (m in input$modeles) {
      nom <- d$noms_modeles[[m]]
      p <- add_trace(p, x = d$test$date, y = d$previsions[[m]], name = nom,
                     type = "scatter", mode = "lines", inherit = FALSE,
                     line = list(color = d$couleurs[[nom]], width = 1.6,
                                 dash = if (m == "naive") "dash" else "solid"))
    }
    mise_en_page(p, "Prévisions vs valeurs réelles — période de test")
  })

  output$graph_finale <- renderPlotly({
    f <- d$finale
    p <- plot_ly()
    bande <- function(p, bas, haut, opacite, nom) {
      p |>
        add_trace(x = f$date, y = f[[haut]], type = "scatter", mode = "lines",
                  line = list(color = "transparent"), showlegend = FALSE,
                  hoverinfo = "skip") |>
        add_trace(x = f$date, y = f[[bas]], type = "scatter", mode = "lines",
                  fill = "tonexty", fillcolor = paste0("rgba(46,134,222,", opacite, ")"),
                  line = list(color = "transparent"), name = nom)
    }
    if (input$ic95) p <- bande(p, "lo95", "hi95", 0.15, "IC 95 %")
    if (input$ic80) p <- bande(p, "lo80", "hi80", 0.30, "IC 80 %")
    p <- add_trace(p, x = f$date, y = f$prevision, type = "scatter",
                   mode = "lines+markers", name = d$nom_modele_final,
                   line = list(color = "#2e86de", width = 2.5),
                   marker = list(color = "#2e86de", size = 6))
    if (input$reel && nrow(d$validation) > 0) {
      p <- add_trace(p, x = d$validation$date, y = d$validation$reel,
                     type = "scatter", mode = "markers", name = "Réel",
                     marker = list(color = "#c0392b", size = 12, symbol = "star"))
    }
    mise_en_page(p, "Prévision des 12 prochains mois")
  })

  output$texte_validation <- renderUI({
    v <- d$validation
    if (nrow(v) == 0) return(p("Pas encore de montant publié."))
    tagList(
      lapply(seq_len(nrow(v)), function(i) {
        p(sprintf("%s : réel %s, prévu %s (%s)",
                  format(v$date[i], "%m/%Y"), millions(v$reel[i]),
                  millions(v$prevision[i]),
                  if (v$dans_ic95[i]) "dans l'IC 95 %" else "hors IC 95 %"),
          style = "font-size:12px")
      })
    )
  })
}

shinyApp(ui, server)
