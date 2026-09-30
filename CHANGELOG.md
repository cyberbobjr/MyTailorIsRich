# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

## 0.3.1 — 2026-09-30

### Compatibility
- **Immersive Weighing** is now supported: your weight stays hidden on the character screen, and your size (derived from your weight) is hidden along with it.

### New
- Sandbox option **Show your size**: turn off the size shown next to your weight on the character screen.

## 0.3.0 — 2026-09-30

### New
- **Uninstall helper**: a second mod, **batman_MyTailorIsRich_Uninstall**, is now included. Removing My Tailor Is Rich from an existing save made multiplayer worlds impossible to join ("Missing dictionary script on client: Base.MTIR_TreadleMachine"): the game keeps the sewing machines on record in the save and never lets go of them. To remove the mod, replace it with the uninstall helper in your mod list or on your server, and keep the helper enabled in that save. It only keeps the sewing machines, as plain furniture. Never enable both.

### Changes
- The Workshop description explains how to remove the mod from a save.

## 0.2.0 — 2026-09-29

### New
- **Translations**: German, Spanish, Portuguese (Brazil and Portugal), Russian and Simplified Chinese, in game and on the Workshop page.

### Improvements
- The sewing machine panel adapts its width to your language and font size: texts no longer overflow the tabs, the Maintain button or the bonus list.
- Better performance: the shoe discomfort check no longer runs every tick when nobody wears ill-fitting shoes.

## 0.1.0 — 2026-09-29

- First release on the Workshop: clothing sizes (XS to XXL) and shoe sizes (EU 35 to 47), alterations, clothes wear and reconditioning, sewing patterns, electric and treadle sewing machines.
