# FAQ and compatibility

## Compatibility

| Mod | Status |
|---|---|
| [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672) | **Required.** |
| [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) | **Incompatible** (declared in the mod). My Tailor Is Rich is its rewrite for Build 42.21. |
| [Immersive Weighing](https://steamcommunity.com/sharedfiles/filedetails/?id=3791897755) | Compatible: when your weight is hidden, your size is hidden too, since it follows your weight. |
| Clothing mods | Compatible: their clothes are sized automatically from what they cover; store-bought patterns, the 3D preview and dyeing include them. |
| Loot mods that add sewing kits | Compatible: the electric machine can turn up where they put a sewing kit. |

## A modded garment has no size (or shouldn't have one)

Clothes from other mods get a size from the body parts they cover. Hats, masks, gloves, jewelry, belts, socks and similar accessories never do. If a garment is missed or wrongly sized, use the sandbox options **List custom clothes**, **Extra sized locations** or **List excluded clothes** ([Sandbox options](08-sandbox-options.md#which-items-are-sized)).

## Why doesn't a loose garment slow me down?

In Build 42.21 the vanilla `RunSpeedModifier` of clothes is never applied to movement (only bags use it). The mod uses what the engine allows: foot injuries (blisters) and endurance.

## My arms are sore after a fight

Arm soreness comes from **vanilla shoving**: every push adds arm strain. Tight tops only make it last longer.

## Can I add the mod to an existing save?

Yes. Clothes already in the world get a size the first time it is needed.

## Removing the mod from a save

Don't just disable the mod in an existing save. The game records the two sewing machines (`Base.MTIR_SewingMachine`, `Base.MTIR_TreadleMachine`) in the save's `WorldDictionary.bin` and, in Build 42.21, never clears that record. Once the mod is gone, every multiplayer client, co-op host included, is refused with `[SpriteConfigs] Missing dictionary script on client: Base.MTIR_TreadleMachine`.

The Workshop item ships a second mod for this: **`batman_MyTailorIsRich_Uninstall`**.

1. In the save's mod list (or the server's mod list), replace `batman_MyTailorIsRich` with `batman_MyTailorIsRich_Uninstall`. Keep the Workshop item subscribed.
2. Keep it enabled for good in that save: removing it brings the error back.
3. Never enable both mods together (they are declared incompatible).

It contains no code: placed machines stay in the world as plain furniture (no sewing panel), and picked-up machines stay valid items. Clothes keep their sizes in their data but have no effect anymore. Patterns, binders and other items of the mod disappear, as with any removed mod.

## Debug tools

In debug mode, or in multiplayer with a role allowed to edit items, right-click a garment or shoes and open **[Debug] Size**. It shows your size, foot size, stomp power, trip and shoe-loss risks and, in singleplayer, the friction gauge, lets you set any size, or clears it for a new roll.

> Capture à faire : the [Debug] Size submenu on a pair of shoes.

## Reporting a problem

Open an issue on [GitHub](https://github.com/cyberbobjr/MyTailorIsRich/issues) with your game version, mod list and the lines starting with `[MTIR]` or the error from `console.txt`.
