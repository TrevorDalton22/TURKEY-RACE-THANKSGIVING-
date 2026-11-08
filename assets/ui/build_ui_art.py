"""Builds the game's low-poly UI art in Blender: an icon sheet, two panel textures, and the shop item icons.

Run it inside Blender. It works in its own scene and removes it again, so the open file is left as it was.

  export/ui_icons.png     1024 x 1024, an 8 x 8 grid of 128 px icons on a transparent background, each faceted,
                          flat shaded and drawn with a thick dark outline like the UI's text. ui_icons.json
                          maps each icon's name to its cell.
  export/ui_panel.png     256 x 256 grey panels with cut corners, a bevel and a faint triangle facet pattern,
  export/ui_window.png    for 9-slicing. They're grey so ImageColor3 can tint them any color; SLICES has the
                          margins.
  export/items/*.png      512 x 512 icons for the game passes and developer products.

Icons are modeled with the same helpers as the props and maps (assets/props/build_props.py), rendered one at a
time, and outlined and packed here with numpy.
"""

import json
import os
import random
from math import cos, pi, radians, sin, sqrt

import bpy
import numpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets"
UI_DIR = ASSET_DIR + "/ui"
EXPORT = UI_DIR + "/export"
RENDERS = UI_DIR + "/renders"
TURKEY_TEXTURES = (ASSET_DIR + "/turkey/export", ASSET_DIR + "/turkey/textures")
SCENE = "TR_UiArt"
PREFIX = "UIA_"

helpers = {"__name__": "backyard_helpers"}
yard_source = open(ASSET_DIR + "/lowpoly/build_backyard.py", encoding="utf-8").read()
exec(yard_source[: yard_source.rindex("build()")], helpers)
helpers["ASSET_DIR"] = UI_DIR  # so make_palette writes its texture under assets/ui
Part, box, cbox, ico, lathe, tube = helpers["Part"], helpers["box"], helpers["cbox"], helpers["ico"], helpers["lathe"], helpers["tube"]
make_mesh, make_palette, make_material = helpers["make_mesh"], helpers["make_palette"], helpers["make_material"]

OUTLINE = numpy.array([0x3A, 0x1E, 0x10], dtype=numpy.float32) / 255
SLICES = {"ui_panel": 28, "ui_window": 36}

# The game's palette.
CREAM, CREAM_DARK = "F4EAD8", "E2D2B4"
GOLD, GOLD_LIGHT, GOLD_DARK = "F0AE32", "F6C24A", "D08A1E"
ORANGE, ORANGE_LIGHT, RUST = "E2782A", "EE9234", "B5532A"
CRANBERRY, CRANBERRY_DARK = "A03628", "7E2820"
GREEN, GREEN_DARK = "6FA63C", "4E8A2C"
BROWN, BROWN_DARK = "8A5A32", "5E3B22"
SLATE, SLATE_LIGHT = "42687C", "8FBEDC"
STEEL = "9DA3A9"
CHARCOAL = "2E2A2C"


# Shapes ----------------------------------------------------------------------------------------------------------------


def prism(p, points, depth, front, side):
    """A flat shape in the X-Z plane, `depth` thick along Y, its face toward -Y (the camera)."""
    n = len(points)
    fronts = [p.add((x, -depth / 2, z)) for x, z in points]
    backs = [p.add((x, depth / 2, z)) for x, z in points]
    middle = p.m @ V((sum(x for x, _ in points) / n, 0, sum(z for _, z in points) / n))
    p.face_out(fronts, front, middle + p.m.to_3x3() @ V((0, 10, 0)))
    p.face_out(backs, side, middle - p.m.to_3x3() @ V((0, 10, 0)))
    for i in range(n):
        j = (i + 1) % n
        ids = [fronts[i], fronts[j], backs[j], backs[i]]
        p.face_out(ids, side, middle)


def faceted(p, points, depth, colors, back=None):
    """A shape whose middle bulges toward the camera, so each point of its outline makes a facet: stars, feathers."""
    n = len(points)
    cx, cz = sum(x for x, _ in points) / n, sum(z for _, z in points) / n
    apex = p.add((cx, -depth, cz))
    rim = [p.add((x, 0, z)) for x, z in points]
    rear = p.add((cx, depth * 0.5, cz))
    inside = p.m @ V((cx, 0, cz))
    for i in range(n):
        j = (i + 1) % n
        p.face_out([apex, rim[i], rim[j]], colors[i % len(colors)], inside)
        p.face_out([rear, rim[j], rim[i]], back or colors[0], inside)


def feather(p, x, z, angle, length, colors, quill="D8C8A8"):
    """A feather standing up at (x, z), turned by `angle` (radians, positive leans right), facing the camera."""
    m = Matrix.Translation((x, 0, z)) @ Matrix.Rotation(-angle, 4, "Y") @ Matrix.Scale(length, 4)
    with p.xf(m):
        right = [(0.0, 1.0), (0.2, 0.78), (0.29, 0.42), (0.26, 0.05), (0.13, -0.3), (0.04, -0.42)]
        outline = right + [(-u, v) for u, v in reversed(right[1:-1])] + [(-0.04, -0.42)]
        faceted(p, outline, 0.09, colors)
        # Just behind the bulge, so the quill only shows below the vane.
        tube(p, [(0, -0.02, -0.64), (0, -0.02, -0.1)], 0.028, quill, n=4, smooth=False)


def star_points(outer, inner, count=5, turn=pi / 2):
    points = []
    for k in range(count * 2):
        r = outer if k % 2 == 0 else inner
        a = turn + k * pi / count
        points.append((cos(a) * r, sin(a) * r))
    return points


# Icons: each builds into the part at the origin, roughly 2 units across, facing -Y -----------------------------------


def icon_feather(p):
    feather(p, 0, 0, 0.35, 1.05, [ORANGE, ORANGE_LIGHT, RUST, ORANGE])


def feather_pile(p, count):
    rng = random.Random(count)
    palettes = ([ORANGE, ORANGE_LIGHT, RUST], [CRANBERRY, "CC4228", RUST], [GOLD, GOLD_LIGHT, GOLD_DARK], [RUST, "C4652F", ORANGE])
    for k in range(count):
        spread = (k - (count - 1) / 2) / max(1, count - 1)
        with p.xf(Matrix.Translation((0, k * 0.06, 0))):
            feather(p, spread * 0.9, -0.1 + abs(spread) * -0.15, spread * 1.1 + rng.uniform(-0.1, 0.1), 0.9 + rng.uniform(-0.08, 0.08), palettes[k % len(palettes)])


def icon_cart(p):
    cbox(p, (0.05, 0, 0.15), (1.5, 0.9, 0.85), GREEN, bevel=0.06)
    for x in (-0.4, 0.05, 0.5):
        box(p, (x, -0.47, 0.15), (0.07, 0.05, 0.75), GREEN_DARK)
    box(p, (0.05, -0.47, 0.15), (1.4, 0.05, 0.07), GREEN_DARK)
    tube(p, [(-0.7, -0.2, 0.55), (-0.95, -0.2, 0.95), (-1.25, -0.2, 0.95)], 0.07, SLATE, n=6, smooth=False)
    box(p, (0.05, 0, -0.38), (1.3, 0.12, 0.08), SLATE)
    for x in (-0.45, 0.55):
        lathe(p, [(0.2, -0.08), (0.2, 0.08)], CHARCOAL, n=8, smooth=False, center=(x, -0.5, -0.55), axis="Y")


def icon_ticket(p):
    cbox(p, (0, 0, 0), (1.9, 0.16, 1.05), GOLD, bevel=0.06)
    box(p, (-0.62, -0.09, 0), (0.42, 0.04, 0.95), CRANBERRY)
    for z in (-0.38, -0.19, 0, 0.19, 0.38):
        box(p, (-0.38, -0.1, z), (0.04, 0.04, 0.08), CRANBERRY_DARK)
    with p.xf(Matrix.Translation((0.3, -0.1, 0))):
        faceted(p, star_points(0.36, 0.16), 0.08, [CREAM, CREAM_DARK])


def icon_gear(p):
    lathe(p, [(0.32, -0.14), (0.66, -0.14), (0.66, 0.14), (0.32, 0.14), (0.32, -0.14)], STEEL, n=10, smooth=False, axis="Y", cap_start=False, cap_end=False)
    for k in range(8):
        a = k * pi / 4
        with p.xf(Matrix.Rotation(-a, 4, "Y")):
            cbox(p, (0, 0, 0.74), (0.3, 0.26, 0.26), STEEL, bevel=0.04)


def icon_lightning(p):
    points = [(0.0, 1.0), (0.45, 1.0), (0.05, 0.2), (0.4, 0.2), (-0.35, -1.0), (-0.1, -0.1), (-0.45, -0.1)]
    prism(p, points, 0.22, GOLD_LIGHT, GOLD_DARK)


def icon_crown(p):
    lathe(p, [(0.62, -0.3), (0.62, 0.05)], GOLD, n=10, smooth=False)
    for k in range(5):
        a = k * 2 * pi / 5 - pi / 2
        center = (cos(a) * 0.55, sin(a) * 0.55, 0)
        lathe(p, [(0.16, 0.05), (0.0, 0.55)], GOLD_LIGHT, n=4, smooth=False, center=center)
        ico(p, (center[0], center[1], 0.6), 0.08, GOLD_LIGHT, subdiv=0, jitter=0.02)
    for x, color in ((-0.3, "3F7FD0"), (0.0, CRANBERRY), (0.3, GREEN)):
        ico(p, (x, -0.6, -0.12), 0.1, color, subdiv=0, jitter=0.03)


def icon_gift(p):
    cbox(p, (0, 0, -0.1), (1.2, 1.0, 1.0), CRANBERRY, bevel=0.05)
    cbox(p, (0, 0, 0.43), (1.32, 1.1, 0.22), CRANBERRY_DARK, bevel=0.04)
    box(p, (0, -0.52, -0.1), (0.2, 0.06, 1.0), GOLD)
    box(p, (0, -0.57, 0.43), (0.22, 0.06, 0.24), GOLD)
    box(p, (0, 0, 0.55), (0.22, 1.12, 0.02), GOLD)
    for side in (-1, 1):
        ico(p, (side * 0.22, -0.1, 0.68), 0.2, GOLD_LIGHT, subdiv=0, jitter=0.05, squash=1.6)
    ico(p, (0, -0.15, 0.64), 0.1, GOLD, subdiv=0, jitter=0.02)


def icon_trophy(p):
    lathe(p, [(0.1, -0.25), (0.1, 0.05), (0.32, 0.18), (0.55, 0.6), (0.6, 0.85), (0.0, 0.85)], GOLD, n=8, smooth=False)
    for side in (-1, 1):
        tube(p, [(side * 0.5, 0, 0.7), (side * 0.85, 0, 0.62), (side * 0.75, 0, 0.3), (side * 0.32, 0, 0.22)], 0.06, GOLD_DARK, n=5, smooth=False)
    cbox(p, (0, 0, -0.33), (0.62, 0.45, 0.18), GOLD_DARK, bevel=0.03)
    cbox(p, (0, 0, -0.55), (0.9, 0.6, 0.28), BROWN, bevel=0.04)
    with p.xf(Matrix.Translation((0, -0.42, 0.48))):
        faceted(p, star_points(0.17, 0.08), 0.05, [CREAM, CREAM_DARK])


def icon_star(p):
    faceted(p, star_points(1.0, 0.45), 0.3, [GOLD_LIGHT, GOLD])


def icon_lock(p):
    tube(p, [(-0.32, 0, 0.25), (-0.32, 0, 0.62), (-0.18, 0, 0.82), (0.18, 0, 0.82), (0.32, 0, 0.62), (0.32, 0, 0.25)], 0.09, STEEL, n=6, smooth=False)
    cbox(p, (0, 0, -0.1), (1.0, 0.45, 0.8), GOLD, bevel=0.06)
    lathe(p, [(0.09, -0.24), (0.09, -0.2)], CHARCOAL, n=6, smooth=False, center=(0, 0, 0.0), axis="Y")
    box(p, (0, -0.24, -0.15), (0.07, 0.04, 0.2), CHARCOAL)


def icon_check(p):
    points = [(-0.8, 0.05), (-0.48, 0.37), (-0.18, 0.07), (0.55, 0.8), (0.87, 0.48), (-0.18, -0.57)]
    prism(p, points, 0.24, GREEN, GREEN_DARK)


def icon_clock(p):
    lathe(p, [(0.86, -0.12), (0.86, 0.12)], GOLD, n=12, smooth=False, axis="Y")
    lathe(p, [(0.72, -0.14), (0.72, -0.13)], CREAM, n=12, smooth=False, axis="Y")
    for k in range(4):
        a = k * pi / 2
        box(p, (cos(a) * 0.58, -0.17, sin(a) * 0.58), (0.09, 0.03, 0.09), CHARCOAL)
    with p.xf(Matrix.Rotation(radians(-40), 4, "Y")):
        box(p, (0, -0.19, 0.2), (0.08, 0.03, 0.46), CHARCOAL)
    with p.xf(Matrix.Rotation(radians(60), 4, "Y")):
        box(p, (0, -0.2, 0.14), (0.08, 0.03, 0.32), CRANBERRY)
    ico(p, (0, -0.21, 0), 0.07, CHARCOAL, subdiv=0, jitter=0.01)


def icon_tag(p):
    points = [(-0.9, 0.35), (0.35, 0.35), (0.85, 0.0), (0.35, -0.35), (-0.9, -0.35)]
    prism(p, points, 0.14, CRANBERRY, CRANBERRY_DARK)
    lathe(p, [(0.1, -0.09), (0.1, -0.08)], CREAM, n=6, smooth=False, center=(0.45, 0, 0), axis="Y")
    box(p, (-0.3, -0.08, 0.0), (0.7, 0.03, 0.12), CREAM)


def icon_drumstick(p):
    with p.xf(Matrix.Rotation(radians(40), 4, "Y")):
        tube(p, [(0, 0, -0.1), (0, 0, 0.45), (0, 0, 0.8)], [0.38, 0.45, 0.25], BROWN, n=7, smooth=False)
        ico(p, (0.05, -0.1, 0.35), 0.4, ["B5652F", "9C4F22", "C47A3E"], subdiv=1, jitter=0.12, squash=1.2, seed=3)
        tube(p, [(0, 0, -0.1), (0, 0, -0.75)], 0.08, CREAM, n=5, smooth=False)
        for side in (-1, 1):
            ico(p, (side * 0.09, 0, -0.82), 0.12, CREAM, subdiv=0, jitter=0.03)


def icon_pie(p):
    lathe(p, [(0.0, 0.0), (0.85, 0.0), (0.98, 0.22), (0.9, 0.3), (0.0, 0.3)], "D9A35A", n=10, smooth=False)
    lathe(p, [(0.8, 0.31), (0.0, 0.31)], ORANGE, n=10, smooth=False, cap_start=False)
    for k in range(10):
        a = k * 2 * pi / 10
        ico(p, (cos(a) * 0.88, sin(a) * 0.88, 0.3), 0.09, "C8904A", subdiv=0, jitter=0.03, seed=k)
    ico(p, (0, 0, 0.42), 0.25, CREAM, subdiv=0, jitter=0.1, squash=1.4)


def icon_butter(p):
    lathe(p, [(0.0, -0.2), (0.95, -0.2), (1.0, -0.12), (0.0, -0.12)], SLATE_LIGHT, n=10, smooth=False)
    cbox(p, (0, 0, 0.12), (1.1, 0.55, 0.45), "F6D24A", bevel=0.05)
    cbox(p, (0.25, 0, 0.36), (0.45, 0.4, 0.08), "F8E07A", bevel=0.02)


def icon_bomb(p):
    ico(p, (0, 0, -0.1), 0.7, [CHARCOAL, "3A3638", "24201F"], subdiv=1, jitter=0.05, seed=7)
    cbox(p, (0.32, 0, 0.55), (0.3, 0.3, 0.2), STEEL, bevel=0.03)
    tube(p, [(0.38, 0, 0.64), (0.5, 0, 0.85), (0.7, 0, 0.92)], 0.05, BROWN, n=4, smooth=False)
    with p.xf(Matrix.Translation((0.78, -0.05, 0.95))):
        faceted(p, star_points(0.26, 0.1, 6), 0.08, [GOLD_LIGHT, ORANGE])


def icon_potato(p):
    lathe(p, [(0.3, -0.45), (0.62, -0.35), (0.85, -0.05), (0.88, 0.1), (0.0, 0.1)], SLATE, n=10, smooth=False)
    for k, (x, y, z, r) in enumerate(((0, 0, 0.25, 0.48), (-0.35, -0.1, 0.15, 0.3), (0.35, -0.12, 0.17, 0.3), (0.05, -0.25, 0.4, 0.28))):
        ico(p, (x, y, z), r, [CREAM, "F8F0E2", CREAM_DARK], subdiv=0, jitter=0.12, squash=1.3, seed=k + 20)
    cbox(p, (0.05, -0.2, 0.62), (0.3, 0.25, 0.1), "F6D24A", bevel=0.02)


def icon_tornado(p):
    rings = [(-0.95, 0.12), (-0.6, 0.26), (-0.25, 0.42), (0.1, 0.6), (0.45, 0.8), (0.8, 0.98)]
    for k in range(len(rings) - 1):
        (h0, r0), (h1, r1) = rings[k], rings[k + 1]
        lathe(p, [(r0, h0), (r1, h1)], GREEN if k % 2 == 0 else "8AA43A", n=7, smooth=False, phase=k * 0.35, cap_start=False, cap_end=k == len(rings) - 2)
    rng = random.Random(4)
    for k in range(7):
        a = k * 2.3
        h = -0.7 + k * 0.25
        r = 0.35 + (h + 0.95) * 0.5
        ico(p, (cos(a) * r, sin(a) * r - 0.2, h), 0.11, [GOLD_LIGHT, GOLD], subdiv=0, jitter=0.1, squash=1.5, seed=k)


ICONS = [
    ("feather", icon_feather),
    ("cart", icon_cart),
    ("ticket", icon_ticket),
    ("gear", icon_gear),
    ("lightning", icon_lightning),
    ("crown", icon_crown),
    ("gift", icon_gift),
    ("trophy", icon_trophy),
    ("star", icon_star),
    ("lock", icon_lock),
    ("check", icon_check),
    ("clock", icon_clock),
    ("turkey", None),  # the real turkey, rendered from the turkey file
    ("tag", icon_tag),
    ("feathers_s", lambda p: feather_pile(p, 2)),
    ("feathers_m", lambda p: feather_pile(p, 4)),
    ("feathers_l", lambda p: feather_pile(p, 7)),
    ("drumstick", icon_drumstick),
    ("pie", icon_pie),
    ("butter", icon_butter),
    ("bomb", icon_bomb),
    ("potato", icon_potato),
    ("tornado", icon_tornado),
]
# Some icons read better from higher up.
PITCH = {"pie": 38, "butter": 30, "potato": 30, "crown": 22, "trophy": 12, "gear": 6, "clock": 6, "star": 4, "lightning": 4, "check": 4, "tag": 6, "ticket": 8}


# Scene, rendering --------------------------------------------------------------------------------------------------------


def remove_scene():
    scene = bpy.data.scenes.get(SCENE)
    if scene:
        for obj in list(scene.collection.all_objects):
            data = obj.data
            bpy.data.objects.remove(obj)
            if isinstance(data, bpy.types.Mesh) and data.users == 0 and data.name.startswith(PREFIX):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Camera) and data.users == 0:
                bpy.data.cameras.remove(data)
            elif isinstance(data, bpy.types.Light) and data.users == 0:
                bpy.data.lights.remove(data)
        bpy.data.scenes.remove(scene)
    for mat in list(bpy.data.materials):
        if mat.name.startswith(PREFIX) and mat.users == 0:
            bpy.data.materials.remove(mat)
    for image in list(bpy.data.images):
        if image.name.startswith(PREFIX) and image.users == 0:
            bpy.data.images.remove(image)
    world = bpy.data.worlds.get(PREFIX + "World")
    if world:
        bpy.data.worlds.remove(world)


def setup_scene():
    remove_scene()
    scene = bpy.data.scenes.new(SCENE)
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 24
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    for name, energy, rotation in (("Key", 3.4, (radians(48), 0, radians(-38))), ("Fill", 0.9, (radians(70), 0, radians(150)))):
        data = bpy.data.lights.new(PREFIX + name, "SUN")
        data.energy = energy
        data.angle = 0.05
        light = bpy.data.objects.new(PREFIX + name, data)
        light.rotation_euler = rotation
        scene.collection.objects.link(light)
    world = bpy.data.worlds.new(PREFIX + "World")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs[0].default_value = (0.82, 0.8, 0.84, 1)
    background.inputs[1].default_value = 0.85
    scene.world = world
    cam_data = bpy.data.cameras.new(PREFIX + "Camera")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new(PREFIX + "Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def frame(cam, objects, pitch=16, yaw=-22, fill=0.86):
    """Points the orthographic camera at the objects from a little above and to the left, fitting them in."""
    p, y = radians(pitch), radians(yaw)
    forward = V((sin(-y) * cos(p), cos(y) * cos(p), -sin(p))).normalized()
    rotation = forward.to_track_quat("-Z", "Y")
    right, up = rotation @ V((1, 0, 0)), rotation @ V((0, 1, 0))
    points = [obj.matrix_world @ V(corner) for obj in objects for corner in obj.bound_box]
    if any(obj.type == "MESH" and len(obj.data.vertices) < 4000 for obj in objects):
        points = [obj.matrix_world @ v.co for obj in objects if obj.type == "MESH" for v in obj.data.vertices]
    xs, ys = [q.dot(right) for q in points], [q.dot(up) for q in points]
    center3 = sum(points, V()) / len(points)
    width, height = max(xs) - min(xs), max(ys) - min(ys)
    offset = right * ((max(xs) + min(xs)) / 2 - center3.dot(right)) + up * ((max(ys) + min(ys)) / 2 - center3.dot(up))
    target = center3 + offset
    cam.location = target - forward * 50
    cam.rotation_euler = rotation.to_euler()
    cam.data.ortho_scale = max(width, height) / fill
    cam.data.clip_end = 200


def render(scene, path, size):
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = path
    window = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=window, scene=scene):
        bpy.ops.render.render(write_still=True, scene=scene.name)


def mesh_object(scene, name, mesh):
    obj = bpy.data.objects.new(PREFIX + name, mesh)
    scene.collection.objects.link(obj)
    return obj


def turkey_object(scene, skin):
    """The rigged turkey's mesh in its rest pose, with a skin's palette; shares the turkey file's mesh, unchanged."""
    source = bpy.data.objects["Turkey_Mesh"]
    obj = bpy.data.objects.new(PREFIX + "Turkey_" + skin, source.data)
    scene.collection.objects.link(obj)
    image_name = "T_Turkey_Color.png" if skin == "Classic" else f"T_Turkey_Skin_{skin}.png"
    path = next(f"{d}/{image_name}" for d in TURKEY_TEXTURES if os.path.exists(f"{d}/{image_name}"))
    image = bpy.data.images.load(path, check_existing=False)
    image.name = PREFIX + skin
    mat = bpy.data.materials.new(PREFIX + "Turkey_" + skin)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.7
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for slot in obj.material_slots:
        slot.link = "OBJECT"
        slot.material = mat
    return obj


# Pixels -----------------------------------------------------------------------------------------------------------------


def load_rgba(path):
    image = bpy.data.images.load(path, check_existing=False)
    w, h = image.size
    buf = numpy.empty(w * h * 4, dtype=numpy.float32)
    image.pixels.foreach_get(buf)
    bpy.data.images.remove(image)
    return buf.reshape(h, w, 4)[::-1].copy()  # top row first


def save_rgba(array, path):
    h, w, _ = array.shape
    image = bpy.data.images.new(PREFIX + "Out", w, h, alpha=True)
    image.pixels.foreach_set(numpy.ascontiguousarray(array[::-1], dtype=numpy.float32).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def dilate(alpha, radius):
    """Grows the alpha by `radius` pixels, alternating square and cross steps for a roundish outline."""
    out = alpha
    for step in range(radius):
        padded = numpy.pad(out, 1)
        shifts = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]
        if step % 2 == 0:
            shifts += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        h, w = out.shape
        out = numpy.max([padded[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w] for dx, dy in shifts], axis=0)
    return out


def outlined(rgba, radius):
    rgb, a = rgba[..., :3], rgba[..., 3]
    ring = dilate(a, radius)
    alpha = numpy.maximum(a, ring)
    color = rgb * a[..., None] + OUTLINE * (ring * (1 - a))[..., None]
    color = numpy.where(alpha[..., None] > 0, color / numpy.maximum(alpha, 1e-6)[..., None], 0)
    return numpy.dstack([color, alpha])


def half(rgba):
    """Halves the size, averaging with the alpha so edges don't go dark."""
    a = rgba[..., 3:4]
    pm = numpy.dstack([rgba[..., :3] * a, a])
    h, w, _ = pm.shape
    pm = pm.reshape(h // 2, 2, w // 2, 2, 4).mean(axis=(1, 3))
    alpha = pm[..., 3:4]
    return numpy.dstack([numpy.where(alpha > 0, pm[..., :3] / numpy.maximum(alpha, 1e-6), 0), alpha])


def over(top, bottom):
    a = top[..., 3:4]
    return numpy.dstack([top[..., :3] * a + bottom[..., :3] * (1 - a), numpy.maximum(top[..., 3], bottom[..., 3])])


def hex_rgb(value):
    return numpy.array([int(value[i : i + 2], 16) / 255 for i in (0, 2, 4)], dtype=numpy.float32)


def facets(size, cell, seed, spread):
    """A shade per triangle of a grid of squares cut corner to corner."""
    rng = numpy.random.default_rng(seed)
    count = size // cell + 2
    shades = rng.uniform(-spread, spread, (count, count, 2)).astype(numpy.float32)
    y, x = numpy.mgrid[0:size, 0:size]
    i, j = x // cell, y // cell
    upper = (x % cell) > (y % cell)
    return shades[j, i, upper.astype(int)]


def background(size, color, seed):
    """An item icon's backdrop: the color, lighter in the middle, with soft facets."""
    base = hex_rgb(color)
    y, x = numpy.mgrid[0:size, 0:size] / (size - 1) - 0.5
    radial = numpy.clip(1 - numpy.sqrt(x * x + y * y) * 1.6, 0, 1)
    shade = 0.72 + 0.45 * radial + facets(size, size // 8, seed, 0.05)
    rgb = numpy.clip(base[None, None, :] * shade[..., None], 0, 1)
    return numpy.dstack([rgb, numpy.ones((size, size), dtype=numpy.float32)])


def panel(chamfer, line, bevel, seed):
    """A grey 9-slice panel, drawn at twice the size and halved for smooth edges."""
    size = 512
    c, o, b = chamfer * 2, line * 2, bevel * 2
    y, x = numpy.mgrid[0:size, 0:size].astype(numpy.float32) + 0.5
    edges = {
        "top": y, "left": x, "bottom": size - y, "right": size - x,
        "top_left": (x + y - c) / sqrt(2), "top_right": ((size - x) + y - c) / sqrt(2),
        "bottom_left": (x + (size - y) - c) / sqrt(2), "bottom_right": ((size - x) + (size - y) - c) / sqrt(2),
    }
    stack = numpy.stack(list(edges.values()))
    distance = stack.min(axis=0)
    nearest = stack.argmin(axis=0)
    light = {"top": 1.0, "left": 0.97, "top_left": 1.0, "top_right": 0.9, "bottom_left": 0.84, "bottom": 0.7, "right": 0.76, "bottom_right": 0.7}
    bevel_shade = numpy.array([light[k] for k in edges], dtype=numpy.float32)[nearest]
    inner = 0.92 + facets(size, 64, seed, 0.03)
    value = numpy.where(distance < o, 0.16, numpy.where(distance < o + b, bevel_shade, inner))
    alpha = numpy.clip(distance + 0.5, 0, 1).astype(numpy.float32)
    rgba = numpy.dstack([value, value, value, alpha]).astype(numpy.float32)
    return half(rgba)


# Build --------------------------------------------------------------------------------------------------------------------


def build():
    os.makedirs(EXPORT + "/items", exist_ok=True)
    os.makedirs(RENDERS + "/cells", exist_ok=True)
    scene, cam = setup_scene()
    helpers["swatches"].clear()

    # Every icon's mesh first, so they share one palette texture.
    parts = {}
    for name, builder in ICONS:
        if builder:
            part = Part()
            builder(part)
            parts[name] = part
    item_parts = {
        "premium_pass": parts["ticket"],
        "xp_30m": None,
        "xp_2h": None,
        "feathers_300": parts["feathers_s"],
        "feathers_1000": parts["feathers_m"],
        "feathers_3000": parts["feathers_l"],
        "vip": parts["crown"],
        "starter_5": None,
        "starter_15": None,
    }
    # Combined pictures for the boosts and starters.
    for name, count in (("xp_30m", 1), ("xp_2h", 2)):
        part = Part()
        for k in range(count):
            with part.xf(Matrix.Translation(((k - (count - 1) / 2) * 0.75 - 0.25, -0.2 - k * 0.05, 0.1))):
                icon_lightning(part)
        with part.xf(Matrix.Translation((0.75, 0.2, -0.45)) @ Matrix.Scale(0.6, 4)):
            icon_clock(part)
        item_parts[name] = part
    for name, count in (("starter_5", 1), ("starter_15", 3)):
        part = Part()
        spots = [(0, 0, 0)] if count == 1 else [(-0.75, 0.1, -0.15), (0.75, 0.1, -0.15), (0, -0.25, 0.05)]
        for x, y, z in spots:
            with part.xf(Matrix.Translation((x, y, z)) @ Matrix.Scale(0.8 if count > 1 else 1, 4)):
                icon_gift(part)
        with part.xf(Matrix.Translation((0.05, -0.6, 1.0 if count == 1 else 0.85)) @ Matrix.Rotation(radians(12), 4, "Y") @ Matrix.Scale(0.42, 4)):
            icon_star(part)
        item_parts[name] = part
    # Meshes before the palette, which holds only the colors they use.
    meshes = {name: make_mesh(PREFIX + name, part, random.Random(len(name))) for name, part in parts.items()}
    item_meshes = {name: make_mesh(PREFIX + "item_" + name, part, random.Random(len(name))) for name, part in item_parts.items()}
    image = make_palette(PREFIX + "Palette")
    material = make_material(image, PREFIX + "Material")
    material.use_backface_culling = False
    for mesh in list(meshes.values()) + list(item_meshes.values()):
        mesh.materials.append(material)

    # Icon sheet.
    sheet = numpy.zeros((1024, 1024, 4), dtype=numpy.float32)
    cells = {}
    for index, (name, _) in enumerate(ICONS):
        if name == "turkey":
            obj = turkey_object(scene, "Classic")
            frame(cam, [obj], pitch=10, yaw=-32, fill=0.92)
        else:
            obj = mesh_object(scene, name, meshes[name])
            frame(cam, [obj], pitch=PITCH.get(name, 16))
        path = f"{RENDERS}/cells/{name}.png"
        render(scene, path, 256)
        bpy.data.objects.remove(obj)
        icon = half(outlined(load_rgba(path), 7))
        cx, cy = index % 8, index // 8
        sheet[cy * 128 : (cy + 1) * 128, cx * 128 : (cx + 1) * 128] = icon
        cells[name] = {"x": cx, "y": cy}
    save_rgba(sheet, EXPORT + "/ui_icons.png")
    with open(EXPORT + "/ui_icons.json", "w", encoding="utf-8") as f:
        json.dump({"cell": 128, "icons": cells}, f, indent=1)

    # Item icons.
    backgrounds = {
        "premium_pass": "7A44B8", "skin_rainbow": "E89A1C", "skin_galaxy": "D8406E", "skin_diamond": "D8406E",
        "xp_30m": "3F88D8", "xp_2h": "3F88D8", "feathers_300": "D86A22", "feathers_1000": "D86A22",
        "feathers_3000": "D86A22", "vip": "8E2A22", "starter_5": "4E8A2C", "starter_15": "4E8A2C",
    }
    skins = {"skin_rainbow": "Rainbow", "skin_galaxy": "Galaxy", "skin_diamond": "Diamond"}
    for seed, (name, color) in enumerate(backgrounds.items()):
        if name in skins:
            obj = turkey_object(scene, skins[name])
            frame(cam, [obj], pitch=10, yaw=-32, fill=0.82)
        else:
            obj = mesh_object(scene, name, item_meshes[name])
            frame(cam, [obj], pitch=PITCH.get(name, 16), fill=0.74)
        path = f"{RENDERS}/cells/item_{name}.png"
        render(scene, path, 512)
        bpy.data.objects.remove(obj)
        picture = over(outlined(load_rgba(path), 12), background(512, color, seed))
        save_rgba(picture, f"{EXPORT}/items/{name}.png")

    # Panels.
    save_rgba(panel(22, 4, 6, 1), EXPORT + "/ui_panel.png")
    save_rgba(panel(30, 5, 9, 2), EXPORT + "/ui_window.png")

    # A preview: the sheet on a mid backdrop, and the panels tinted a few ways.
    preview = numpy.ones((1024 + 288, 1024, 4), dtype=numpy.float32)
    preview[..., :3] = hex_rgb("6A4A36")
    preview[:1024] = over(sheet, preview[:1024])
    panel_img = load_rgba(EXPORT + "/ui_panel.png")
    window_img = load_rgba(EXPORT + "/ui_window.png")
    for k, (img, tint) in enumerate(((panel_img, CREAM), (panel_img, ORANGE), (panel_img, GREEN), (window_img, "6A3A22"))):
        tinted = img.copy()
        tinted[..., :3] *= hex_rgb(tint)
        x0 = 16 + k * 252
        preview[1040 : 1040 + 256, x0 : x0 + 236] = over(tinted[:, 10:246], preview[1040 : 1040 + 256, x0 : x0 + 236])
    save_rgba(preview, RENDERS + "/preview_ui.png")

    remove_scene()
    print("icons:", len(cells), "items:", len(backgrounds), "swatches:", len(helpers["swatches"]))
    print("still open:", bpy.data.filepath, "dirty:", bpy.data.is_dirty, "scenes:", [s.name for s in bpy.data.scenes])


build()
