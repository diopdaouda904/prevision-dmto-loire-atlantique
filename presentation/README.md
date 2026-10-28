# Support de soutenance

`soutenance.html` est la présentation de soutenance (Quarto / reveal.js), 10 diapositives.

Ce fichier a été exporté sans ses ressources (dossier `soutenance_files/` : reveal.js, thème, styles). Ouvert seul, il s'affiche sans mise en page.

Pour qu'il s'ouvre correctement partout, le plus simple est de le ré-exporter en un seul fichier autonome, en ajoutant dans l'en-tête du `.qmd` de la présentation :

```yaml
format:
  revealjs:
    embed-resources: true
```

puis de remplacer `soutenance.html` par le nouveau fichier.
