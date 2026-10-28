# ==============================================================================
# 06_prevision_finale.R — Prévision des 12 prochains mois et validation
# ------------------------------------------------------------------------------
# Le meilleur modèle (ETS dans le mémoire) est ré-estimé sur TOUTE la série,
# pour profiter des observations les plus récentes, puis on prévoit 12 mois.
# Sortie  : tableau des prévisions, figure, données de l'application Shiny
# ==============================================================================

# ---- 1. Ré-estimation sur la série complète ----------------------------------
modele_final <- switch(
  meilleur_univarie,
  hw     = HoltWinters(dmto_corr, seasonal = "multiplicative"),
  ets    = ets(dmto_corr),
  sarima = auto.arima(dmto_corr, d = 1, stepwise = FALSE, approximation = FALSE),
  adam   = adam(dmto_corr, model = "ZZZ", lags = frequence)
)
nom_modele_final <- if (meilleur_univarie == "ets") modele_final$method else
  noms_modeles[[meilleur_univarie]]

prev_finale <- forecast(modele_final, h = horizon, level = c(80, 95))
dates_prev  <- seq(max(dates_ts(dmto_corr)), by = "month", length.out = horizon + 1)[-1]

# ---- 2. Tableau des prévisions -----------------------------------------------
tab_prev <- data.frame(
  Mois            = mois_fr(dates_prev),
  `Prévision (€)` = format_nombre(prev_finale$mean),
  `Borne inf. 80%` = format_nombre(prev_finale$lower[, 1]),
  `Borne sup. 80%` = format_nombre(prev_finale$upper[, 1]),
  `Borne inf. 95%` = format_nombre(prev_finale$lower[, 2]),
  `Borne sup. 95%` = format_nombre(prev_finale$upper[, 2]),
  check.names = FALSE
)
print(tab_prev)
exporter_tableau(tab_prev, "tab10_previsions_finales",
                 lignes_surlignees = which.max(prev_finale$mean))

total_annuel <- sum(prev_finale$mean)
mois_pic     <- which.max(prev_finale$mean)
message("Total prévu sur 12 mois : ", format_nombre(total_annuel / 1e6, 1), " M€",
        " | pic : ", mois_fr(dates_prev[mois_pic]), " (",
        format_nombre(prev_finale$mean[mois_pic] / 1e6, 1), " M€)")

# ---- 3. Validation partielle sur les mois déjà publiés -----------------------
validation <- merge(
  validation_reelle,
  data.frame(date = dates_prev,
             prevision = as.numeric(prev_finale$mean),
             borne_inf_95 = as.numeric(prev_finale$lower[, 2]),
             borne_sup_95 = as.numeric(prev_finale$upper[, 2])),
  by = "date"
)
validation$ecart_pct <- round(100 * (validation$reel - validation$prevision) /
                                validation$prevision, 1)
validation$dans_ic95 <- with(validation, reel >= borne_inf_95 & reel <= borne_sup_95)
print(validation)

# ---- 4. Figure ---------------------------------------------------------------
historique <- window(dmto_corr, start = c(2022, 1))
df_hist <- data.frame(date = dates_ts(historique), valeur = as.numeric(historique))
df_fc <- data.frame(
  date = dates_prev, prevision = as.numeric(prev_finale$mean),
  lo80 = prev_finale$lower[, 1], hi80 = prev_finale$upper[, 1],
  lo95 = prev_finale$lower[, 2], hi95 = prev_finale$upper[, 2]
)

fig_finale <- ggplot() +
  geom_ribbon(data = df_fc, aes(date, ymin = lo95, ymax = hi95),
              fill = "steelblue", alpha = 0.15) +
  geom_ribbon(data = df_fc, aes(date, ymin = lo80, ymax = hi80),
              fill = "steelblue", alpha = 0.25) +
  geom_line(data = df_hist, aes(date, valeur), colour = "grey30") +
  geom_line(data = df_fc, aes(date, prevision), colour = "steelblue", linewidth = 1) +
  geom_point(data = validation, aes(date, reel), colour = "#c0392b",
             shape = 8, size = 3) +
  axe_millions() +
  labs(title = paste("Prévision des DMTO —", mois_fr(min(dates_prev)), "à",
                     mois_fr(max(dates_prev))),
       subtitle = paste0(nom_modele_final, " · intervalles à 80 % et 95 % · ",
                         "étoiles rouges = montants réellement perçus"),
       x = NULL, y = NULL) +
  theme_projet()
sauver_ggplot(fig_finale, "17_prevision_finale")

# ---- 5. Données pour l'application Shiny -------------------------------------
# L'app lit uniquement ce fichier : elle démarre vite et n'a pas besoin de
# ré-estimer les modèles (ni d'avoir les données brutes).
outliers_app <- resultat_tso$outliers |>
  mutate(date = dates_ts(dmto_ts)[ind],
         valeur = as.numeric(dmto_ts)[ind],
         cle = format(date, "%Y-%m"),
         label = paste0(type, " ", mois_fr(date),
                        ifelse(cle %in% names(explications_outliers),
                               paste0(" — ", explications_outliers[cle]), ""))) |>
  select(date, valeur, label)

donnees_app <- list(
  serie        = data.frame(date = dates_ts(dmto_ts), valeur = as.numeric(dmto_ts)),
  outliers     = outliers_app,
  nb_obs       = length(dmto_ts),
  part_saison  = part_saisonnalite,
  test         = data.frame(date = dates_test, reel = reel_test),
  previsions   = previsions[ordre_modeles],
  noms_modeles = noms_modeles[ordre_modeles],
  couleurs     = couleurs_modeles,
  performances = tab_perf,
  finale       = df_fc,
  nom_modele_final = nom_modele_final,
  total_annuel = total_annuel,
  validation   = validation
)
saveRDS(donnees_app, fichier_app)
message("Données de l'application enregistrées : ", fichier_app)
