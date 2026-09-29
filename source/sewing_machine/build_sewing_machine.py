"""Electric sewing machine tile (mtir_sewing_01) for My Tailor Is Rich.

Table-top object: modelled resting at the vanilla table height (Surface = 34,
i.e. 34 / 96 * 2.44949 = 0.8675 m); the game lowers it on low tables or the
floor with IsSurfaceOffset. Four facings S, E, N, W (sprites _0 to _3).

Needs pz-sprite-forge (MIT, https://github.com/Leeheejin/pz-sprite-forge).
Render (headless, or run the body through the Blender MCP in a spare scene):
    set PZ_FORGE=<path to pz-sprite-forge>
    blender -b -P source/sewing_machine/build_sewing_machine.py -- <cells-dir>
Package:
    python -m pzforge.cli build <cells-dir> --out <dist> --mod-id MTIRSewingTiles \
        --sheet mtir_sewing_01 --preset appliance --tileset-id 1 --tiledef-id 7171 \
        --prop "CustomName=Sewing Machine" --prop "GroupName=Electric" \
        --prop IsTableTop= --prop IsSurfaceOffset= --prop Surface=34 --prop ItemHeight=17 \
        --prop PickUpWeight=80 --prop Material=MetalScrap --prop Material2=Electric \
        --prop MaterialType=Metal_Light --prop ScrapSize=Small
then copy <dist>/MTIRSewingTiles/42/media/texturepacks/mtir_sewing_01.pack and
mtir_sewing_01.tiles into Contents/mods/batman_MyTailorIsRich/common/media/, and
<cells-dir>/panel_art.png to 42.21/media/textures/MTIR_SewingMachinePanel.png
(illustration of the sewing machine panel).
Depth map (B42 discards every sprite pixel outside the depth map; never borrow a
smaller vanilla tile's), with the tools of the pz-blender-assets skill
(Workshop/content/108600/.claude/skills/pz-blender-assets/scripts):
    blender -b --factory-startup -P <scripts>/build_depthmap.py -- <this script> depth.json
    python <scripts>/build_depthmap.py depth.json <mod>/common/media/texturepacks/mtir_sewing_01.pack
        mtir_sewing_01 <mod>/common/media/depthmaps/DEPTH_mtir_sewing_01.png
(common/media/tileGeometry.txt must exist for the game to load it).
Editable copy of the model: mtir_sewing_01.blend, next to this script, from
    blender -b --factory-startup -P <scripts>/save_blend.py -- <this script> mtir_sewing_01.blend mtir_sewing_01
"""
from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy

FORGE = Path(os.environ["PZ_FORGE"])
sys.path.insert(0, str(FORGE / "blender"))

import pz_sprite_forge as F  # noqa: E402

#: Top of a vanilla table (Surface = 34 in 96ths of a 2.44949 m level).
TABLE_Z = 34 / 96 * 2.44949
#: Readability boost: vanilla props are drawn larger than life.
SCALE = 1.35

PAINTS = {
    "body": (0.80, 0.76, 0.64),   # cream enamel
    "trim": (0.52, 0.30, 0.22),   # brown decorative band
    "dark": (0.16, 0.16, 0.17),   # handwheel, stitch dial
    "steel": (0.62, 0.63, 0.65),  # needle bar, presser foot, spool pin
    "spool": (0.72, 0.12, 0.10),  # red thread spool
}


def materials() -> dict:
    return {key: F.forge_material(f"mtir_{key}", "metal", paint) for key, paint in PAINTS.items()}


def build(subject, mats) -> None:
    """Front (operator side) faces -Y = south; head on the left, handwheel on the right."""
    k = SCALE

    def link(obj, mat):
        obj.data.materials.append(mats[mat])
        obj.parent = subject

    def box(name, cx, cy, cz, sx, sy, sz, mat, bevel=0.18):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx * k, cy * k, TABLE_Z + cz * k))
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = (sx * k, sy * k, sz * k)
        bpy.ops.object.transform_apply(scale=True)
        if bevel:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = min(sx, sy, sz) * k * bevel
            mod.segments = 2
        link(obj, mat)

    def cyl(name, cx, cy, cz, radius, depth, axis, mat, verts=32):
        rotation = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius * k, depth=depth * k,
                                            location=(cx * k, cy * k, TABLE_Z + cz * k),
                                            rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        link(obj, mat)

    box("bed", 0.00, 0.00, 0.030, 0.44, 0.19, 0.060, "body")
    box("pillar", 0.15, 0.01, 0.160, 0.10, 0.14, 0.210, "body")
    box("arm", 0.00, 0.01, 0.245, 0.42, 0.12, 0.080, "body")
    # La tête surplombe le plateau : l'aiguille et le pied-de-biche restent visibles dessous.
    box("head", -0.175, 0.00, 0.210, 0.09, 0.14, 0.160, "body")
    box("stripe", 0.00, -0.052, 0.250, 0.34, 0.02, 0.035, "trim", 0)
    box("stripe_e", 0.201, 0.01, 0.160, 0.02, 0.12, 0.035, "trim", 0)
    box("plate", -0.170, -0.030, 0.062, 0.09, 0.07, 0.006, "steel", 0)
    box("presser", -0.190, -0.035, 0.100, 0.018, 0.018, 0.060, "steel")
    box("foot", -0.190, -0.035, 0.070, 0.05, 0.045, 0.010, "steel", 0)
    cyl("needlebar", -0.160, -0.035, 0.105, 0.007, 0.060, "z", "steel", 12)
    cyl("needle", -0.160, -0.035, 0.078, 0.003, 0.030, "z", "steel", 8)
    cyl("handwheel", 0.215, 0.01, 0.235, 0.070, 0.040, "x", "dark")
    cyl("hub", 0.237, 0.01, 0.235, 0.030, 0.012, "x", "steel", 20)
    cyl("dial", 0.12, -0.072, 0.160, 0.034, 0.014, "y", "dark")
    cyl("spoolpin", 0.08, 0.01, 0.310, 0.005, 0.050, "z", "steel", 10)
    cyl("spool", 0.08, 0.01, 0.312, 0.024, 0.036, "z", "spool", 24)
    box("lamp", -0.175, -0.02, 0.285, 0.07, 0.10, 0.02, "body")


def render_panel_art(scene, out: str) -> None:
    """Illustration du panneau : vue 3/4 en perspective, 384x256, fond transparent.

    Caméra dédiée ; les réglages du gabarit (caméra, résolution, échantillons) sont
    restaurés ensuite, et le sol et le guide de case sont masqués pendant le rendu.
    """
    from mathutils import Vector

    cam = bpy.data.objects.get("MTIR_PanelCam")
    if cam is None:
        cam = bpy.data.objects.new("MTIR_PanelCam", bpy.data.cameras.new("MTIR_PanelCam"))
        scene.collection.objects.link(cam)
    cam.data.type = "PERSP"
    cam.data.lens = 70
    target = Vector((0.0, 0.0, TABLE_Z + 0.20))
    cam.location = Vector((0.85, -1.55, TABLE_Z + 0.75))
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
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build/mtir_sewing_cells"
    if bpy.context.window:
        # Interactive Blender: work in a spare scene, never in the user's.
        scene = bpy.data.scenes.new("MTIR_SewingMachine")
        bpy.context.window.scene = scene
    else:
        # Headless factory scene: safe to empty.
        scene = bpy.context.scene
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    F.register()
    scene.render.engine = "CYCLES"
    props = scene.pz_forge
    props.sheet_name = "mtir_sewing_01"
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
