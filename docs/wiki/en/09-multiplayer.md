# Multiplayer

The mod works on dedicated servers, hosted (co-op) games and in split screen.

## The server decides

The server decides everything: sizes, label reading, resizing, wear, blisters, stiffness, lost shoes, patterns, binders, dyeing, embroidery and machine condition. It then syncs the result to the players concerned. All actions run through the vanilla Build 42 timed-action network system, and the server checks every requirement again before applying an action.

## What other players see

- A dyed garment shows its color to other players once it is put on.
- A sewing machine at work is heard by nearby players, and only one player can use a machine at a time.
- Lost shoes, fallen pants and ripped clothes are visible to everyone.

## Language

Pattern names are written into the item by the server, in the **server's language**. Everything else (speech lines, menus, tooltips) is in each player's language.

## Admin tools

Players with a role allowed to edit items can use **[Debug] Size** (see [FAQ](10-faq-and-compatibility.md#debug-tools)). Sandbox options can be changed in game by an admin and apply at once, except loot rarity.

## Before going public

See [Installation](01-installation.md#dedicated-or-hosted-server) for the server setup and [Removing the mod from a save](10-faq-and-compatibility.md#removing-the-mod-from-a-save) before ever removing it: a server world that had the mod refuses every client once it is gone.
