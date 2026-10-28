# ==============================================================================
# 05_evaluation.R — Comparaison des prévisions hors échantillon
# ------------------------------------------------------------------------------
# Critères : RMSE, MAPE, R²OOS (vs naïve) et test de Diebold-Mariano
# (vs naïve, et vs Holt-Winters, le modèle utilisé par le Département).
# ==============================================================================

ordre_modeles <- c("naive", "hw", "ets", "sarima", "adam", "arimax", "arimax_select")
erreurs <- lapply(previsions[ordre_modeles], function(p) reel_test - p)

# ---- 1. Test de Diebold-Mariano ----------------------------------------------
# H0 : même précision que la référence ; H1 ("less") : le modèle est meilleur.
# h = 1 comme dans le mémoire ; voir la section "Limites" du README.
p_dm <- function(modele, reference) {
  if (modele == reference) return(NA_real_)
  dm.test(erreurs[[modele]], erreurs[[reference]],
          alternative = "less", h = 1)$p.value
}

# ---- 2. Tableau de synthèse --------------------------------------------------
mse_naive <- mse(reel_test, previsions$naive)

tab_perf <- data.frame(
  code      = ordre_modeles,
  Modèle    = unname(noms_modeles[ordre_modeles]),
  RMSE      = sapply(previsions[ordre_modeles], rmse, reel = reel_test),
  MAPE      = sapply(previsions[ordre_modeles], mape, reel = reel_test),
  R2OOS     = sapply(previsions[ordre_modeles],
                     function(p) r2oos(mse(reel_test, p), mse_naive)),
  p_DM_naive = sapply(ordre_modeles, p_dm, reference = "naive"),
  p_DM_hw    = sapply(ordre_modeles, p_dm, reference = "hw"),
  row.names = NULL
)

tab_perf_affiche <- with(tab_perf, data.frame(
  Modèle = Modèle,
  `RMSE (€)` = format_nombre(RMSE),
  MAPE = paste0(format_nombre(MAPE, 1), " %"),
  `R²OOS` = format_nombre(R2OOS, 3),
  `DM vs naïve (p)` = ifelse(is.na(p_DM_naive), "—", format_p(p_DM_naive)),
  `DM vs Holt-Winters (p)` = ifelse(is.na(p_DM_hw), "—", format_p(p_DM_hw)),
  check.names = FALSE
))
print(tab_perf_affiche)

# Meilleur modèle univarié, celui qui sera utilisé pour la prévision finale
univaries <- c("hw", "ets", "sarima", "adam")
meilleur_univarie <- univaries[which.min(tab_perf$RMSE[match(univaries, tab_perf$code)])]
message("Meilleur modèle univarié (RMSE) : ", noms_modeles[[meilleur_univarie]])

exporter_tableau(tab_perf_affiche, "tab09_performances",
                 lignes_surlignees = match(meilleur_univarie, tab_perf$code))

# ARIMAX complet face au meilleur univarié
p_arimax_vs_meilleur <- dm.test(erreurs$arimax, erreurs[[meilleur_univarie]],
                                alternative = "less", h = 1)$p.value
message("DM ARIMAX complet vs ", noms_modeles[[meilleur_univarie]], " : p = ",
        format_p(p_arimax_vs_meilleur))

# ---- 3. Graphique : prévisions vs réel sur la période de test ----------------
historique <- window(dmto_corr, start = c(2024, 1))
df_prev <- rbind(
  data.frame(date = dates_ts(historique), valeur = as.numeric(historique),
             serie = "Réel"),
  do.call(rbind, lapply(c("naive", "hw", "ets", "sarima", "adam"), function(m) {
    data.frame(date = dates_test, valeur = previsions[[m]],
               serie = noms_modeles[[m]])
  }))
)

fig_comparaison <- ggplot(df_prev, aes(date, valeur, colour = serie)) +
  geom_line(aes(linewidth = serie == "Réel")) +
  scale_linewidth_manual(values = c(`TRUE` = 1.1, `FALSE` = 0.6), guide = "none") +
  scale_colour_manual(values = couleurs_modeles) +
  axe_millions() +
  labs(title = "Prévisions vs valeurs réelles",
       subtitle = paste("Période de test :", mois_fr(min(dates_test)), "–",
                        mois_fr(max(dates_test))),
       x = NULL, y = NULL, colour = NULL) +
  theme_projet()
sauver_ggplot(fig_comparaison, "15_comparaison_previsions")

# ---- 4. Graphique : erreurs quadratiques cumulées (CSPE) ---------------------
# Plus la courbe est basse, moins le modèle a accumulé d'erreurs.
df_cspe <- do.call(rbind, lapply(c("naive", "hw", "ets", "sarima", "adam"), function(m) {
  data.frame(date = dates_test, cspe = cumsum(erreurs[[m]]^2),
             modele = noms_modeles[[m]])
}))

fig_cspe <- ggplot(df_cspe, aes(date, cspe, colour = modele)) +
  geom_line(linewidth = 1) +
  scale_colour_manual(values = couleurs_modeles) +
  labs(title = "Erreurs de prévision cumulées au carré (CSPE)",
       x = NULL, y = "CSPE", colour = NULL) +
  theme_projet()
sauver_ggplot(fig_cspe, "16_erreurs_cumulees_cspe")
