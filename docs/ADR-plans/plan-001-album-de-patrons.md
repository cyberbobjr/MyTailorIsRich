# Plan 001 — Album de patrons

ADR : [ADR-001 — Album de patrons](../ADR/001-album-de-patrons.md) (accepté le 2026-11-15).
Le test en jeu est fait par l'utilisateur (demande du 2026-11-15) : chaque étape codée et verte hors jeu reste
`À valider` jusqu'à son retour.

## Tableau de bord

| # | Étape | Statut | Dépend de | Décisions ADR | Taille | Parallélisable avec |
|---|---|---|---|---|---|---|
| 1 | Modèle de l'album : sources, fiches, catégories, recherche, tri | À valider | — | D03, D04 | S | 2 |
| 2 | Groupe d'emplacement (haut, bas, tenue) et machine la plus proche | À valider | — | D03, D06 | S | 1 |
| 3 | Fenêtre de l'album : grille, recherche, fiche et besoins sous l'aperçu, boutons, case de dépôt | À valider | 1, 2 | D02, D05 à D09, D11 | M | — |
| 4 | Style « album ancien » et tailles adaptatives (4K) | À valider | 3 | D12 | M | — |
| 5 | Menus : « Ouvrir l'album » sur le classeur, album en mode « choisir » sur la machine | À valider | 3 | D02, D05 | S | 6 |
| 6 | Recette « Déchirer un patron » | À valider | — | D13 | S | 5 |
| 7 | Traductions (9 langues), wiki EN/FR, spécifications, CHANGELOG | À valider | 3 à 6 | D10 | S | — |
| 8 | Deux volets : pages de 3 × 3 pochettes à gauche, aperçu 3D intégré à droite | À valider | 3, 4 | D14 | M | 9 |
| 9 | Classeur sans limite de nombre | À valider | — | D15 | S | 8 |
| 10 | Album redimensionnable (poignée, agrandissement retenu) | À valider | 8 | D16 | S | — |

## Preuve du vert (toutes étapes, après refactor)

Commande : `python tests/run_tests.py`, le 2026-11-16 (après les étapes 8 à 10) : luacheck sans avertissement, syntaxe Lua 5.1 et appels
absents de Kahlua, traductions (mêmes clés et paramètres que l'anglais dans les 9 langues), descriptions Steam,
mod de désinstallation, faces des tuiles, puis 287 tests Lua `ok`, 0 `ÉCHEC`, ligne finale `Tout est bon.`

## Fiches

### 1 — Modèle de l'album
- Fichiers : `shared/MyTailorIsRich/MTIR_PatternAlbum.lua` ; tests `tests/lua/test_pattern_album.lua` (6 tests).
- Rouge constaté avant le code (module absent), vert après.

### 2 — Groupe d'emplacement et machine la plus proche
- `group` (`top`, `bottom`, `full`) dans les profils d'emplacement (`MTIR_Core.lua`, `MTIR_Sizing.lua`), test
  ajouté à `tests/lua/test_sizing_deduction.lua` (rouge puis vert).
- `MTIR.findNearestObject` (recherche commune), `MTIR.findNearestWorkTable` et `MTIR.findNearestSewingMachine` dans
  `MTIR_WorkTable.lua` ; tests `tests/lua/test_nearest_objects.lua` (3 tests, rouges puis verts).

### 3 — Fenêtre de l'album
- `client/MyTailorIsRich/MTIR_PatternAlbumWindow.lua` ; `UI.newDetails` accepte une position et une largeur.
- Sans test hors jeu (interface) : à valider en jeu.

### 4 — Style et tailles adaptatives
- `client/MyTailorIsRich/MTIR_UIScale.lua` (tests `tests/lua/test_ui_scale.lua`, 4 tests) et
  `client/MyTailorIsRich/MTIR_VintageStyle.lua`.
- À valider en jeu en 1080p et avec une grande police (4K).

### 5 — Menus
- `MTIR_PatternBinderMenu.lua` : « Ouvrir l'album (n/max) » remplace le sous-menu des patrons ; `MTIR.BinderUI`.
- `MTIR_MachineTabPattern.lua` : clic sur l'emplacement → album en mode « choisir » (l'ancienne liste et sa clé
  `IGUI_MTIR_Machine_NoPattern` sont retirées).

### 6 — Recette « Déchirer un patron »
- `scripts/MTIR_items.txt` (`MTIR_TearPattern`), `Recipes.json` des 9 langues.

### 7 — Traductions et documentation
- Clés `IGUI_MTIR_Album_*` dans les 9 langues ; clés retirées : `IGUI_MTIR_Binder_Patterns`,
  `IGUI_MTIR_Binder_Empty`, `IGUI_MTIR_Machine_NoPattern`.
- Wiki EN/FR pages 05 et 06, spécifications fonctionnelles (F16, F22) et techniques, architecture, CHANGELOG
  (section Unreleased).

### 8 — Deux volets
- `MTIR_PatternAlbumWindow.lua` (page `MTIR_PatternAlbumPage`, dépôt sur la page) ; `MTIR_PatternPreview.lua` :
  panneau `MTIR_PatternPreviewPanel` extrait, partagé par l'album et la fenêtre « Aperçu sur moi ».
- Clés `IGUI_MTIR_Album_Page` et nouvelle `IGUI_MTIR_Album_Drop` dans les 9 langues. À valider en jeu.

### 9 — Classeur sans limite
- `MTIR_PatternBinder.lua`, `MTIR_BinderStoreAction.lua`, `MTIR_PatternBinderMenu.lua` ; option
  `PatternBinderCapacity` et clé `IGUI_MTIR_Binder_Full` supprimées (9 langues, `sandbox-options.txt`).
- Test `test_pattern_binder.lua` : « ajout sans limite de nombre » (150 entrées), rouge puis vert ; le test du
  classeur plein est supprimé avec la limite.

### 10 — Redimensionnement
- `MTIR.UIScale.factor(baseW, baseH, zoom)` : test ajouté à `tests/lua/test_ui_scale.lua`, rouge puis vert.
- Poignée, cadre de la taille visée et reconstruction dans `MTIR_PatternAlbumWindow.lua`. À valider en jeu.

## Recette en jeu (utilisateur)

1. Classeur avec quelques patrons : clic droit **Ouvrir l'album** ; vignettes, recherche (`jean`, `haut cuir`),
   clic sur une vignette : photo, puis besoins dessous.
2. Glisser un patron de l'inventaire sur la case de dépôt : il est rangé.
3. **Coudre à la main** (menu des tailles), **Sortir**, **Aperçu sur moi**.
4. Près d'une machine : **Coudre à la machine** ouvre la machine, onglet Patron, patron choisi.
5. Sur la machine : clic sur l'emplacement du patron → album en mode « choisir ».
6. Recette **Déchirer un patron** : une feuille de papier.
7. Avec une grande taille de police (4K) : la fenêtre grandit et tient dans l'écran.
8. Tirer le coin cousu en bas à droite : l'album s'agrandit ; le rouvrir : même taille.
9. Ranger plus de 20 patrons : aucun refus, pages supplémentaires.
