# ==============================================================================
# 00_config.R — Packages, chemins et paramètres du projet
# ------------------------------------------------------------------------------
# Tous les réglages modifiables sont regroupés ici : on ne les répète pas
# dans les autres scripts.
# ==============================================================================

# ---- Packages ----------------------------------------------------------------
packages <- c(
  "readr", "dplyr", "ggplot2", "zoo",          # manipulation et graphiques
  "forecast", "tseries", "tsoutliers",         # séries temporelles
  "seastests", "RJDemetra", "smooth",          # saisonnalité, X13, ADAM
  "moments", "flextable", "officer"            # statistiques et export Word
)

manquants <- packages[!packages %in% rownames(installed.packages())]
if (length(manquants) > 0) {
  stop(
    "Packages manquants : ", paste(manquants, collapse = ", "),
    "\nInstalle-les avec : install.packages(c(\"",
    paste(manquants, collapse = "\", \""), "\"))",
    call. = FALSE
  )
}

suppressPackageStartupMessages(
  invisible(lapply(packages, library, character.only = TRUE))
)

# ---- Chemins -----------------------------------------------------------------
fichier_donnees <- file.path("data", "base_complete_dmto.csv")
dossier_figures <- file.path("outputs", "figures")
dossier_tableaux <- file.path("outputs", "tables")
fichier_app <- file.path("app", "donnees_app.rds")

dir.create(dossier_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(dossier_tableaux, recursive = TRUE, showWarnings = FALSE)

# ---- Paramètres de l'étude ---------------------------------------------------
debut_serie <- c(2000, 1)   # janvier 2000
frequence   <- 12           # données mensuelles
n_test      <- 12           # 12 derniers mois gardés pour tester les prévisions
horizon     <- 12           # horizon de la prévision finale (en mois)
seuil       <- 0.05         # seuil des tests statistiques
lag_ljung   <- 24           # nombre de retards du test de Ljung-Box

set.seed(2026)              # reproductibilité

# ---- Validation partielle ----------------------------------------------------
# Montants réellement perçus, publiés après la fin de l'étude (DGFiP / IGEDD).
# Ils servent à confronter la prévision finale à la réalité.
validation_reelle <- data.frame(
  date = as.Date(c("2026-03-01", "2026-04-01")),
  reel = c(25606529, 22593521)
)

# ---- Interprétation économique des points atypiques --------------------------
# La détection est automatique (tso). L'explication, elle, vient de l'analyse
# du marché immobilier : on la renseigne ici, par date "AAAA-MM".
explications_outliers <- c(
  "2010-05" = "Rebond technique après le creux de 2009",
  "2012-02" = "Turbulences post-crise financière de 2008",
  "2015-01" = "Début de la reprise du marché immobilier national",
  "2020-04" = "Effondrement brutal dû au premier confinement",
  "2020-06" = "Rattrapage massif après le déconfinement",
  "2020-09" = "Boom immobilier post-Covid (exode urbain)"
)

# ---- Noms et couleurs des modèles (mêmes partout : figures, tableaux, app) ---
noms_modeles <- c(
  naive         = "Naïve saisonnière",
  hw            = "Holt-Winters",
  ets           = "ETS",
  sarima        = "SARIMA",
  adam          = "ADAM ETS",
  arimax        = "ARIMAX complet",
  arimax_select = "ARIMAX sélectionné"
)

couleurs_modeles <- c(
  "Naïve saisonnière"  = "#7f8c8d",
  "Holt-Winters"       = "#2e86de",
  "ETS"                = "#1e8449",
  "SARIMA"             = "#e67e22",
  "ADAM ETS"           = "#8e44ad",
  "ARIMAX complet"     = "#c0392b",
  "ARIMAX sélectionné" = "#f1948a",
  "Réel"               = "#000000"
)
