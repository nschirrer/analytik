# Metrixator

App macOS (SwiftUI) pour suivre chaque semaine les résultats chiffrés venant de différentes sources, et se construire une vue de synthèse personnalisée inspirée de Numerics : chiffres, courbes, barres, progressions Y/Y, cumuls PWK / L4W / QTD / YTD.

- **100 % local** : les données sont dans `~/Library/Application Support/Metrixator/metrixator.json` (fichier lisible par vous seul, droits `600`). Aucune synchronisation cloud, aucune connexion réseau.
- **Hors connexion**, français / anglais, mode sombre selon le réglage du Mac.
- Plus petite période : la **semaine** (pas de données journalières).

## Installer et lancer

Pré-requis : macOS 14 (Sonoma) ou plus récent, et Xcode **ou** les outils en ligne de commande (`xcode-select --install`).

```bash
git clone https://github.com/nschirrer/analytik.git
cd analytik
./scripts/build-app.sh --install   # construit build/Metrixator.app et la copie dans /Applications
open /Applications/Metrixator.app
```

Autres possibilités :
- ouvrir `Package.swift` dans Xcode, choisir le schéma **Metrixator** puis ⌘R ;
- télécharger l'archive `Metrixator-app` produite par la CI GitHub (onglet *Actions*). L'app n'est pas signée par un compte développeur : au premier lancement, faites **clic droit › Ouvrir**.

Au premier lancement, l'app est remplie avec des **données d'exemple fictives** (22 résultats d'un point de vente imaginaire, avec l'historique de l'exercice précédent). Pour partir de zéro : **Réglages (⌘,) › Tout effacer**.

## Utilisation

| Écran | Contenu | Actions |
|---|---|---|
| **Tableau de synthèse** | Une tuile par résultat (chiffre, courbe, barres, Y/Y, N vs N-1), colorée | Choisir la période (PWK, L4W, QTD, YTD, ou ⌘1…⌘4), remonter les semaines (‹ ›), cliquer sur une tuile pour le détail, clic droit pour changer le format, masquer ou supprimer |
| **Vue détaillée** | Formulaire « Ajouter une semaine », synthèse des 4 périodes, graphique (3 formats, 13 sem. à tout l'historique), historique | Saisir, modifier ou supprimer une valeur |
| **Nouveau résultat / Modifier** (⌘N) | Titre, description, nature (unités, montant, %, score), unité, cumul (somme ou moyenne), sens (hausse ou baisse = positif), format d'affichage, couleur | Aperçu en direct de la tuile |
| **Résultats suivis** | Liste de tous les résultats | Modifier, supprimer, masquer, réordonner par glisser-déposer, importer ou exporter en CSV |
| **Saisie de la semaine** (⌘E) | Une ligne par résultat pour la semaine choisie | Saisir toutes les valeurs du lundi en une fois |

Parcours du lundi : ouvrir l'app → ⌘E (ou cliquer sur une tuile) → saisir les chiffres de la semaine passée → le tableau et les vues détaillées se recalculent aussitôt.

## Règles de calcul

- **Calendrier fiscal** (réglable) : par défaut, l'exercice se termine le dernier samedi de septembre et les semaines vont du dimanche au samedi. L'exercice FY27 va du 27 sept. 2026 au 25 sept. 2027. Il y a 4 trimestres de 13 semaines ; une éventuelle 53e semaine va au T4.
- **PWK** : la dernière semaine terminée. **L4W** : les 4 dernières semaines. **QTD / YTD** : du début du trimestre ou de l'exercice jusqu'à la semaine de référence.
- **Cumul** : somme des semaines (volumes, CA) ou moyenne (taux, panier moyen, scores), au choix pour chaque résultat.
- **Y/Y** : si la même semaine de l'exercice précédent est dans l'app, le Y/Y est calculé. Sinon, c'est le Y/Y saisi à la main qui est utilisé. Sur une période, le Y/Y compare les cumuls des seules semaines qui ont une référence N-1.
  - Volumes et montants : progression en %.
  - Taux et scores : écart en points.
- **Comparaison avec la période précédente** : semaine précédente, 4 semaines précédentes, ou mêmes semaines du trimestre précédent. Pour les cumuls en somme, cette comparaison ne s'affiche que si les deux périodes sont complètes.

## Cas particuliers

- **Résultat sans données** : sa tuile s'affiche vide (« — », « Aucune donnée »).
- **Période incomplète** : un badge orange indique combien de semaines sont saisies, par exemple « 5/6 sem. ».
- **Saisie incorrecte** (texte, Y/Y ≤ −100 %, semaine pas encore terminée) : un symbole ⚠︎ s'affiche à côté du champ avec le message, et l'enregistrement est bloqué.
- **Doublons** : un deuxième résultat portant le même nom (casse et accents ignorés) est bloqué, tout comme une deuxième valeur pour la même semaine. À l'import CSV, les doublons sont ignorés et listés.
- **Suppressions** : une bannière « Annuler » s'affiche pendant 8 secondes, et le menu Édition › Annuler la suppression (⌥⌘Z) reste disponible tant que l'app est ouverte.
- **Fichier de données illisible** : il est mis de côté et l'app vous prévient.

## CSV

- **Export** (⇧⌘E) : une ligne par résultat et par semaine, séparateur `;`, encodage UTF-8 pour Excel.
- **Import** (⇧⌘I) : colonnes `resultat ; semaine (AAAA-MM-JJ, n'importe quel jour de la semaine) ; valeur`, avec en option `yoy_saisi ; nature ; unite ; agregation`. Les résultats inconnus sont créés.

## Développement

```
Sources/MetrixatorCore   logique métier (Foundation uniquement) : calendrier, calculs, stockage, CSV, données d'exemple
Sources/Metrixator       interface SwiftUI + Swift Charts (macOS)
Tests/MetrixatorCoreTests tests unitaires (dont un test par critère de réussite)
```

```bash
swift test   # tests de la logique métier (macOS ou Linux)
```

La CI (`.github/workflows/macos.yml`) compile l'app sur macOS, lance les tests, puis génère des captures d'écran avec `Metrixator --snapshot <dossier>`. Ce mode utilise un fichier de données temporaire et ne touche jamais vos données.
