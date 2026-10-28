# ==============================================================================
# 04_arimax.R — Modèle ARIMAX avec variables macroéconomiques
# ------------------------------------------------------------------------------
# Question : l'information macroéconomique (chômage, inflation, taux et
# encours de crédit à l'habitat) améliore-t-elle les prévisions ?
# Sortie  : modeles$arimax, modeles$arimax_select et leurs prévisions
# ==============================================================================

# ---- 1. Variables explicatives -----------------------------------------------
variables <- list(
  Chomage = ts(donnees$chomage_A, start = debut_serie, frequency = frequence),
  IPC     = ts(donnees$ipc,       start = debut_serie, frequency = frequence),
  Taux    = ts(donnees$taux,      start = debut_serie, frequency = frequence),
  Encours = ts(donnees$encours,   start = debut_serie, frequency = frequence)
)

# Les derniers mois ne sont pas toujours publiés au moment de l'étude
# (ex. IPC de janvier-février 2026). On reprend la dernière valeur connue
# (méthode "LOCF"), et on le signale.
variables <- lapply(names(variables), function(nom) {
  x <- variables[[nom]]
  manquants <- which(is.na(x))
  if (length(manquants) > 0) {
    message(nom, " : ", length(manquants), " valeur(s) manquante(s) (",
            paste(mois_fr(dates_ts(x)[manquants]), collapse = ", "),
            ") remplacée(s) par la dernière valeur connue")
    x[] <- zoo::na.locf(as.numeric(x), na.rm = FALSE)
  }
  x
}) |> setNames(names(variables))

# ---- 2. Stationnarité : ordre d'intégration de chaque variable ---------------
diagnostic_variable <- function(x, nom) {
  niveaux <- lapply(0:2, function(d) {
    test_stationnarite(if (d == 0) x else diff(x, differences = d))
  })
  ordre <- ordre_integration(x)
  data.frame(
    Variable       = nom,
    `ADF niveau`   = affiche_p_adf(niveaux[[1]]$adf_p),
    `KPSS niveau`  = affiche_p_kpss(niveaux[[1]]$kpss_p),
    `ADF diff(1)`  = affiche_p_adf(niveaux[[2]]$adf_p),
    `KPSS diff(1)` = affiche_p_kpss(niveaux[[2]]$kpss_p),
    `ADF diff(2)`  = if (ordre == 2) affiche_p_adf(niveaux[[3]]$adf_p) else "—",
    `KPSS diff(2)` = if (ordre == 2) affiche_p_kpss(niveaux[[3]]$kpss_p) else "—",
    Ordre          = paste0("I(", ordre, ")"),
    ordre_num      = ordre,
    check.names = FALSE
  )
}

tab_statio_vars <- do.call(rbind, Map(diagnostic_variable, variables, names(variables)))
ordres <- setNames(tab_statio_vars$ordre_num, tab_statio_vars$Variable)
tab_statio_vars$ordre_num <- NULL
print(tab_statio_vars)
exporter_tableau(tab_statio_vars, "tab07_stationnarite_variables",
                 lignes_surlignees = which(ordres == 2), couleur = "#FFF3CD")

# ---- 3. Saisonnalité : désaisonnalisation X13 si le test WO la détecte -------
saisonnalite_vars <- sapply(variables, isSeasonal, test = "wo")
print(saisonnalite_vars)

variables_cvs <- Map(function(x, saisonniere) {
  if (saisonniere) x13(x, x13_spec("RSA5c"))$final$series[, "sa"] else x
}, variables, saisonnalite_vars)

# ---- 4. Mise en forme des régresseurs ----------------------------------------
# auto.arima(d = 1) différencie une fois la cible ET les régresseurs.
# Une variable I(1) est donc fournie en niveau ; une variable I(2) (l'encours)
# est différenciée une fois au préalable pour être différenciée deux fois au total.
regresseurs <- Map(function(x, ordre) {
  if (ordre >= 2) diff(x, differences = ordre - 1) else x
}, variables_cvs, ordres)

# Toutes les séries doivent couvrir la même période : la différenciation
# préalable de l'encours fait perdre le 1er mois (janvier 2000).
debut_commun <- max(sapply(regresseurs, function(x) time(x)[1]))
fin_train    <- tail(time(dmto_train), 1)
debut_test   <- time(dmto_test)[1]
fin_test     <- tail(time(dmto_test), 1)

matrice_xreg <- function(noms, debut, fin) {
  do.call(cbind, lapply(regresseurs[noms], function(x) {
    as.numeric(window(x, start = debut, end = fin))
  })) |> `colnames<-`(noms)
}

dmto_train_x <- window(dmto_corr, start = debut_commun, end = fin_train)

estimer_arimax <- function(noms) {
  auto.arima(dmto_train_x,
             xreg = matrice_xreg(noms, debut_commun, fin_train),
             d = 1, stepwise = FALSE, approximation = FALSE)
}

t_stats_xreg <- function(modele, noms) {
  coefs <- coef(modele)[noms]
  ecarts <- sqrt(diag(modele$var.coef))[noms]
  coefs / ecarts
}

# ---- 5. Sélection des variables : du général au particulier ------------------
# On part du modèle complet puis on retire, une à une, la variable la moins
# significative (|t| le plus faible). On garde le modèle d'AIC minimal.
chemin <- list()
noms_courants <- names(regresseurs)
repeat {
  modele <- estimer_arimax(noms_courants)
  t_val  <- t_stats_xreg(modele, noms_courants)
  chemin[[length(chemin) + 1]] <- list(variables = noms_courants, modele = modele,
                                       aic = AIC(modele), t = t_val)
  if (length(noms_courants) == 1) break
  noms_courants <- setdiff(noms_courants, names(which.min(abs(t_val))))
}

tab_selection <- data.frame(
  Étape = seq_along(chemin),
  `Variables retenues` = sapply(chemin, function(e) paste(e$variables, collapse = " + ")),
  `Modèle ARIMA` = sapply(chemin, function(e) as.character(e$modele)),
  AIC = round(sapply(chemin, `[[`, "aic"), 1),
  check.names = FALSE
)
meilleure_etape <- which.min(tab_selection$AIC)
print(tab_selection)
exporter_tableau(tab_selection, "tab08_selection_arimax",
                 lignes_surlignees = meilleure_etape)

# ---- 6. Prévisions sur la période de test ------------------------------------
# NB : on utilise ici les vraies valeurs des variables explicatives sur la
# période de test. En conditions réelles, il faudrait aussi les prévoir :
# l'avantage de l'ARIMAX est donc ici surestimé (cf. limites du mémoire).
prevoir_arimax <- function(etape) {
  noms <- etape$variables
  forecast(etape$modele, xreg = matrice_xreg(noms, debut_test, fin_test),
           h = n_test)
}

modeles$arimax        <- chemin[[1]]$modele                  # 4 variables
modeles$arimax_select <- chemin[[meilleure_etape]]$modele    # sélection AIC

previsions_obj$arimax        <- prevoir_arimax(chemin[[1]])
previsions_obj$arimax_select <- prevoir_arimax(chemin[[meilleure_etape]])

previsions$arimax        <- as.numeric(previsions_obj$arimax$mean)
previsions$arimax_select <- as.numeric(previsions_obj$arimax_select$mean)

sauver_base("14_residus_arimax", checkresiduals(modeles$arimax, test = FALSE))
