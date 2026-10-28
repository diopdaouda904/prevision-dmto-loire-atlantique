# ==============================================================================
# utils.R — Fonctions réutilisées dans tout le projet
# ------------------------------------------------------------------------------
# Écrire une fonction une fois évite de copier-coller le même bloc de code
# (dans la version d'origine, le style des tableaux Word était répété 8 fois).
# ==============================================================================

# ---- Dates -------------------------------------------------------------------

# Convertit l'axe temps d'une série ts mensuelle en vraies dates (1er du mois)
dates_ts <- function(x) {
  as.Date(zoo::as.yearmon(time(x)))
}

# "2026-03-01" -> "Mars 2026" (indépendant de la langue du système)
mois_fr <- function(dates) {
  noms <- c("Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet",
            "Août", "Septembre", "Octobre", "Novembre", "Décembre")
  paste(noms[as.integer(format(dates, "%m"))], format(dates, "%Y"))
}

# ---- Critères de qualité de prévision ----------------------------------------

mse  <- function(reel, prevu) mean((reel - prevu)^2)
rmse <- function(reel, prevu) sqrt(mse(reel, prevu))
mape <- function(reel, prevu) mean(abs((reel - prevu) / reel)) * 100

# R² hors échantillon : part de l'erreur quadratique de la naïve qu'on élimine.
# > 0 : le modèle fait mieux que la naïve ; < 0 : il fait moins bien.
r2oos <- function(mse_modele, mse_reference) 1 - mse_modele / mse_reference

# ---- Mise en forme -----------------------------------------------------------

format_nombre <- function(x, decimales = 0) {
  formatC(x, format = "f", digits = decimales, big.mark = " ")
}

format_p <- function(p) {
  ifelse(p < 0.001, formatC(p, format = "e", digits = 2),
         formatC(p, format = "f", digits = 3))
}

# ---- Tests statistiques ------------------------------------------------------

# ADF + KPSS sur une série. Les p-values du KPSS sont tabulées par le package :
# elles sont bornées entre 0,01 et 0,10, d'où l'affichage "< 0.01" / "> 0.10".
test_stationnarite <- function(x) {
  adf  <- suppressWarnings(tseries::adf.test(x))
  kpss <- suppressWarnings(tseries::kpss.test(x, null = "Level"))
  data.frame(
    adf_stat   = unname(adf$statistic),
    adf_p      = adf$p.value,
    kpss_stat  = unname(kpss$statistic),
    kpss_p     = kpss$p.value,
    stationnaire = adf$p.value < seuil & kpss$p.value > seuil
  )
}

affiche_p_kpss <- function(p) {
  ifelse(p <= 0.01, "< 0.01", ifelse(p >= 0.10, "> 0.10", format_p(p)))
}

affiche_p_adf <- function(p) {
  ifelse(p <= 0.01, "< 0.01", format_p(p))
}

# Ordre d'intégration : nombre de différenciations nécessaires pour que
# ADF (rejet de la racine unitaire) et KPSS (non-rejet) concluent ensemble
# à la stationnarité.
ordre_integration <- function(x, d_max = 2) {
  for (d in 0:d_max) {
    serie <- if (d == 0) x else diff(x, differences = d)
    if (test_stationnarite(serie)$stationnaire) return(d)
  }
  NA_integer_
}

# Test de Ljung-Box sur les résidus d'un modèle.
# Pour un ARIMA, on retire les degrés de liberté des coefficients estimés
# (comme forecast::checkresiduals) ; pour les autres modèles, fitdf = 0.
ljung_box <- function(modele, lag = lag_ljung) {
  fitdf <- if (inherits(modele, "Arima")) length(coef(modele)) else 0
  test <- Box.test(residuals(modele), lag = lag, type = "Ljung-Box",
                   fitdf = fitdf)
  data.frame(Q = unname(test$statistic), ddl = unname(test$parameter),
             p_value = test$p.value)
}

# ---- Export des tableaux -----------------------------------------------------

# Style "académique" commun à tous les tableaux Word du mémoire
style_tableau <- function(df, lignes_surlignees = NULL,
                          couleur = "#E2EFDA") {
  bordure_epaisse <- officer::fp_border(color = "black", width = 1.5)
  bordure_fine    <- officer::fp_border(color = "black", width = 1)

  ft <- flextable(df) |>
    bold(part = "header") |>
    align(part = "all", align = "center") |>
    align(j = 1, part = "body", align = "left") |>
    border_remove() |>
    hline_top(part = "header", border = bordure_epaisse) |>
    hline_bottom(part = "header", border = bordure_fine) |>
    hline_bottom(part = "body", border = bordure_epaisse) |>
    font(fontname = "Times New Roman", part = "all") |>
    fontsize(size = 11, part = "all")

  if (!is.null(lignes_surlignees)) {
    ft <- bg(ft, i = lignes_surlignees, bg = couleur, part = "body")
  }
  autofit(ft)
}

# Enregistre un tableau en .csv (lisible partout, y compris sur GitHub)
# et en .docx (prêt à coller dans un rapport)
exporter_tableau <- function(df, nom, ...) {
  readr::write_csv(df, file.path(dossier_tableaux, paste0(nom, ".csv")))
  save_as_docx(style_tableau(df, ...),
               path = file.path(dossier_tableaux, paste0(nom, ".docx")))
  invisible(df)
}

# ---- Export des figures ------------------------------------------------------

theme_projet <- function() {
  theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"),
          plot.subtitle = element_text(colour = "grey40"),
          legend.position = "bottom")
}

axe_millions <- function() {
  scale_y_continuous(labels = function(x) paste(format_nombre(x / 1e6), "M€"))
}

sauver_ggplot <- function(graphique, nom, largeur = 9, hauteur = 5) {
  ggsave(file.path(dossier_figures, paste0(nom, ".png")), graphique,
         width = largeur, height = hauteur, dpi = 150, bg = "white")
  invisible(graphique)
}

# Pour les graphiques en R de base (plot, acf...) : ouvre le fichier png,
# exécute le code du graphique, puis ferme le fichier quoi qu'il arrive.
sauver_base <- function(nom, code_graphique, largeur = 1200, hauteur = 800) {
  png(file.path(dossier_figures, paste0(nom, ".png")),
      width = largeur, height = hauteur, res = 150)
  on.exit(dev.off())
  force(code_graphique)
  invisible(NULL)
}
