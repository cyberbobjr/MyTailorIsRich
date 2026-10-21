# Sandbox options

All options are on the **My Tailor Is Rich** page of the sandbox settings. The mod reads them each time it needs them, so an admin change applies without restarting, except loot rarity (applied when the game loads).

> Capture à faire : the My Tailor Is Rich sandbox page.

## Skill, time and fit

| Option | Default | Range | Effect |
|---|---|---|---|
| Need tailoring level | On | — | Players need enough Tailoring to read labels and to resize clothes. Off: every level requirement is 0. |
| Tailoring exp multiplier | 1.0 | 0–100 | Tailoring XP from checking, resizing, reconditioning and patterns. |
| Action time multiplier | 1.0 | 0–100 | Duration of the mod's actions. |
| Rip chance multiplier | 1.0 | 0–100 | Tight clothes ripping when climbing a wall, fence or window. |
| Drop chance multiplier | 1.0 | 0–100 | Loose pants and skirts falling without a belt while both hands are busy. |
| Insulation reduce multiplier | 1.0 | 0–100 | Insulation lost by loose clothes (up to 50%). |
| Combat speed reduce multiplier | 1.0 | 0–100 | How much loose tops slow down combat. |
| Increase trip chance multiplier | 1.0 | 0–100 | Extra chance to fall when vaulting fences in loose clothes. |
| Increase stiffness multiplier | 1.0 | 0–100 | Stiffness from tight clothes during exercise and running. |

## Wear

| Option | Default | Range | Effect |
|---|---|---|---|
| Enable clothes degrading | On | — | Worn clothes (not shoes) slowly lose condition. |
| Min days to degrade | 30 | 1–720 | Days to fully wear out in the worst conditions. |
| Max days to degrade | 360 | 1–720 | Days to fully wear out in the best conditions. |
| Chance to degrade on failure | 0.5 | 0–1 | Chance to lose condition when resizing or reconditioning fails. |
| Protection loss each condition | 2.5 | 0–100 | % of base protection (scratch, bite, bullet) lost per condition point. |
| Resistance loss each condition | 5.0 | 0–100 | % of base resistance (wind, water) lost per condition point. |

## Which items are sized

| Option | Default | Effect |
|---|---|---|
| List custom clothes | empty | Items that should have sizes, with an optional difficulty 1–3, separated by commas. Example: `Base.Clothing0,Base.Clothing1:1,Base.Clothing2:3` |
| Extra sized locations | empty | Body locations (from any mod) whose clothes get a size even when they declare no covered body parts, optional difficulty, separated by commas or semicolons. Example: `gorget;kiuc:2` |
| List excluded clothes | empty | Items that must never have a size, separated by commas. Example: `Base.Apron_Black,SomeMod.Cape` |

## Shoes

| Option | Default | Range | Effect |
|---|---|---|---|
| Enable shoe sizes | On | — | Shoes get an EU size (35–47). |
| Show player size | On | — | Your size (and foot size) on the character Info tab. Always hidden when a mod hides your weight. |
| Shoe effect multiplier | 1.0 | 0–10 | Blisters, extra endurance use and shoe loss. 0 disables them and the discomfort. |

## Patterns

| Option | Default | Range | Effect |
|---|---|---|---|
| Pattern max uses | 5 | 1–50 | Sewings per pattern (success or failure). |
| Shoe pattern level | 8 | 0–10 | Tailoring to sew shoes from a pattern (tracing: one less). Ignored when the level requirement is off. |
| Enable pattern copy | On | — | Allows copying patterns. |
| Pattern copy precision loss | 1 | 0–10 | Precision levels lost per copy. 0: perfect copies. |
| Pattern binder capacity | 20 | 1–100 | Patterns per binder. |
| Require thimble | On | — | Sewing by hand needs a thimble (not used up). |

## Machines, loot, dyeing, embroidery

| Option | Default | Range | Effect |
|---|---|---|---|
| Machine bonus multiplier | 1.0 | 0–2 | Scales every machine bonus. 0 = no bonus. |
| Machine noise multiplier | 1.0 | 0–3 | Range of the noise that attracts zombies. 0 = silent. |
| Enable machine maintenance | On | — | Wear, broken needles, jams and servicing. |
| Sewing loot multiplier | 1.0 | 0–10 | How often machines, store-bought patterns and binders appear in loot. 0 = never. |
| Enable dyeing | On | — | Dyeing clothes. |
| Enable embroidery | On | — | Embroidering a name, and the machine's Embroidery tab. |
