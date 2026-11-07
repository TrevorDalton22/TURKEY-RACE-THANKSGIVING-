"""Builds the autumn forest around the lobby, so there's no empty floor or horizon in view, and exports it.

Run it inside Blender, like build_lobby.py, whose helpers it borrows. It works in its own scene, saves that to its own
.blend, and leaves the file that's open untouched.

Three rings of trees, getting bigger and simpler further out: detailed trees with bushes under them close to the lobby,
larger ones across the rest of the world's floor, and a wall of very large trees on the horizon. A leafy forest floor
covers the planks around them. Everything stays clear of the lobby, the backyard and house, both rooms and the
neighbors' houses. Each ring is split into eight slices, so Roblox only draws the slices in view.
"""

import os
import random
from math import atan2, cos, pi, sin, sqrt

import bpy
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/lowpoly"
EXPORT = ASSET_DIR + "/export/TurkeyRace_LowPolyForest.glb"
BLEND = ASSET_DIR + "/TurkeyRace_LowPolyForest.blend"
RENDERS = ASSET_DIR + "/renders"
SCENE = "TR_LowPolyForest"

rooms = {"__name__": "rooms_helpers"}
rooms_source = open(ASSET_DIR + "/build_rooms.py", encoding="utf-8").read()
exec(rooms_source[: rooms_source.rindex("build()")], rooms)
Part, lathe, tube, ico, R = rooms["Part"], rooms["lathe"], rooms["tube"], rooms["ico"], rooms["R"]
make_mesh, make_palette, make_material, bounds_of = rooms["make_mesh"], rooms["make_palette"], rooms["make_material"], rooms["bounds_of"]
swatches = rooms["helpers"]["swatches"]

# Roblox coordinates (x, z) throughout, converted with R() where geometry is made.
LOBBY = (0, -5)
LOBBY_CLEAR = (-74, 74, -70, 60)  # the lobby and a little room around its fence
KEEP_OUT = (
    (-525, 505, -1025, -160),  # the backyard, its house and front lawn
    (-905, -430, -245, 165),  # the kitchen, with the oven sticking out of its east wall
    (-445, 445, 205, 795),  # the dining room
    (-525, -145, -1345, -1115),  # the neighbors' houses
    (155, 525, -1355, -1115),
)

PALETTES = (
    ["CC4228", "DD5A2C", "B8351F"],  # red
    ["E2782A", "EE9234", "D2641E"],  # orange
    ["F0AE32", "F6C24A", "E09A24"],  # gold
    ["B5532A", "C4652F", "A2461F"],  # rust
    ["8AA43A", "9CB244", "7A9432"],  # still a little green
)
WEIGHTS = (4, 5, 4, 3, 1)
PINE = ["2F5E3A", "3A6B44", "27523A"]
BARK = ("5E3B22", "6B4428", "54341E")

rng = random.Random(31)


def inside(box, x, z, margin):
    x0, x1, z0, z1 = box
    return x0 - margin < x < x1 + margin and z0 - margin < z < z1 + margin


def blocked(x, z, margin):
    return inside(LOBBY_CLEAR, x, z, margin) or any(inside(box, x, z, margin) for box in KEEP_OUT)


def distance(x, z):
    return sqrt((x - LOBBY[0]) ** 2 + (z - LOBBY[1]) ** 2)


def sector(x, z):
    angle = atan2(z - LOBBY[1], x - LOBBY[0])
    return int((angle + pi) / (2 * pi) * 8) % 8


def spots(low, high, spacing, square=None):
    """Roughly even spots, jittered, at low <= distance < high from the lobby."""
    found = []
    steps = int(high // spacing) + 1
    for i in range(-steps, steps + 1):
        for j in range(-steps, steps + 1):
            x = LOBBY[0] + i * spacing + rng.uniform(-0.45, 0.45) * spacing
            z = LOBBY[1] + j * spacing + rng.uniform(-0.45, 0.45) * spacing
            d = distance(x, z)
            if low <= d < high and (square is None or (abs(x) < square and abs(z) < square)):
                found.append((x, z))
    return found


def fall_tree(p, x, z, height, radius, subdiv, blobs):
    base = R(x, 0, z)
    lean = V((rng.uniform(-1, 1) * radius * 0.08, rng.uniform(-1, 1) * radius * 0.08, 0))
    top = base + V((0, 0, height * 0.62)) + lean
    tube(p, [base, base.lerp(top, 0.5) + V((radius * 0.05, 0, 0)), top], [radius * 0.17, radius * 0.12, radius * 0.08], rng.choice(BARK), n=5, smooth=False)
    colors = rng.choices(PALETTES, WEIGHTS)[0]
    crown = top + V((0, 0, radius * 0.6))
    seed = rng.randrange(1 << 20)
    ico(p, crown, radius, colors, subdiv=subdiv, jitter=0.14, squash=0.9, seed=seed)
    for k in range(blobs):
        a = rng.uniform(0, 2 * pi)
        offset = V((cos(a) * radius * 0.7, sin(a) * radius * 0.7, rng.uniform(-radius * 0.3, radius * 0.2)))
        # The smaller clumps are always simple; only the main crown gets the extra detail.
        ico(p, crown + offset, radius * rng.uniform(0.55, 0.75), colors, subdiv=0, jitter=0.15, seed=seed + k + 1)


def pine(p, x, z, height, radius):
    base = R(x, 0, z)
    tube(p, [base, base + V((0, 0, height * 0.25))], radius * 0.12, rng.choice(BARK), n=5, smooth=False)
    tiers = 3
    for t in range(tiers):
        low = height * (0.18 + t * 0.24)
        lathe(p, [(radius * (1 - t * 0.24), low), (0, low + height * 0.42)], rng.choice(PINE), n=6, smooth=False, center=base)


def bush(p, x, z, radius):
    colors = rng.choices(PALETTES, WEIGHTS)[0]
    ico(p, R(x, radius * 0.45, z), radius, colors, subdiv=0, jitter=0.22, squash=0.7, seed=rng.randrange(1 << 20))


def forest_parts():
    parts = {}

    def part(name):
        if name not in parts:
            parts[name] = Part()
        return parts[name]

    # Close in: detailed trees, a few pines among them.
    for x, z in spots(74, 280, 26):
        radius = rng.uniform(11, 17)
        if blocked(x, z, radius):
            continue
        p = part(f"Forest_Near{sector(x, z) + 1}")
        if rng.random() < 0.13:
            pine(p, x, z, rng.uniform(38, 58), radius * 0.75)
        else:
            fall_tree(p, x, z, rng.uniform(26, 44), radius, 1, 2)
    # Bushes along the inside edge of the trees, so the gaps between trunks are filled at eye level.
    for x, z in spots(72, 125, 10):
        radius = rng.uniform(4, 7)
        if not blocked(x, z, radius):
            bush(part("Forest_Bushes"), x, z, radius)
    # Across the rest of the world's floor: bigger, simpler trees.
    for x, z in spots(280, 1100, 72, square=1015):
        radius = rng.uniform(24, 40)
        if blocked(x, z, radius):
            continue
        p = part(f"Forest_Mid{sector(x, z) + 1}")
        if rng.random() < 0.12:
            pine(p, x, z, rng.uniform(90, 140), radius * 0.8)
        else:
            fall_tree(p, x, z, rng.uniform(60, 110), radius, 0, 3)
    # The horizon: two staggered rows of very big trees just past the floor's edge, all the way round.
    for row, ring in enumerate((1120, 1260)):
        count = int(2 * pi * ring / 95)
        for k in range(count):
            a = (k + row * 0.5) / count * 2 * pi + rng.uniform(-0.01, 0.01)
            x, z = LOBBY[0] + cos(a) * ring, LOBBY[1] + sin(a) * ring
            radius = rng.uniform(65, 100)
            if any(inside(box, x, z, radius * 0.5) for box in KEEP_OUT):
                continue
            fall_tree(part(f"Forest_Far{sector(x, z) + 1}"), x, z, rng.uniform(200, 320), radius, 0, 3)

    # The forest floor, in four quarters, with holes for the lobby and the buildings, which have their own floors.
    def floor_height(x, z):
        return 0.4 + 0.35 * (1 + sin(x * 0.05 + 1) * cos(z * 0.043))

    ground = ("6E6A2E", "7C7434", "8A6A30", "9A5A2A", "5E6230", "84702E")
    cell = 48
    for qx, (x_low, x_high) in enumerate(((-1023, 0), (0, 1023))):
        for qz, (z_low, z_high) in enumerate(((-1023, 0), (0, 1023))):
            p = part(f"Forest_Ground{qx * 2 + qz + 1}")
            below = R((x_low + x_high) / 2, -50, (z_low + z_high) / 2)
            columns, rows = round((x_high - x_low) / cell), round((z_high - z_low) / cell)
            for i in range(columns):
                for j in range(rows):
                    x0 = x_low + (x_high - x_low) * i / columns
                    x1 = x_low + (x_high - x_low) * (i + 1) / columns
                    z0 = z_low + (z_high - z_low) * j / rows
                    z1 = z_low + (z_high - z_low) * (j + 1) / rows
                    # Skip any cell touching the lobby or a building.
                    touches = False
                    for bx0, bx1, bz0, bz1 in (LOBBY_CLEAR,) + KEEP_OUT:
                        if x1 > bx0 and x0 < bx1 and z1 > bz0 and z0 < bz1:
                            touches = True
                            break
                    if touches:
                        continue
                    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
                    a, b, c, d = corners
                    for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
                        ids = [p.add(R(u, floor_height(u, v), v)) for u, v in tri]
                        p.face_out(ids, rng.choice(ground), below)
    return parts


def clear():
    scene = bpy.data.scenes.get(SCENE)
    if scene:
        for obj in list(scene.collection.all_objects):
            data = obj.data
            bpy.data.objects.remove(obj)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)
        for coll in list(scene.collection.children_recursive):
            bpy.data.collections.remove(coll)
        bpy.data.scenes.remove(scene)
    mat = bpy.data.materials.get("M_LowPolyForest")
    if mat:
        bpy.data.materials.remove(mat)
    image = bpy.data.images.get("T_LowPolyForest_Palette")
    if image:
        bpy.data.images.remove(image)


def build():
    clear()
    scene = bpy.data.scenes.new(SCENE)
    collection = bpy.data.collections.new("TR_LowPolyForest")
    scene.collection.children.link(collection)
    parts = forest_parts()

    pick = random.Random(21)
    objects, report, total = {}, [], 0
    for name in sorted(parts):
        part = parts[name]
        obj = bpy.data.objects.new(name, make_mesh(name, part, pick))
        collection.objects.link(obj)
        objects[name] = obj
        tris = sum(len(ids) - 2 for ids, _, _ in part.faces)
        total += tris
        low, high = bounds_of(part)
        size = high - low
        assert tris < 20000, f"{name} has {tris} triangles, over Roblox's limit for a mesh"
        assert max(size.x, size.y, size.z) < 2048, f"{name} is too big for one part"
        center = (low + high) / 2
        report.append(f"{name}: {tris} tris, center ({-center.x:.3f}, {center.z:.3f}, {center.y:.3f}), size {size.x:.0f} x {size.z:.0f} x {size.y:.0f}")
    image = make_palette("T_LowPolyForest_Palette")
    material = make_material(image, "M_LowPolyForest")
    for obj in objects.values():
        obj.data.materials.append(material)
    print("\n".join(report))
    print(f"meshes: {len(objects)}, total tris: {total}, swatches: {len(swatches)}")

    os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
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
    print("glb KB:", os.path.getsize(EXPORT) // 1024, "blend KB:", os.path.getsize(BLEND) // 1024)

    # Preview from the lobby, looking each way. The buildings and the lobby itself aren't in this scene.
    data = bpy.data.lights.new("LPF_Key", "SUN")
    data.energy = 3.0
    data.angle = 0.05
    data.color = (1.0, 0.92, 0.8)
    sun = bpy.data.objects.new("LPF_Key", data)
    sun.rotation_euler = (0.84, 0, 0.56)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.get("LPF_World") or bpy.data.worlds.new("LPF_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.62, 0.78, 0.92, 1)
        background.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("LPF_Camera")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = 1.22
    cam_data.clip_end = 8000
    cam = bpy.data.objects.new("LPF_Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 638
    scene.render.image_settings.file_format = "PNG"
    os.makedirs(RENDERS, exist_ok=True)
    shots = {
        "forest_east": (R(0, 22, -5), R(200, 20, -5)),
        "forest_over": (R(-150, 260, 320), R(200, 0, -180)),
    }
    for name, (eye, target) in shots.items():
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{RENDERS}/{name}.png"
        with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], scene=scene):
            bpy.ops.render.render(write_still=True, scene=SCENE)
    clear()
    print("still open:", bpy.data.filepath, "dirty:", bpy.data.is_dirty, "scenes:", [s.name for s in bpy.data.scenes])


build()
