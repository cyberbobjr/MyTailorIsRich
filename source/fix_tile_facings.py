"""Add the rotation offsets to a generated .tiles file.

A moveable only rotates when its sprite properties say where its other facings
are: ISMoveableSpriteProps:hasFaces() returns false unless at least one of
Noffset / Soffset / Woffset / Eoffset is set, and getFaces() builds the sibling
sprite name as <sheet>_<id + offset> (media/lua/shared/Moveables/
ISMoveableSpriteProps.lua:258-311, 42.21). Without them the placement cursor
keeps the sprite of the inventory item whatever facing the player picks, and
the Rotate mode does nothing.

pz-sprite-forge writes Facing on each rendered facing but no offset, so run
this on the generated files before copying them into the mod:

    python source/fix_tile_facings.py Contents/mods/batman_MyTailorIsRich/common/media/mtir_sewing_01.tiles

It rewrites, in place, every sheet whose sprites carry exactly four Facing
properties on consecutive indices, and leaves anything else untouched.

    python source/fix_tile_facings.py --check <file>    reports without writing
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

MAGIC = b"tdef"
FACINGS = ("N", "S", "W", "E")
OFFSET_KEYS = {"N": "Noffset", "S": "Soffset", "W": "Woffset", "E": "Eoffset"}


class Reader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.pos = 0

    def int32(self) -> int:
        value = struct.unpack_from("<i", self.data, self.pos)[0]
        self.pos += 4
        return value

    def line(self) -> str:
        end = self.data.index(b"\n", self.pos)
        value = self.data[self.pos:end].decode("utf-8")
        self.pos = end + 1
        return value


def parse(data: bytes) -> tuple[int, list]:
    """(version, [ (sheet, png, cols, rows, levels, [ [ (key, value), ... ] ]) ])."""
    if data[:4] != MAGIC:
        raise SystemExit("not a .tiles file (missing 'tdef' magic)")
    r = Reader(data)
    r.pos = 4
    version = r.int32()
    sheets = []
    for _ in range(r.int32()):
        name, png = r.line(), r.line()
        cols, rows, levels, count = r.int32(), r.int32(), r.int32(), r.int32()
        sprites = []
        for _ in range(count):
            props = [(r.line(), r.line()) for _ in range(r.int32())]
            sprites.append(props)
        sheets.append((name, png, cols, rows, levels, sprites))
    if r.pos != len(data):
        raise SystemExit("trailing bytes: unsupported .tiles layout")
    return version, sheets


def serialize(version: int, sheets: list) -> bytes:
    out = bytearray(MAGIC)
    out += struct.pack("<i", version)
    out += struct.pack("<i", len(sheets))
    for name, png, cols, rows, levels, sprites in sheets:
        out += name.encode("utf-8") + b"\n"
        out += png.encode("utf-8") + b"\n"
        out += struct.pack("<iiii", cols, rows, levels, len(sprites))
        for props in sprites:
            out += struct.pack("<i", len(props))
            for key, value in props:
                out += key.encode("utf-8") + b"\n" + value.encode("utf-8") + b"\n"
    return bytes(out)


def facing_group(sprites: list) -> dict | None:
    """{facing: index} when the sheet holds exactly the four facings, else None."""
    group = {}
    for index, props in enumerate(sprites):
        for key, value in props:
            if key == "Facing":
                if value in group:
                    return None
                group[value] = index
    if sorted(group) != sorted(FACINGS):
        return None
    if sorted(group.values()) != list(range(min(group.values()), min(group.values()) + 4)):
        return None
    return group


def add_offsets(sprites: list, group: dict) -> list:
    """Offsets toward the three other facings; returns the changes made."""
    changes = []
    for own, index in group.items():
        props = [(key, value) for key, value in sprites[index]
                 if key not in OFFSET_KEYS.values()]
        for facing, other in sorted(group.items()):
            if facing == own:
                continue
            delta = other - index
            props.append((OFFSET_KEYS[facing], str(delta)))
            changes.append((index, OFFSET_KEYS[facing], delta))
        sprites[index] = props
    return changes


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--check", action="store_true",
                        help="report what is missing, write nothing")
    args = parser.parse_args(argv)

    missing = 0
    for path in args.files:
        data = path.read_bytes()
        version, sheets = parse(data)
        touched = []
        for name, _png, _cols, _rows, _levels, sprites in sheets:
            group = facing_group(sprites)
            if not group:
                continue
            already = any(key in OFFSET_KEYS.values()
                          for props in sprites for key, _ in props)
            if already and args.check:
                continue
            changes = add_offsets(sprites, group)
            if not already:
                missing += 1
            touched.append((name, group, changes))
        for name, group, changes in touched:
            facings = ", ".join("%s=%d" % (f, i) for f, i in sorted(group.items()))
            print("%s: %s -> %d offsets" % (name, facings, len(changes)))
        if touched and not args.check:
            path.write_bytes(serialize(version, sheets))
            print("written: %s" % path)
    if args.check:
        print("missing offsets in %d sheet(s)" % missing)
        return 1 if missing else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
