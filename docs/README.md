# My Tailor Is Rich — documentation

Mod Project Zomboid Build 42.21 (solo et multijoueur) qui donne une taille aux vêtements (XS à XXL) et une pointure aux chaussures (EU 35 à 47), avec retouches, usure, patrons de couture, classeur à patrons, teinture, broderie et machines à coudre.

La présentation publique du mod est le [README du dépôt](../README.md) (anglais, puis français) ; l'historique des versions est dans [CHANGELOG.md](../CHANGELOG.md).

## Documents

| Document | Rôle |
|---|---|
| [architecture.md](architecture.md) | Architecture logicielle : arborescence `Contents/mods`, modules Lua par côté, flux réseau, persistance, intégrations, outillage. |
| [specifications-fonctionnelles.md](specifications-fonctionnelles.md) | Ce que fait le mod pour le joueur et l'administrateur, fonctionnalité par fonctionnalité (`F01`…). |
| [specifications-techniques.md](specifications-techniques.md) | Contrats précis : objets et scripts, actions chronométrées, commandes réseau, clés ModData, options sandbox, traductions, compatibilités. |
| [ameliorations-et-idees.md](ameliorations-et-idees.md) | Améliorations de code proposées et idées de fonctionnalités (propositions, aucune implémentation sans validation). |
| [wiki/](wiki/) | Source des pages du wiki GitHub : guides joueur et administrateur, en anglais ([wiki/en/Home.md](wiki/en/Home.md)) et en français ([wiki/fr/Home.md](wiki/fr/Home.md)). |
| [images/](images/) | Images de la documentation. [images/screenshots/](images/screenshots/) : captures en jeu `shot1.png` à `shot6.png`. |
| [annexes/](annexes/) | Documents annexes rangés par thème. [annexes/communication/kofi-post.md](annexes/communication/kofi-post.md) : billet Ko-fi de lancement. |

## Captures disponibles

| Fichier | Contenu |
|---|---|
| `images/screenshots/shot1.png` | Infobulle d'un pantalon de taille XXL (« Very loose ») et taille ajoutée au nom dans l'inventaire. |
| `images/screenshots/shot2.png` | Machine à pédale, onglet Retouche (bonus de la machine, état, besoins). |
| `images/screenshots/shot3.png` | Menu contextuel « Trace a pattern » et son infobulle de besoins. |
| `images/screenshots/shot4.png` | Machine électrique alimentée, onglet Patron (taille, quantité, risque de taille décalée). |
| `images/screenshots/shot5.png` | Fenêtre « Preview on me » à côté de l'onglet Patron. |
| `images/screenshots/shot6.png` | Sous-menu « Check clothes size » sur un cadavre (sélection, ce cadavre, cadavres proches). |

## Hors de `docs/`

- `tests/` : vérifications hors jeu (`python tests/run_tests.py`), décrites dans [architecture.md](architecture.md#outillage).
- `source/` : fichiers Blender et scripts de génération des tuiles des deux machines.
- `README.steam*` et `workshop.txt` : descriptions de la page Steam Workshop (objet 3810122988).
