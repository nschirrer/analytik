# Analytik

Analytik est une app macOS native (SwiftUI) pour visualiser et comparer des ventes en unités issues d'exports Excel « GOLD » : par période (semaines et trimestres fiscaux, année précédente), par produit et par canal de vente. Les données se lisent en tableaux de chiffres ou en graphiques, et un panneau Claude permet d'interroger les rapports chargés en français.

## Installation

1. Téléchargez `Analytik-x.y.z-macOS.zip` depuis la page [Releases](../../releases) (ou l'artefact `Analytik-macOS` du dernier run GitHub Actions).
2. Décompressez l'archive et glissez `Analytik.app` dans le dossier Applications.
3. Premier lancement : l'app est signée ad hoc, pas notarisée par Apple. macOS affiche un avertissement.
   - macOS 15 et plus : lancez l'app une première fois, puis ouvrez Réglages Système › Confidentialité et sécurité et cliquez sur « Ouvrir quand même ».
   - macOS 14 : clic droit sur l'app › Ouvrir › Ouvrir.
   - Alternative en ligne de commande : `xattr -dr com.apple.quarantine /Applications/Analytik.app`.

Configuration minimale : macOS 14.4 (Sonoma). Binaire universel (Apple Silicon et Intel).

## Utilisation

- **Importer** : Fichier › Importer des exports GOLD (⌘O), ou glissez des fichiers `.xlsx` dans la fenêtre. Chaque feuille au format GOLD devient un rapport dans la barre latérale ; la case à cocher inclut ou exclut le rapport de l'analyse. Les fichiers importés sont rechargés au lancement suivant.
- **Tableau** : choisissez la métrique (NBL, LY, y/y, Mix), les lignes (lignes du fichier, produit, magasin, canal, pays ou fichier) et la granularité (semaines ou trimestres). Les boutons « Périodes » et « Lignes » filtrent les colonnes et les lignes. La colonne Total additionne les unités ; les ratios (y/y, Mix) sont toujours recalculés à partir des sommes, jamais additionnés.
- **Graphique** : barres groupées ou courbes, une couleur par ligne (huit lignes maximum affichées).
- **Comparaison** : deux périodes (une ligne par série), deux lignes (une ligne par période), ou année en cours contre année précédente, avec l'écart en unités et en pourcentage.
- **Exporter** : Fichier › Exporter le tableau en CSV (⇧⌘E). Le fichier utilise le point-virgule et la virgule décimale, lisible directement dans Excel en français.
- **Claude** : bouton « Claude » dans la barre d'outils (⌥⌘C). Posez une question en français ; les données des rapports cochés sont envoyées avec la question, et la réponse s'affiche au fil de l'eau.

### Métriques

| Métrique | Signification |
|---|---|
| NBL | Unités facturées nettes de l'année en cours |
| LY | Unités de la même période l'année précédente |
| y/y | Variation NBL / LY − 1 |
| Mix | Part de la ligne dans le TOTAL |

Dans les exports GOLD, seule la ligne TOTAL possède une ligne LY. Pour les autres lignes, l'app estime LY = NBL / (1 + y/y) afin de pouvoir recalculer y/y sur plusieurs semaines ou plusieurs fichiers. La barre d'état le signale quand c'est le cas.

## Clé API Anthropic

1. Créez une clé sur [console.anthropic.com](https://console.anthropic.com).
2. Dans Analytik › Réglages (⌘,), collez la clé, cliquez sur Enregistrer puis sur « Tester la connexion ».
3. La clé est stockée dans le trousseau macOS. Comme l'app est signée ad hoc, macOS peut demander l'accès au trousseau après une mise à jour : choisissez « Toujours autoriser ».

Le modèle par défaut est `claude-opus-5`. L'usage est facturé à votre compte Anthropic. Les données des rapports cochés ne quittent votre Mac que lorsque vous posez une question ; elles sont mises en cache côté API pendant quelques minutes pour réduire le coût des questions suivantes. Vérifiez que cet usage est conforme à la politique de votre organisation avant d'envoyer des données internes.

## Format des fichiers attendu

Un classeur `.xlsx` contenant, sur une feuille :

1. un bloc de métadonnées (`Product`, `Measures`, `Channel`, `Store ID - Name`, `Country/Region`, `Type`…) : libellé en colonne A, valeur à droite ;
2. une ligne d'en-tête : nom de la dimension en colonne A (`Sub-Channel`, `Product`…), puis les périodes à partir de la colonne C (`FY26Q3_W1`, `W2`, …, `26'Q2`, `26'Q3`) ;
3. des lignes de données : membre en colonne A (vide = membre précédent), métrique en colonne B (`NBL`, `y/y`, `LY`, `Mix`), valeurs ensuite (`-` = non disponible).

Les colonnes de trimestre sont des totaux et ne sont jamais additionnées aux semaines. Les feuilles qui ne suivent pas ce format sont ignorées.

Le dépôt ne contient aucune donnée réelle : les fixtures de test sont synthétiques (`scripts/make_fixtures.py`). Ne commitez jamais d'export réel.

## Développement

- Ouvrir dans Xcode 16 ou plus : Fichier › Ouvrir… › `Package.swift`, puis lancer le schéma `Analytik`.
- En ligne de commande (macOS) : `swift build`, `swift test`, puis `bash scripts/bundle.sh` pour produire `dist/Analytik.app` et son zip.
- Structure : `Sources/AnalytikCore` (lecture des classeurs, parseur GOLD, moteur de pivot et de comparaison, export CSV, client Claude ; sans dépendance à l'interface), `Sources/Analytik` (app SwiftUI), `Tests/AnalytikCoreTests`.
- Intégration continue : à chaque push, GitHub Actions compile sur macOS, exécute les tests et publie l'artefact `Analytik-macOS`. Pour publier une release, deux possibilités :
  - pousser un tag `vX.Y.Z` :

    ```bash
    git tag v0.2.0
    git push origin v0.2.0
    ```

  - ou lancer le workflow « Build » manuellement (onglet Actions › Build › Run workflow) en indiquant la version : le tag et la release sont créés automatiquement.
