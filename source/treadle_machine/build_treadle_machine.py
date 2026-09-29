"""Treadle sewing machine tile (mtir_treadle_01) for My Tailor Is Rich.

Floor furniture, one tile: a 1900-1950 treadle cabinet (black cast-iron
openwork side frames, foot treadle, drive belt, flywheel, wooden top with a
drawer, black machine head with thin gold lines and a handwheel). The table top
stands at the vanilla table height (Surface = 34, 0.8675 m). Four facings S, E,
N, W (sprites _0 to _3); the operator side faces -Y = south.

Needs pz-sprite-forge (MIT, https://github.com/Leeheejin/pz-sprite-forge).
Render headless (the forge rig uses global object names: do not run it in a
Blender file that already holds another forge rig):
    set PZ_FORGE=<path to pz-sprite-forge>
    blender -b --factory-startup -P source/treadle_machine/build_treadle_machine.py -- <cells-dir>
Package:
    python -m pzforge.cli build <cells-dir> --out <dist> --mod-id MTIRTreadleTiles \
        --sheet mtir_treadle_01 --tileset-id 1 --tiledef-id 7172 \
        --prop "CustomName=Sewing Machine" --prop "GroupName=Treadle" \
        --prop IsMoveAble= --prop PickUpWeight=300 --prop BlocksPlacement= \
        --prop CanScrap= --prop Material=Wood --prop Material2=MetalScrap \
        --prop ScrapSize=Medium --prop solidtrans=
then copy <dist>/MTIRTreadleTiles/42/media/texturepacks/mtir_treadle_01.pack and
mtir_treadle_01.tiles into Contents/mods/batman_MyTailorIsRich/common/media/, and
<cells-dir>/panel_art.png to 42.21/media/textures/MTIR_TreadleMachinePanel.png
(illustration of the treadle machine panel).
Depth map (B42 discards every sprite pixel outside the depth map; never borrow a
smaller vanilla tile's), with the tools of the pz-blender-assets skill
(Workshop/content/108600/.claude/skills/pz-blender-assets/scripts):
    blender -b --factory-startup -P <scripts>/build_depthmap.py -- <this script> depth.json
    python <scripts>/build_depthmap.py depth.json <mod>/common/media/texturepacks/mtir_treadle_01.pack
        mtir_treadle_01 <mod>/common/media/depthmaps/DEPTH_mtir_treadle_01.png
(common/media/tileGeometry.txt must exist for the game to load it).
Editable copy of the model: mtir_treadle_01.blend, next to this script, from
    blender -b --factory-startup -P <scripts>/save_blend.py -- <this script> mtir_treadle_01.blend mtir_treadle_01
"""
from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

FORGE = Path(os.environ["PZ_FORGE"])
sys.path.insert(0, str(FORGE / "blender"))

import pz_sprite_forge as F  # noqa: E402

#: Whole cabinet: real size x 1.1, which puts the top at the vanilla table height.
SCALE = 1.1
#: Table top height before SCALE (0.79 * 1.1 = 0.869 m, vanilla Surface 34).
TOP_Z = 0.79
#: The machine head is drawn larger than life so it reads at game scale.
HEAD_BOOST = 1.25
#: Head origin on the table (before SCALE): needle end left, handwheel right.
HEAD_X = 0.03
#: Flywheel (under the table, right side) and handwheel share this x.
DRIVE_X = 0.28
FLYWHEEL_Z = 0.40
FLYWHEEL_R = 0.17
FRAME_X = 0.40

PAINTS = {
    "iron": (0.105, 0.105, 0.110),  # cast-iron frames, treadle, flywheel
    "black": (0.070, 0.070, 0.075),  # japanned machine head
    "gold": (0.78, 0.60, 0.24),      # decals, brass knobs
    "wood": (0.46, 0.20, 0.07),      # walnut top
    "drawer": (0.36, 0.15, 0.055),   # drawer fronts
    "steel": (0.62, 0.63, 0.65),     # needle bar, presser foot, face plate
    "belt": (0.40, 0.24, 0.12),      # leather belt
    "spool": (0.72, 0.12, 0.10),     # red thread spool
}
MATERIAL_CLASS = {"wood": "wood", "drawer": "wood"}


def materials() -> dict:
    return {key: F.forge_material(f"mtir_trd_{key}", MATERIAL_CLASS.get(key, "metal"), paint)
            for key, paint in PAINTS.items()}


class Parts:
    """Primitives parented to an anchor; coordinates in metres before SCALE."""

    def __init__(self, anchor, mats, k=SCALE):
        self.anchor, self.mats, self.k = anchor, mats, k

    def _link(self, obj, name, mat):
        obj.name = name
        obj.data.materials.append(self.mats[mat])
        obj.parent = self.anchor
        return obj

    def box(self, name, c, size, mat, bevel=0.15, rot=(0, 0, 0)):
        k = self.k
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=tuple(v * k for v in c), rotation=rot)
        obj = bpy.context.active_object
        obj.scale = tuple(v * k for v in size)
        bpy.ops.object.transform_apply(scale=True)
        if bevel:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = min(size) * k * bevel
            mod.segments = 2
        return self._link(obj, name, mat)

    def cyl(self, name, c, radius, depth, axis, mat, verts=32):
        rotation = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius * self.k,
                                            depth=depth * self.k,
                                            location=tuple(v * self.k for v in c), rotation=rotation)
        return self._link(bpy.context.active_object, name, mat)

    def rod(self, name, p0, p1, radius, mat, verts=8):
        a, b = Vector(p0) * self.k, Vector(p1) * self.k
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius * self.k,
                                            depth=(b - a).length, location=(a + b) / 2)
        obj = bpy.context.active_object
        obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
        return self._link(obj, name, mat)

    def ring(self, name, c, major, minor, axis, mat):
        rotation = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
        bpy.ops.mesh.primitive_torus_add(major_radius=major * self.k, minor_radius=minor * self.k,
                                         major_segments=40, minor_segments=10,
                                         location=tuple(v * self.k for v in c), rotation=rotation)
        return self._link(bpy.context.active_object, name, mat)


def build_cabinet(p: Parts) -> None:
    """Plateau en bois, tiroir à gauche, bandeau avant."""
    p.box("top", (0, 0, TOP_Z - 0.0175), (0.92, 0.48, 0.035), "wood", 0.3)
    p.box("apron", (0.10, -0.215, TOP_Z - 0.055), (0.56, 0.02, 0.05), "wood", 0)
    p.box("drawer_box", (-0.32, 0.0, TOP_Z - 0.125), (0.24, 0.44, 0.215), "wood", 0.05)
    for i, z in enumerate((TOP_Z - 0.075, TOP_Z - 0.180)):
        p.box(f"drawer_{i}", (-0.32, -0.223, z), (0.21, 0.012, 0.085), "drawer", 0.2)
        p.cyl(f"knob_{i}", (-0.32, -0.235, z), 0.012, 0.016, "y", "gold", 12)


def build_frame(p: Parts, x: float, side: str) -> None:
    """Bâti latéral en fonte ajourée (plan YZ) : pied, montants, anneau, entretoises."""
    top = TOP_Z - 0.04
    p.box(f"foot_{side}", (x, 0, 0.03), (0.05, 0.50, 0.05), "iron", 0.2)
    for s, tag in ((-1, "f"), (1, "b")):
        p.box(f"pad_{side}{tag}", (x, s * 0.235, 0.012), (0.07, 0.06, 0.024), "iron", 0.2)
        p.rod(f"leg_{side}{tag}", (x, s * 0.21, 0.05), (x, s * 0.16, top), 0.022, "iron")
        p.rod(f"brace_up_{side}{tag}", (x, s * 0.06, 0.52), (x, s * 0.155, top - 0.01), 0.013, "iron")
        p.rod(f"brace_lo_{side}{tag}", (x, s * 0.06, 0.32), (x, s * 0.20, 0.07), 0.013, "iron")
        p.rod(f"strut_{side}{tag}", (x, s * 0.11, 0.42), (x, s * 0.185, 0.42), 0.013, "iron")
    p.box(f"rail_{side}", (x, 0, top), (0.05, 0.40, 0.04), "iron", 0.2)
    p.ring(f"ring_{side}", (x, 0, 0.42), 0.11, 0.017, "x", "iron")
    p.cyl(f"boss_{side}", (x, 0, 0.42), 0.03, 0.05, "x", "iron", 16)


def build_treadle(p: Parts, anchor, mats) -> None:
    """Pédale ajourée pivotant sur un axe, entretoise arrière et bielle."""
    p.rod("stretcher", (-FRAME_X, 0.17, 0.15), (FRAME_X, 0.17, 0.15), 0.014, "iron")
    p.rod("pivot", (-FRAME_X, -0.02, 0.12), (FRAME_X, -0.02, 0.12), 0.012, "iron")
    pivot = bpy.data.objects.new("treadle_pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.parent = anchor
    pivot.location = (0, -0.02 * SCALE, 0.12 * SCALE)
    pivot.rotation_euler = (math.radians(8), 0, 0)
    t = Parts(pivot, mats)
    w, d = 0.58, 0.30
    for s, tag in ((-1, "f"), (1, "b")):
        t.box(f"tread_edge_{tag}", (0, s * d / 2, 0), (w, 0.03, 0.022), "iron", 0.2)
    for s, tag in ((-1, "l"), (1, "r")):
        t.box(f"tread_side_{tag}", (s * w / 2, 0, 0), (0.03, d, 0.022), "iron", 0.2)
    for i in range(7):
        x = -w / 2 + (i + 0.5) * w / 7
        t.rod(f"tread_bar_{i}", (x - 0.04, -d / 2, 0), (x + 0.04, d / 2, 0), 0.008, "iron", 6)
    t.box("tread_center", (0, 0, 0.004), (0.12, 0.08, 0.02), "iron", 0.2)
    p.rod("pitman", (DRIVE_X - 0.03, 0.10, 0.18), (DRIVE_X - 0.03, 0.07, FLYWHEEL_Z - 0.05),
          0.011, "iron")


def build_drive(p: Parts) -> None:
    """Grand volant sous le plateau et courroie jusqu'au volant de la tête."""
    x, z, r = DRIVE_X, FLYWHEEL_Z, FLYWHEEL_R
    # Jante à gorge : deux tores accolés, les rayons restent visibles.
    for dx, tag in ((-0.011, "a"), (0.011, "b")):
        p.ring(f"flywheel_{tag}", (x + dx, 0, z), r, 0.016, "x", "iron")
    for i in range(6):
        a = math.radians(30 + 60 * i)
        p.rod(f"spoke_{i}", (x, 0, z), (x, math.cos(a) * r, z + math.sin(a) * r), 0.011, "iron", 6)
    p.cyl("hub", (x, 0, z), 0.035, 0.05, "x", "iron", 16)
    p.rod("axle", (x, 0, z), (FRAME_X, 0, 0.42), 0.014, "iron")
    hw_z = TOP_Z + 0.235 * HEAD_BOOST
    hw_r = 0.07 * HEAD_BOOST
    for s, tag in ((-1, "f"), (1, "b")):
        p.rod(f"belt_{tag}", (x, s * (hw_r - 0.012), hw_z), (x, s * (r + 0.004), z), 0.006,
              "belt", 8)


def build_head(p: Parts) -> None:
    """Tête de machine noire à filets dorés, posée sur le plateau (façon Singer 27)."""
    k = HEAD_BOOST

    def at(x, y, z):
        return (HEAD_X + x * k, y * k, TOP_Z + z * k)

    def sz(*v):
        return tuple(c * k for c in v)

    p.box("bed", at(0, 0, 0.0175), sz(0.40, 0.19, 0.035), "black", 0.2)
    p.box("bed_line", at(0, -0.096, 0.018), sz(0.37, 0.004, 0.007), "gold", 0)
    p.box("pillar", at(0.14, 0.01, 0.135), sz(0.08, 0.10, 0.20), "black", 0.2)
    p.box("arm", at(0.0, 0.01, 0.228), sz(0.34, 0.085, 0.06), "black", 0.2)
    p.cyl("arm_hump", at(0.0, 0.01, 0.245), 0.043 * k, 0.30 * k, "x", "black")
    p.box("needle_head", at(-0.17, 0.0, 0.18), sz(0.075, 0.095, 0.17), "black", 0.2)
    p.box("face_plate", at(-0.2095, 0.0, 0.18), sz(0.006, 0.080, 0.14), "steel", 0)
    for i, z in enumerate((0.212, 0.250)):
        p.box(f"arm_line_{i}", at(0.0, -0.034, z), sz(0.28, 0.004, 0.006), "gold", 0)
    p.box("pillar_decal", at(0.14, -0.041, 0.13), sz(0.04, 0.004, 0.09), "gold", 0)
    p.box("head_line", at(-0.17, -0.049, 0.18), sz(0.05, 0.004, 0.006), "gold", 0)
    p.box("throat_plate", at(-0.17, -0.02, 0.036), sz(0.09, 0.07, 0.004), "steel", 0)
    p.cyl("needlebar", at(-0.17, -0.025, 0.085), 0.007 * k, 0.05 * k, "z", "steel", 12)
    p.cyl("needle", at(-0.17, -0.025, 0.055), 0.003 * k, 0.03 * k, "z", "steel", 8)
    p.box("presser", at(-0.19, -0.03, 0.08), sz(0.016, 0.016, 0.06), "steel")
    p.box("foot", at(-0.19, -0.03, 0.041), sz(0.045, 0.04, 0.009), "steel", 0)
    hx = (DRIVE_X - HEAD_X) / k
    p.cyl("handwheel", at(hx, 0.0, 0.235), 0.07 * k, 0.035 * k, "x", "black")
    p.cyl("handwheel_hub", at(hx + 0.02, 0.0, 0.235), 0.028 * k, 0.012 * k, "x", "steel", 20)
    p.cyl("spoolpin", at(0.06, 0.01, 0.30), 0.005 * k, 0.05 * k, "z", "steel", 10)
    p.cyl("spool", at(0.06, 0.01, 0.305), 0.022 * k, 0.034 * k, "z", "spool", 24)
    p.box("stitch_lever", at(0.14, -0.064, 0.09), sz(0.01, 0.02, 0.05), "steel", 0)


def build(subject, mats) -> None:
    """Operator side faces -Y = south; head needle end on the left, drive on the right."""
    p = Parts(subject, mats)
    build_cabinet(p)
    build_frame(p, -FRAME_X, "w")
    build_frame(p, FRAME_X, "e")
    build_treadle(p, subject, mats)
    build_drive(p)
    build_head(p)


def render_panel_art(scene, out: str) -> None:
    """Illustration du panneau : vue 3/4 en perspective, 384x256, fond transparent.

    Caméra dédiée ; les réglages du gabarit (caméra, résolution, échantillons) sont
    restaurés ensuite, et le sol et le guide de case sont masqués pendant le rendu.
    """
    cam = bpy.data.objects.get("MTIR_TreadlePanelCam")
    if cam is None:
        cam = bpy.data.objects.new("MTIR_TreadlePanelCam", bpy.data.cameras.new("MTIR_TreadlePanelCam"))
        scene.collection.objects.link(cam)
    cam.data.type = "PERSP"
    cam.data.lens = 70
    target = Vector((0.0, 0.0, 0.54 * SCALE))
    cam.location = target + Vector((1.45, -2.65, 1.05)).normalized() * 4.55
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    saved = (scene.camera, scene.render.resolution_x, scene.render.resolution_y,
             scene.render.filepath, scene.cycles.samples)
    hidden = [o for o in (bpy.data.objects.get("PZ_Ground"), bpy.data.objects.get("PZ_TileGuide"))
              if o is not None and not o.hide_render]
    for obj in hidden:
        obj.hide_render = True
    try:
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = 384, 256
        scene.render.film_transparent = True
        scene.cycles.samples = 128
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
    finally:
        (scene.camera, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, scene.cycles.samples) = saved
        for obj in hidden:
            obj.hide_render = False


def main() -> None:
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build/mtir_treadle_cells"
    if bpy.context.window:
        # Interactive Blender: work in a spare scene, never in the user's.
        scene = bpy.data.scenes.new("MTIR_TreadleMachine")
        bpy.context.window.scene = scene
    else:
        # Headless factory scene: safe to empty.
        scene = bpy.context.scene
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    F.register()
    scene.render.engine = "CYCLES"
    props = scene.pz_forge
    props.sheet_name = "mtir_treadle_01"
    props.output_dir = str(out)
    props.footprint_x = props.footprint_y = 1
    props.facings = "4"
    props.show_guide = False
    props.contrast_boost = 1.0
    props.toon_shading = True
    F.build_rig(bpy.context)
    scene.cycles.samples = 256
    scene.cycles.use_denoising = True
    build(bpy.data.objects[F.SUBJECT_NAME], materials())
    manifest = F.render_cells(bpy.context)
    print(f"rendered {len(manifest['cells'])} cells to {out}")
    render_panel_art(scene, str(Path(out) / "panel_art.png"))
    print(f"rendered panel art to {Path(out) / 'panel_art.png'}")


if __name__ == "__main__":
    main()
