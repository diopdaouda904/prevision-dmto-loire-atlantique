# Données

Le code attend un fichier `base_complete_dmto.csv` dans ce dossier.

## Format

- Séparateur : point-virgule `;`
- Décimales : point `.`
- Une ligne par mois, de janvier 2000 à février 2026 (314 lignes), dans l'ordre chronologique

| Colonne | Contenu | Unité |
|---|---|---|
| `dmto_mensuel` | Droits de mutation à titre onéreux perçus, régime de droit commun, Loire-Atlantique | € |
| `chomage_A` | Demandeurs d'emploi de catégorie A, Loire-Atlantique | personnes |
| `ipc` | Indice des prix à la consommation, base 2015 | indice |
| `taux` | Taux moyen des crédits à l'habitat | % |
| `encours` | Encours des crédits à l'habitat | M€ |

D'autres colonnes (une colonne de dates, par exemple) peuvent être présentes : elles sont ignorées.

## Sources (données publiques)

- **DMTO** : IGEDD d'après DGFiP (MEDOC), série mensuelle par département — [statistiques.developpement-durable.gouv.fr](https://www.statistiques.developpement-durable.gouv.fr)
- **Chômage catégorie A** : DARES — [dares.travail-emploi.gouv.fr](https://www.dares.travail-emploi.gouv.fr)
- **IPC** : INSEE — [insee.fr](https://www.insee.fr)
- **Taux et encours des crédits à l'habitat** : Banque de France — [banque-france.fr/statistiques](https://www.banque-france.fr/statistiques)

Données consultées en janvier 2026.
