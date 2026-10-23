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
3. **Machine à pédale** posée sur une case libre à une ou deux cases du joueur par le chemin du joueur : `ISMoveableSpriteProps:instanceItem` puis `placeMoveableInternal(nil, case, objet, "mtir_treadle_01_0")` (bonne classe, entité B42 du `SpriteConfig`, envoi aux clients). Lignes `INFO` : case du joueur, case visée, objet d'inventaire, objet créé ; en échec, la raison de chaque case rejetée. Reconnue par `machineFromPos`, utilisable, et table de travail.
4. **Patron tracé** (`MTIR_TracePatternAction`) avec la même sélection de feuilles que le menu ; une feuille **écrite**, une **renommée** et une **favorite** sont présentes : `predicatePaper` doit les refuser, l'autorité doit refuser un tracé qui liste la feuille écrite, et les trois feuilles doivent rester intactes (C01).
5. **Copie du patron** (`MTIR_CopyPatternAction`) : original gardé, copie `copies = 1`.
6. **Couture sur la machine** (`MTIR_SewPatternAction` avec `machinePos`) depuis la copie, à la taille du personnage : vêtement créé ; usure de la machine si l'entretien est activé. Une aiguille cassée (tirage de la machine) relance jusqu'à 4 essais.
7. **Teinture** (`MTIR_DyeAction`, `Base.IndustrialDye` et seau de 10 L d'eau) puis **broderie à la main** (`MTIR_EmbroiderAction`) : couleur personnalisée, nom et ModData de broderie.

Chaque objet de test porte la marque ModData `PZAT_MTIR` (rôle) et est envoyé à son propriétaire (`syncItemFields`). La machine posée est retirée à la fin.

## Contrôles côté client (MP, `--client-run`)

**Synchronisation (MP).** Le « go » de l'outil arrive dès `OnGameStart` du client, avant que son chargement soit fini : le 2026-10-21 le serveur a joué le scénario environ 4 s avant que le client soit prêt, sans case voisine utilisable pour la machine, et les objets envoyés pendant le chargement n'ont jamais atteint le client. Désormais le client envoie `ready` (commande `PZAT_MTIR`) toutes les 2 s jusqu'à la réponse `started` ; le serveur attend ce message (60 s au plus, sinon `WARN` et départ) et que la case du joueur soit chargée (90 s, sinon `FAIL`). À la fin, le serveur envoie `done` avec les rôles réellement préparés, le résumé et le premier échec.

Le client 1 attend le message `done` (180 s, paramètre `clientWaitSec`), puis au plus 30 s les objets des rôles annoncés, et vérifie sur sa propre copie : pointure révélée, taille et retouche, feuilles protégées toujours possédées, données des patrons et de la copie, taille du vêtement cousu, couleur personnalisée, nom et ModData de broderie. La **teinte du visuel** d'un vêtement non porté est notée `WARN` sans échec : `syncItemFields` transmet la couleur personnalisée, pas la teinte du visuel (base moteur, `clothing-tint.md`) ; les autres joueurs la reçoivent à l'enfilage.

## Limites

- Les actions sont complétées sans leur durée, leur animation ni leur son ; les menus, le panneau de la machine et l'infobulle ne sont pas ouverts. Le rendu reste à vérifier à l'œil.
- La machine électrique (courant) et la broderie à la machine ne sont pas couvertes.
- Les contrôles C01 supposent la correction de C01 (`MTIR.isBlankSheet`, `predicatePaper`), présente depuis la 0.4.6.
- Écrit le 2026-10-21. Premier passage `mp` (`runs/20261021-161320-mp-70b8a05b75af`) : 5 PASS serveur puis échec de la pose de la machine (aucune case trouvée, scénario lancé avant la fin du chargement du client) ; client 0/9. Corrigé par la synchronisation ci-dessus et la pose par `placeMoveableInternal` (`f11ee94`). Passage suivant (`…164655-mp-a9af45a5d6f9`) : serveur 15/15, client 7/8, nom brodé suivi du suffixe vanilla d'humidité (« (trempé) », le vêtement sort de la teinture) ; contrôle corrigé pour accepter ce suffixe (`834facc`), sans défaut du mod.

## Résultats

Dernière campagne verte le 2026-10-21, sur le mod publié en 0.4.6 (code de sortie 0, aucune erreur Lua) :

| Mode | Passage | Résultat |
|---|---|---|
| `sp` | `runs/20261021-164228-sp-76732312ac75` | 15 PASS, 0 FAIL |
| `mp` (1 client) | `runs/20261021-170004-mp-776a550dfea3` | serveur 15 PASS ; client 8 PASS, 1 `WARN` attendu (teinte du visuel d'un vêtement non porté) |

Le premier passage `sp` (`…155749-sp-4e8b08d9e37f`) n'a pas démarré : la sauvegarde la plus récente exigeait une carte absente ; la configuration utilise depuis la sauvegarde Sandbox partagée (`0d069c8`).
- Un échec côté serveur apparaît chez le client comme `FAIL client: server scenario completed` ; seuls les objets réellement préparés sont contrôlés.
