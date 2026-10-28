# ==============================================================================
# 01_donnees_outliers.R — Chargement des données et correction des points
#                         atypiques
# ------------------------------------------------------------------------------
# Entrée  : data/base_complete_dmto.csv
# Sortie  : dmto_ts (série brute), dmto_corr (série corrigée), outliers_tab
# ==============================================================================

# ---- 1. Chargement -----------------------------------------------------------
if (!file.exists(fichier_donnees)) {
  stop("Fichier introuvable : ", fichier_donnees,
       "\nVoir data/README.md pour le format attendu et les sources.",
       call. = FALSE)
}

donnees <- read_delim(
  fichier_donnees,
  delim = ";",
  locale = locale(decimal_mark = ".", grouping_mark = ","),
  show_col_types = FALSE
)

colonnes_attendues <- c("dmto_mensuel", "chomage_A", "ipc", "taux", "encours")
stopifnot(all(colonnes_attendues %in% names(donnees)))

dmto_ts <- ts(donnees$dmto_mensuel, start = debut_serie, frequency = frequence)

message("Série DMTO : ", length(dmto_ts), " observations (",
        mois_fr(min(dates_ts(dmto_ts))), " – ", mois_fr(max(dates_ts(dmto_ts))), ")")

# ---- 2. Graphique de la série brute ------------------------------------------
fig_serie <- autoplot(dmto_ts) +
  axe_millions() +
  labs(title = "DMTO mensuels — Loire-Atlantique",
       subtitle = "Régime de droit commun, montants perçus",
       x = NULL, y = NULL) +
  theme_projet()
sauver_ggplot(fig_serie, "01_serie_brute")

# ---- 3. Détection automatique des points atypiques (tso) --------------------
# tso() cherche trois types de chocs :
#   AO = choc ponctuel, TC = choc qui s'estompe, LS = changement de niveau
resultat_tso <- tso(dmto_ts)
dmto_corr    <- resultat_tso$yadj   # série corrigée, utilisée pour la suite

outliers_tab <- resultat_tso$outliers |>
  mutate(
    date        = dates_ts(dmto_ts)[ind],
    cle         = format(date, "%Y-%m"),
    Explication = ifelse(cle %in% names(explications_outliers),
                         explications_outliers[cle], "")
  ) |>
  transmute(
    Date          = format(date, "%Y-%m"),
    Type          = as.character(type),
    `Coefficient (€)` = format_nombre(coefhat),
    `t-stat`      = round(tstat, 3),
    Explication
  )

print(outliers_tab)
exporter_tableau(outliers_tab, "tab01_points_atypiques")

sauver_base("02_points_atypiques", plot(resultat_tso))

fig_corrigee <- autoplot(dmto_ts, series = "Série brute") +
  autolayer(dmto_corr, series = "Série corrigée") +
  scale_colour_manual(values = c("Série brute" = "grey65",
                                 "Série corrigée" = "steelblue")) +
  axe_millions() +
  labs(title = "Série brute et série corrigée des points atypiques",
       x = NULL, y = NULL, colour = NULL) +
  theme_projet()
sauver_ggplot(fig_corrigee, "03_serie_corrigee")
