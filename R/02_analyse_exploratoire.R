# ==============================================================================
# 02_analyse_exploratoire.R — Statistiques descriptives, stationnarité,
#                             saisonnalité et désaisonnalisation X13
# ------------------------------------------------------------------------------
# Entrée  : dmto_corr
# Sortie  : tableaux et figures de la partie 3.1 du mémoire, dmto_cvs
# ==============================================================================

# ---- 1. Statistiques descriptives -------------------------------------------
x <- as.numeric(dmto_corr)

stats_desc <- data.frame(
  Statistique = c("Minimum", "1er quartile", "Médiane", "Moyenne",
                  "3e quartile", "Maximum", "Écart-type",
                  "Coefficient de variation", "Skewness", "Kurtosis"),
  Valeur = c(
    format_nombre(c(min(x), quantile(x, 0.25), median(x), mean(x),
                    quantile(x, 0.75), max(x), sd(x))),
    format_nombre(c(sd(x) / mean(x), skewness(x), kurtosis(x)), 3)
  )
)
print(stats_desc)
exporter_tableau(stats_desc, "tab02_statistiques_descriptives")

normalite <- shapiro.test(x)
message("Shapiro-Wilk : W = ", round(normalite$statistic, 3),
        ", p = ", format_p(normalite$p.value))

sauver_base("04_boxplot", boxplot(x, main = "DMTO corrigés", ylab = "Montant (€)",
                                  col = "steelblue", border = "navy"))

# ---- 2. Corrélogrammes -------------------------------------------------------
sauver_base("05_acf_pacf", {
  par(mfrow = c(2, 2))
  acf(dmto_corr, lag.max = 36, main = "ACF — série en niveau")
  pacf(dmto_corr, lag.max = 36, main = "PACF — série en niveau")
  acf(diff(dmto_corr), lag.max = 36, main = "ACF — série différenciée (d = 1)")
  pacf(diff(dmto_corr), lag.max = 36, main = "PACF — série différenciée (d = 1)")
})

# ---- 3. Stationnarité (ADF + KPSS) -------------------------------------------
statio <- rbind(
  cbind(Serie = "Série corrigée (niveau)", test_stationnarite(dmto_corr)),
  cbind(Serie = "Série différenciée (d = 1)", test_stationnarite(diff(dmto_corr)))
)

tab_statio <- data.frame(
  Série = rep(statio$Serie, each = 2),
  Test  = rep(c("ADF", "KPSS"), times = nrow(statio)),
  Statistique = round(c(rbind(statio$adf_stat, statio$kpss_stat)), 3),
  `P-value` = c(rbind(affiche_p_adf(statio$adf_p), affiche_p_kpss(statio$kpss_p))),
  Conclusion = rep(ifelse(statio$stationnaire, "Stationnaire", "Non stationnaire"),
                   each = 2),
  check.names = FALSE
)
print(tab_statio)
exporter_tableau(tab_statio, "tab03_stationnarite",
                 lignes_surlignees = which(tab_statio$Conclusion == "Stationnaire"))

# ---- 4. Tests de saisonnalité ------------------------------------------------
# Chaque test renvoie une statistique et une p-value ; H0 = pas de saisonnalité.
# tryCatch : si un test échoue, on l'indique au lieu d'arrêter tout le script.
lancer_test_saison <- function(nom, fonction) {
  res <- tryCatch(fonction(dmto_corr), error = function(e) NULL)
  ok  <- is.list(res) && is.numeric(res$stat) && is.numeric(res$Pval)
  data.frame(Test = nom,
             stat = if (ok) res$stat else NA_real_,
             p    = if (ok) res$Pval else NA_real_)
}

resultats_saison <- rbind(
  lancer_test_saison("Friedman", fried),
  lancer_test_saison("Kruskal-Wallis", kw),
  lancer_test_saison("QS", qs),
  lancer_test_saison("Seasonal Dummies", seasdum),
  lancer_test_saison("Welch", welch)
)

# Le test WO combine plusieurs tests et renvoie directement TRUE / FALSE
saison_wo <- isSeasonal(dmto_corr, test = "wo")

conclure <- function(saisonnier) {
  ifelse(is.na(saisonnier), "Test non calculable",
         ifelse(saisonnier, "Saisonnalité détectée", "Pas de saisonnalité"))
}

tab_saison <- data.frame(
  Test        = c(resultats_saison$Test, "WO (Webel-Ollech)"),
  Statistique = c(format_nombre(resultats_saison$stat, 2), as.integer(saison_wo)),
  `P-value`   = c(ifelse(is.na(resultats_saison$p), "—",
                         ifelse(resultats_saison$p == 0, "< 1e-16",
                                format_p(resultats_saison$p))), "—"),
  Conclusion  = conclure(c(resultats_saison$p < seuil, saison_wo)),
  check.names = FALSE
)
print(tab_saison)
exporter_tableau(tab_saison, "tab04_saisonnalite")

sauver_base("06_profil_saisonnier",
            monthplot(dmto_corr, main = "Profil saisonnier mensuel des DMTO",
                      xlab = "Mois", ylab = "Montant (€)",
                      col = "steelblue", lwd = 2))

# ---- 5. Désaisonnalisation X13-ARIMA-SEATS -----------------------------------
x13_dmto <- x13(dmto_corr, x13_spec("RSA5c"))
print(summary(x13_dmto$regarima))

dmto_cvs <- x13_dmto$final$series[, "sa"]

# Part de la variance expliquée par chaque composante (saisonnalité, cycle...)
decomposition_variance <- x13_dmto$diagnostics$variance_decomposition
print(decomposition_variance)
part_saisonnalite <- unname(decomposition_variance["Seasonal", 1])

sauver_base("07_x13_cvs_tendance", plot(x13_dmto$final, type = "sa-trend"))
sauver_base("08_x13_saison_irregulier", plot(x13_dmto$final, type = "cal-seas-irr"))

fig_cvs <- autoplot(dmto_corr, series = "Série corrigée") +
  autolayer(dmto_cvs, series = "Série CVS") +
  scale_colour_manual(values = c("Série corrigée" = "grey65",
                                 "Série CVS" = "steelblue")) +
  axe_millions() +
  labs(title = "Série corrigée et série corrigée des variations saisonnières",
       x = NULL, y = NULL, colour = NULL) +
  theme_projet()
sauver_ggplot(fig_cvs, "09_serie_cvs")
