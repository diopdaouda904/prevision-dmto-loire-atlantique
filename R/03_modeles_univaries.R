# ==============================================================================
# 03_modeles_univaries.R — Estimation des 5 modèles univariés
# ------------------------------------------------------------------------------
# Protocole : on estime sur janv. 2000 – févr. 2025 (train) et on prévoit
# les 12 mois suivants (test), que les modèles n'ont jamais vus.
# Sortie  : modeles (liste), previsions (liste des prévisions sur le test)
# ==============================================================================

# ---- 1. Découpage train / test -----------------------------------------------
dmto_train <- head(dmto_corr, length(dmto_corr) - n_test)
dmto_test  <- tail(dmto_corr, n_test)
dates_test <- dates_ts(dmto_test)

message("Train : ", mois_fr(min(dates_ts(dmto_train))), " – ",
        mois_fr(max(dates_ts(dmto_train))), " (", length(dmto_train), " obs.)")
message("Test  : ", mois_fr(min(dates_test)), " – ", mois_fr(max(dates_test)),
        " (", length(dmto_test), " obs.)")

# ---- 2. Estimation -----------------------------------------------------------
modeles <- list(
  # Benchmark : chaque mois = le même mois de l'année précédente
  naive  = snaive(dmto_train, h = n_test),

  # Référence du Département. Schéma multiplicatif : l'amplitude saisonnière
  # augmente avec le niveau de la série (confirmé par X13)
  hw     = HoltWinters(dmto_train, seasonal = "multiplicative"),

  # ETS : teste toutes les combinaisons Erreur / Tendance / Saison, garde la
  # meilleure selon l'AIC
  ets    = ets(dmto_train),

  # SARIMA : d = 1 imposé par les tests ADF / KPSS ; recherche exhaustive
  sarima = auto.arima(dmto_train, d = 1, stepwise = FALSE,
                      approximation = FALSE),

  # ADAM ETS (Svetunkov, 2023) : sélection automatique, saisonnalité de 12 mois
  adam   = adam(dmto_train, model = "ZZZ", lags = frequence)
)

# ---- 3. Prévisions sur la période de test ------------------------------------
previsions_obj <- list(
  naive  = modeles$naive,                       # snaive renvoie déjà la prévision
  hw     = forecast(modeles$hw, h = n_test),
  ets    = forecast(modeles$ets, h = n_test),
  sarima = forecast(modeles$sarima, h = n_test),
  adam   = forecast(modeles$adam, h = n_test)
)

# Les prévisions ponctuelles, en simples vecteurs numériques
previsions <- lapply(previsions_obj, function(p) as.numeric(p$mean))
reel_test  <- as.numeric(dmto_test)

# ---- 4. Paramètres et critères d'information ---------------------------------
decrire_params <- function(valeurs, decimales = 3) {
  valeurs <- valeurs[!is.na(valeurs)]
  paste(names(valeurs), "=", formatC(valeurs, format = "f", digits = decimales),
        collapse = " ; ")
}

tab_params <- data.frame(
  Modèle = c("Holt-Winters", "ETS", "SARIMA", "ADAM ETS"),
  Spécification = c(
    "Multiplicatif",
    modeles$ets$method,
    as.character(modeles$sarima),
    paste0("ETS(", modelType(modeles$adam), ")")
  ),
  Paramètres = c(
    decrire_params(c(alpha = unname(modeles$hw$alpha),
                     beta  = unname(modeles$hw$beta),
                     gamma = unname(modeles$hw$gamma)), 4),
    decrire_params(modeles$ets$par[c("alpha", "beta", "gamma")], 4),
    decrire_params(coef(modeles$sarima), 3),
    decrire_params(modeles$adam$persistence, 4)
  ),
  AIC  = c(NA, AIC(modeles$ets), AIC(modeles$sarima), AIC(modeles$adam)),
  AICc = c(NA, modeles$ets$aicc, modeles$sarima$aicc, AICc(modeles$adam)),
  BIC  = c(NA, BIC(modeles$ets), BIC(modeles$sarima), BIC(modeles$adam)),
  `Nb paramètres` = c(NA, length(modeles$ets$par), length(coef(modeles$sarima)),
                      nparam(modeles$adam)),
  Distribution = c("—", "Normale", "Normale", modeles$adam$distribution),
  check.names = FALSE
)
tab_params[c("AIC", "AICc", "BIC")] <- lapply(tab_params[c("AIC", "AICc", "BIC")],
                                               round, 2)
print(tab_params)

# Rappel : l'AIC mesure l'ajustement sur le passé, pas la qualité de prévision,
# et il n'est pas comparable entre familles de modèles (ETS vs ARIMA).
exporter_tableau(tab_params, "tab05_parametres_aic",
                 lignes_surlignees = which.min(tab_params$AIC))

# ---- 5. Validation des résidus (Ljung-Box) ------------------------------------
tab_ljung <- do.call(rbind, lapply(c("hw", "ets", "sarima", "adam"), function(m) {
  cbind(Modèle = noms_modeles[[m]], ljung_box(modeles[[m]]))
}))
tab_ljung$Conclusion <- ifelse(tab_ljung$p_value < seuil,
                               "Autocorrélation résiduelle", "Bruit blanc")
tab_ljung$Q       <- round(tab_ljung$Q, 2)
tab_ljung$p_value <- format_p(tab_ljung$p_value)
names(tab_ljung)  <- c("Modèle", "Statistique Q*", "Degrés de liberté",
                       "P-value", "Conclusion")
print(tab_ljung)
exporter_tableau(tab_ljung, "tab06_ljung_box")

# ---- 6. Figures : ajustement, résidus et prévisions de chaque modèle --------
sauver_base("10_ajustement_hw", {
  plot(dmto_train, main = "Ajustement Holt-Winters", xlab = "Année",
       ylab = "Montant (€)")
  lines(fitted(modeles$hw)[, "xhat"], col = "red", lwd = 1.5)
  legend("topleft", c("Observé", "Ajusté"), col = c("black", "red"), lwd = c(1, 1.5))
})
sauver_base("11_decomposition_ets", plot(modeles$ets))

for (m in c("sarima", "adam")) {
  sauver_base(paste0("12_ajustement_", m), {
    plot(dmto_train, main = paste("Ajustement", noms_modeles[[m]]),
         xlab = "Année", ylab = "Montant (€)")
    lines(fitted(modeles[[m]]), col = "red", lwd = 1.5)
    legend("topleft", c("Observé", "Ajusté"), col = c("black", "red"),
           lwd = c(1, 1.5))
  })
}

for (m in c("ets", "sarima", "adam")) {
  sauver_base(paste0("13_residus_", m),
              checkresiduals(modeles[[m]], test = FALSE))
}
