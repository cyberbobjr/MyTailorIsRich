# Multijoueur

Le mod fonctionne sur serveur dédié, en partie hébergée (coopération) et en écran partagé.

## Le serveur décide

Le serveur décide de tout : tailles, lecture des étiquettes, retouches, usure, ampoules, raideur, chaussures perdues, patrons, classeurs, teinture, broderie et état des machines. Il synchronise ensuite le résultat vers les joueurs concernés. Toutes les actions passent par le système d'actions réseau vanilla de la Build 42, et le serveur revérifie chaque besoin avant d'appliquer une action.

## Ce que voient les autres joueurs

- Un vêtement teint montre sa couleur aux autres joueurs une fois enfilé.
- Une machine à coudre au travail s'entend des joueurs proches, et un seul joueur à la fois peut l'utiliser.
- Chaussures perdues, pantalons tombés et vêtements déchirés sont visibles de tous.

## Langue

Le nom d'un patron est écrit dans l'objet par le serveur, dans la **langue du serveur**. Tout le reste (répliques, menus, infobulles) est dans la langue de chaque joueur.

## Outils d'administration

Les joueurs dont le rôle autorise l'édition des objets ont accès à **[Debug] Taille** (voir la [FAQ](10-faq-et-compatibilite.md#outils-de-débogage)). Un administrateur peut changer les options sandbox en jeu : elles s'appliquent aussitôt, sauf le butin.

## Avant d'ouvrir le serveur

Voir [Installation](01-installation.md#serveur-dédié-ou-partie-hébergée) pour la configuration du serveur, et [Retirer le mod d'une partie](10-faq-et-compatibilite.md#retirer-le-mod-dune-partie) avant de jamais le retirer : un monde de serveur qui a eu le mod refuse tous les clients une fois le mod retiré.
