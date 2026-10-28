# ==============================================================================
# run_all.R — Lance toute l'analyse, de la donnée brute à la prévision finale
# ------------------------------------------------------------------------------
# Utilisation : ouvrir le projet dans RStudio (dossier racine), puis
#   source("run_all.R")
# Résultats   : outputs/figures (png), outputs/tables (csv + docx),
#               app/donnees_app.rds (pour l'application Shiny)
# ==============================================================================

etapes <- c(
  "R/00_config.R",
  "R/utils.R",
  "R/01_donnees_outliers.R",
  "R/02_analyse_exploratoire.R",
  "R/03_modeles_univaries.R",
  "R/04_arimax.R",
  "R/05_evaluation.R",
  "R/06_prevision_finale.R"
)

debut <- Sys.time()
for (script in etapes) {
  message("\n==> ", script)
  source(script, encoding = "UTF-8")
}
# Versions de R et des packages utilisées : utile pour comprendre un écart
# de résultat d'un ordinateur à l'autre
writeLines(capture.output(sessionInfo()), file.path("outputs", "session_info.txt"))

message("\nAnalyse terminée en ",
        round(as.numeric(difftime(Sys.time(), debut, units = "mins")), 1), " min.")
