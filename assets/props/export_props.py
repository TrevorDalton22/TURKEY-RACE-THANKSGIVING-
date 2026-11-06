"""Exports the TR_Props scene made by build_props.py: one GLB holding every piece, and a .blend of just that scene.
Run it inside Blender after build_props.py. It doesn't save or change the file that's open."""

import os

import bpy

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/props"
EXPORT = ASSET_DIR + "/export/TurkeyRace_Props.glb"
BLEND = ASSET_DIR + "/TurkeyRace_Props.blend"

scene = bpy.data.scenes["TR_Props"]
collection = bpy.data.collections["TR_Props"]

# The ring is tilted for the preview render only; the game does its own tilting.
bpy.data.objects["ItemBox_Halo_Glow"].rotation_euler = (0, 0, 0)

os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
# Show the scene in the window while exporting. Overriding the scene and view layer in the operator's context instead
# crashed Blender 5.2 in its scene update.
window = bpy.context.window
previous = window.scene
window.scene = scene
try:
    bpy.ops.export_scene.gltf(
        filepath=EXPORT,
        collection=collection.name,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_animations=False,
        export_skins=False,
        export_cameras=False,
        export_lights=False,
    )
finally:
    window.scene = previous

bpy.data.libraries.write(BLEND, {scene}, fake_user=True, compress=True)

print("meshes:", len(collection.objects))
print("glb bytes:", os.path.getsize(EXPORT))
print("blend bytes:", os.path.getsize(BLEND))
print("still open:", bpy.data.filepath)
