# Test en jeu automatique (pz-autotest)

Parcours nominal de My Tailor Is Rich joué par script dans le vrai jeu 42.21, sans personne devant le PC, avec l'outil générique `C:\Users\cyber\Zomboid\Workshop\.claude\tools\pz-autotest` (voir son `README.md` et le skill `pz-autotest`).

Fichiers : [`autotest.json`](../../../autotest.json) (mods chargés, sauvegarde, serveur) et [`autotest/mtir_hooks.lua`](../../../autotest/mtir_hooks.lua) (scénario et contrôles). Les résultats vont dans `runs/` (ignoré par git).

## Commandes

Depuis `C:\Users\cyber\Zomboid\Workshop` :

```powershell
python .claude/tools/pz-autotest/pz_autotest.py check MyTailorIsRich                                   # config, mods, hooks
python .claude/tools/pz-autotest/pz_autotest.py sp    MyTailorIsRich --wait-idle 3600                  # client solo
python .claude/tools/pz-autotest/pz_autotest.py mp    MyTailorIsRich --clients 1 --client-run --wait-idle 3600
```

Mods chargés : TooltipLib (Workshop 3694097672, copié en lecture) puis `Contents/mods/batman_MyTailorIsRich`. En solo, la sauvegarde Sandbox la plus récente (`20*`) est copiée et sa liste de mods remplacée.

## Ce que fait le scénario

L'autorité (client solo, ou serveur dédié en MP sur le premier joueur connecté) appelle directement `complete()` des vraies actions chronométrées du mod, comme le serveur après une demande du client. Le personnage reçoit Couture 10 (`setPerkLevelDebug`), dé, aiguille, ciseaux, crayon et fil.

1. **Étiquette et pointure** : `MTIR_CheckSizeAction` sur un vêtement taillé (taille révélée) et sur des chaussures (pointure révélée).
2. **Retouche à la main** : `MTIR_ResizeAction` (trombones pour rétrécir, bandes pour agrandir si la taille est déjà la plus petite) ; nouvelle taille et `resized` vérifiés.
3. **Machine à pédale** posée sur une case libre voisine (objet de tuile `mtir_treadle_01_0`, sans passer par l'objet d'inventaire) : reconnue par `machineFromPos`, utilisable, et table de travail.
4. **Patron tracé** (`MTIR_TracePatternAction`) avec la même sélection de feuilles que le menu ; une feuille **écrite**, une **renommée** et une **favorite** sont présentes : `predicatePaper` doit les refuser, l'autorité doit refuser un tracé qui liste la feuille écrite, et les trois feuilles doivent rester intactes (C01).
5. **Copie du patron** (`MTIR_CopyPatternAction`) : original gardé, copie `copies = 1`.
6. **Couture sur la machine** (`MTIR_SewPatternAction` avec `machinePos`) depuis la copie, à la taille du personnage : vêtement créé ; usure de la machine si l'entretien est activé. Une aiguille cassée (tirage de la machine) relance jusqu'à 4 essais.
7. **Teinture** (`MTIR_DyeAction`, `Base.IndustrialDye` et seau de 10 L d'eau) puis **broderie à la main** (`MTIR_EmbroiderAction`) : couleur personnalisée, nom et ModData de broderie.

Chaque objet de test porte la marque ModData `PZAT_MTIR` (rôle) et est envoyé à son propriétaire (`syncItemFields`). La machine posée est retirée à la fin.

## Contrôles côté client (MP, `--client-run`)

Le client 1 attend (180 s, paramètre `clientWaitSec`) de recevoir tous les objets marqués, puis vérifie sur sa propre copie : pointure révélée, taille et retouche, feuilles protégées toujours possédées, données des patrons et de la copie, taille du vêtement cousu, couleur personnalisée, nom et ModData de broderie. La **teinte du visuel** d'un vêtement non porté est notée `WARN` sans échec : `syncItemFields` transmet la couleur personnalisée, pas la teinte du visuel (base moteur, `clothing-tint.md`) ; les autres joueurs la reçoivent à l'enfilage.

## Limites

- Les actions sont complétées sans leur durée, leur animation ni leur son ; les menus, le panneau de la machine et l'infobulle ne sont pas ouverts. Le rendu reste à vérifier à l'œil.
- La machine électrique (courant) et la broderie à la machine ne sont pas couvertes.
- Les contrôles C01 échouent tant que la correction de C01 (`MTIR.isBlankSheet`, `predicatePaper`) n'est pas dans le mod chargé.
- Écrit le 2026-10-21 ; `check` et luacheck passent. **Aucun passage `sp` ni `mp` n'a encore été lancé.**
