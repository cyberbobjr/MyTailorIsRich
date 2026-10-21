# Options sandbox

Toutes les options sont sur la page **My Tailor Is Rich** des réglages sandbox. Le mod les relit à chaque usage : une modification par un administrateur s'applique sans redémarrage, sauf le butin (appliqué au chargement de la partie).

> Capture à faire : la page sandbox My Tailor Is Rich.

## Compétence, durée et ajustement

| Option | Défaut | Bornes | Effet |
|---|---|---|---|
| Niveau de couture requis | Oui | — | Il faut assez de Couture pour lire les étiquettes et retoucher. Désactivé : tous les niveaux requis valent 0. |
| Multiplicateur d'XP de couture | 1,0 | 0–100 | XP de Couture des lectures, retouches, remises en état et patrons. |
| Multiplicateur de durée des actions | 1,0 | 0–100 | Durée des actions du mod. |
| Multiplicateur de déchirure | 1,0 | 0–100 | Déchirure d'un vêtement serré en escaladant un mur, une clôture ou une fenêtre. |
| Multiplicateur de chute du vêtement | 1,0 | 0–100 | Chute d'un bas trop grand sans ceinture, les deux mains prises. |
| Multiplicateur de perte d'isolation | 1,0 | 0–100 | Isolation perdue par un vêtement trop grand (jusqu'à 50 %). |
| Multiplicateur de gêne au combat | 1,0 | 0–100 | Ralentissement du combat par un haut trop grand. |
| Multiplicateur de risque de chute | 1,0 | 0–100 | Risque de tomber en enjambant une clôture avec un bas trop grand. |
| Multiplicateur de raideur | 1,0 | 0–100 | Raideur due aux vêtements serrés pendant l'exercice et la course. |

## Usure

| Option | Défaut | Bornes | Effet |
|---|---|---|---|
| Usure des vêtements | Oui | — | Les vêtements portés (pas les chaussures) perdent lentement de l'état. |
| Jours minimum d'usure | 30 | 1–720 | Jours pour une usure complète dans les pires conditions. |
| Jours maximum d'usure | 360 | 1–720 | Jours pour une usure complète dans les meilleures conditions. |
| Usure en cas d'échec | 0,5 | 0–1 | Chance de perdre de l'état sur une retouche ou une remise en état ratée. |
| Perte de protection par point d'état | 2,5 | 0–100 | % de la protection de base (griffure, morsure, balle) perdu par point d'état. |
| Perte de résistance par point d'état | 5,0 | 0–100 | % de la résistance de base (vent, eau) perdu par point d'état. |

## Objets qui ont une taille

| Option | Défaut | Effet |
|---|---|---|
| Vêtements supplémentaires | vide | Objets qui doivent avoir une taille, avec une difficulté facultative de 1 à 3, séparés par des virgules. Exemple : `Base.Clothing0,Base.Clothing1:1,Base.Clothing2:3` |
| Emplacements supplémentaires | vide | Emplacements (de tout mod) dont les vêtements ont une taille même sans parties du corps déclarées, difficulté facultative, séparés par des virgules ou des points-virgules. Exemple : `gorget;kiuc:2` |
| Vêtements exclus | vide | Objets qui ne doivent jamais avoir de taille, séparés par des virgules. Exemple : `Base.Apron_Black,SomeMod.Cape` |

## Chaussures

| Option | Défaut | Bornes | Effet |
|---|---|---|---|
| Pointures de chaussures | Oui | — | Les chaussures ont une pointure EU (35–47). |
| Afficher votre taille | Oui | — | Taille (et pointure) sur l'onglet Info du personnage. Toujours masquée si un mod masque le poids. |
| Intensité des effets des chaussures | 1,0 | 0–10 | Ampoules, endurance en plus et pertes de chaussures. 0 les coupe, inconfort compris. |

## Patrons

| Option | Défaut | Bornes | Effet |
|---|---|---|---|
| Coutures par patron | 5 | 1–50 | Coutures par patron (réussies ou ratées). |
| Couture pour les patrons de chaussures | 8 | 0–10 | Niveau pour coudre des chaussures (tracé : un de moins). Ignoré si le niveau requis est désactivé. |
| Copies de patrons | Oui | — | Autorise la copie des patrons. |
| Précision perdue par copie | 1 | 0–10 | Niveaux de précision perdus par copie. 0 : copies parfaites. |
| Patrons par classeur | 20 | 1–100 | Capacité d'un classeur. |
| Dé à coudre pour coudre à la main | Oui | — | Coudre à la main demande un dé (non consommé). |

## Machines, butin, teinture, broderie

| Option | Défaut | Bornes | Effet |
|---|---|---|---|
| Bonus des machines à coudre | 1,0 | 0–2 | Règle tous les bonus des machines. 0 = aucun bonus. |
| Bruit des machines à coudre | 1,0 | 0–3 | Portée du bruit qui attire les zombies. 0 = silencieuses. |
| Entretien des machines à coudre | Oui | — | Usure, aiguilles cassées, blocage et entretien. |
| Butin de couture | 1,0 | 0–10 | Fréquence des machines, patrons du commerce et classeurs dans le butin. 0 = jamais. |
| Activer la teinture | Oui | — | Teinture des vêtements. |
| Activer la broderie | Oui | — | Broderie d'un nom et onglet Broderie des machines. |
