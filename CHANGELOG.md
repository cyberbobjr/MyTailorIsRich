# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

## 0.4.2 — 2026-10-02

### Improvements
- **Check clothes size** now has three submenu options: **Selected clothes**, **All clothes on this corpse**, and **All clothes on nearby corpses**. Shoes are included; the corpse option appears when the selected clothing is on a corpse.
- Group checks only cover accessible corpses within reach. Clothes stay on the bodies, without moving your character. Each label keeps its usual duration, Tailoring requirements and XP.
- Clothes removed or already checked by another player before their turn are skipped without cancelling the remaining checks.
- Group checks skip known sizes and hints your current Tailoring level cannot yet improve. You can check those hints again after gaining the required level, or inspect them manually from **Selected clothes**.

## 0.4.1 — 2026-10-02

### New
- **Embroidery on the sewing machines**: a fourth tab, **Embroidery**, in the panel of both machines. Drop a garment in the slot (or click to choose one), type the text (your first name to start with), see the name it will get, and embroider. Needle and one use of thread, no thimble. As with any other machine job, it makes noise, wears the machine out, can break the needle, and a worn machine can fail (the name doesn't change and half the thread is lost).
- **Electric machine**: twice as fast as by hand, Tailoring 1 with the machine's bonus levels counted.
- **Treadle machine**: straight stitch only, so it is harder: **Tailoring 3** (the machine's bonus does not count), 25% faster than by hand.
- Already embroidered garments are shown as such; unpicking stays a hand job with scissors, from the right-click menu.

## 0.4.0 — 2026-10-01

### New
- **Pattern Binder**: keep up to 20 sewing patterns in one binder (craft it with **Make Pattern Binder**: scissors, needle, thread, two fabric strips and two sheets of paper, or find it with sewing supplies). Store and take out patterns from the right-click menu, sew straight from a stored pattern, and pick stored patterns in the sewing machine's Pattern tab. Patterns keep their uses and precision.
- **Copy pattern**: transfer a pattern onto new sheets of paper at a table (scissors, pen or pencil), without destroying it. Each copy is a little less precise than its original, and gets fresh uses.
- **Preview on me**: see your character wearing the garment or shoes of a pattern in 3D, from the pattern, the binder or the sewing machine. Rotate with the mouse or the arrow keys. Clothes from other mods are supported, and nothing is actually worn.
- **Dye**: dye clothes and shoes with industrial dye or hair dye, plus water. Pick the dye, and the garment takes its color and comes out soaked. Any garment made to be tinted can be dyed, **clothing mods included**; printed or patterned clothes can't (the option is greyed out with an explanation).
- **Embroider a name** on a garment with a needle and thread (Tailoring 1). It shows in the item's name and tooltip. **Unpick the embroidery** with scissors to get the old name back.
- Sandbox options: **Pattern copies**, **Precision lost per copy**, **Patterns per binder**, **Enable dyeing**, **Enable embroidery**.

## 0.3.2 — 2026-09-30

### Improvements
- **Check clothes size** no longer moves the garment into your inventory: clothes on a corpse, in a piece of furniture or in a vehicle within reach are checked where they are. Your character walks up to the container if needed, and walking away stops the check.
- Clothes in a bag you carry are checked inside the bag, without moving them to your main inventory.
- Clothes lying on the floor are still picked up before being checked, so that the size you read stays in sync in multiplayer.

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
