"""Builds the lobby and the wooden floor under the whole world in the faceted low-poly style, and exports them.

Run it inside Blender, like build_rooms.py, whose helpers it borrows. It works in its own scene, saves that to its own
.blend, and leaves the file that's open untouched.

Every part in lobby_parts.txt is rebuilt with the same size, place and color, except the ones that stay real parts in
the game: anything with text or a decal on it, anything that glows, and the Hall of Fame board. The trees, pumpkins, hay
bales, corn and rugs get proper low-poly shapes instead of a straight copy.
"""

import os
import random
from math import cos, pi, radians, sin

import bpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/lowpoly"
EXPORT = ASSET_DIR + "/export/TurkeyRace_LowPolyLobby.glb"
BLEND = ASSET_DIR + "/TurkeyRace_LowPolyLobby.blend"
RENDERS = ASSET_DIR + "/renders"
SCENE = "TR_LowPolyLobby"

rooms = {"__name__": "rooms_helpers"}
rooms_source = open(ASSET_DIR + "/build_rooms.py", encoding="utf-8").read()
exec(rooms_source[: rooms_source.rindex("build()")], rooms)
Part, lathe, cbox, box, tube, ico, merge = rooms["Part"], rooms["lathe"], rooms["cbox"], rooms["box"], rooms["tube"], rooms["ico"], rooms["merge"]
make_mesh, make_palette, make_material, bounds_of = rooms["make_mesh"], rooms["make_palette"], rooms["make_material"], rooms["bounds_of"]
ROBLOX, faceted_top, add_original_part, R = rooms["ROBLOX"], rooms["faceted_top"], rooms["add_original_part"], rooms["R"]
PIECES = rooms["PIECES"]
swatches = rooms["helpers"]["swatches"]
leaf = rooms["helpers"]["leaf"]

rng = random.Random(11)
FLOOR_Y = 0.12


def shade(hex_value, factor):
    return "".join(f"{min(255, max(0, round(int(hex_value[i : i + 2], 16) * factor))):02X}" for i in (0, 2, 4))


def read_parts():
    parts = []
    with open(ASSET_DIR + "/lobby_parts.txt", encoding="utf-8") as f:
        for raw in f:
            if raw.startswith("#") or not raw.strip():
                continue
            fields = raw.split()
            numbers = [float(v) for v in fields[3:12]]
            parts.append({"group": fields[0], "name": fields[1], "shape": fields[2], "n": numbers, "color": fields[12], "flags": fields[13]})
    return parts


def lobby_parts():
    decor, features = Part(), Part()
    for p in (decor, features):
        p.m = ROBLOX.copy()
    # Low-poly stand-ins built in Blender's own axes, merged in at the end.
    organic = Part()

    for part in read_parts():
        name, shape, color, flags = part["name"], part["shape"], part["color"], part["flags"]
        x, y, z, rx, ry, rz, sx, sy, sz = part["n"]
        # These stay as real parts in the game.
        if "T" in flags or "N" in flags or name == "WinsBoard":
            continue
        # The low-poly pumpkins come with their own stems.
        if name == "Stem":
            continue
        target = decor if part["group"] in ("Decor", "Spawn") else features
        if name == "Leaves":
            ico(target, (x, y, z), sy / 2, [color, shade(color, 0.88), shade(color, 1.1)], subdiv=1, jitter=0.14, seed=int(abs(x * 7 + z * 3)))
        elif name == "Pumpkin":
            # The track pumpkin, squashed to this one's shape: about 11.7 across and 10.1 tall without its stem.
            fit = Matrix.Translation(R(x, y + sy * 0.02, z)) @ Matrix.Diagonal((sx / 11.7, sz / 11.7, sy / 10.1, 1))
            merge(organic, PIECES["Pumpkin"](), fit)
        elif name == "HayBale":
            # The track bale is about 12 long on Blender X; these run along Roblox Z, which is Blender Y.
            fit = Matrix.Translation(R(x, y, z)) @ Matrix.Rotation(pi / 2, 4, "Z") @ Matrix.Diagonal((sz / 12, sx / 7, sy / 6, 1))
            merge(organic, PIECES["HayBale"](), fit)
        elif name == "Trunk":
            base, top = V((x, y - sy / 2, z)), V((x, y + sy / 2, z))
            tube(target, [base, base.lerp(top, 0.5) + V((0.35, 0, 0.2)), top], [sx * 0.62, sx * 0.5, sx * 0.36], "6B3E1D", n=6, smooth=False)
        elif name == "CornStalk":
            # A stalk with a couple of leaves and a tassel, leaning the way the original does.
            lean = Matrix.Translation((x, y, z)) @ Matrix.Rotation(radians(ry), 4, "Y") @ Matrix.Rotation(radians(rx), 4, "X") @ Matrix.Rotation(radians(rz), 4, "Z")
            with target.xf(lean):
                tube(target, [(0, -sy / 2, 0), (0, 0, 0), (0, sy / 2, 0)], [0.42, 0.34, 0.16], color, n=4, smooth=False)
                for k, (a, h) in enumerate(((0.6, -1.5), (2.8, 1.2), (4.6, 3.4))):
                    leaf(target, (0, h, 0), (cos(a), 0.5, sin(a)), (0, 1, 0), 3.8, 1.0, shade(color, 0.92 + k * 0.05), thick=0.08, bend=-0.9, stations=3, sides=4)
                leaf(target, (0, sy / 2, 0), (0.1, 1, 0.1), (1, 0, 0), 1.6, 0.6, "C8A04A", thick=0.08, stations=3, sides=4)
        elif name.startswith("Rug"):
            box(target, (x, y - 0.02, z), (sx, sy, sz), color)
            faceted_top(target, x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2, y + sy / 2, [color, shade(color, 0.93), shade(color, 1.07)], 4)
        elif name == "Leaf":
            # Fallen leaves, lifted just clear of the floor.
            add_original_part(target, (shape, x, y + FLOOR_Y + 0.02, z, rx, ry, rz, sx, sy, sz, color))
        else:
            add_original_part(target, (shape, x, y, z, rx, ry, rz, sx, sy, sz, color))

    merge(decor, organic, ROBLOX.inverted())
    return {"Lobby_Decor": decor, "Lobby_Features": features}


def floor_parts():
    """Faceted planks over the whole world, in four quarters, since a part can't be wider than 2048 studs. The planks
    run along Z, 16 wide, like the boards in the place. Where a room or the backyard's lawn has its own floor, there's
    a gap, so nothing pokes up through it."""
    covered = (
        (-600, 600, -1340, -245),  # the backyard lawn
        (-600, 495, -245, -170),  # the lawn in front of the house
        (-900, -500, -240, 160),  # the kitchen
        (-440, 440, 210, 790),  # the dining room
    )
    colors = (("C48048", "BC7A44", "CC864E"), ("AE6C3C", "A66638", "B67242"), ("BA7642", "B2703E", "C27C48"))

    def under_floor(x0, x1, z0, z1):
        return any(a <= x0 and x1 <= b and c <= z0 and z1 <= d for a, b, c, d in covered)

    quarters = {}
    for qx, (x_low, x_high) in enumerate(((-1024, 0), (0, 1024))):
        for qz, (z_low, z_high) in enumerate(((-1078, -27), (-27, 1024))):
            p = Part()
            p.m = ROBLOX.copy()
            below = ROBLOX @ V(((x_low + x_high) / 2, FLOOR_Y - 50, (z_low + z_high) / 2))
            board = 16
            for i in range(round((x_high - x_low) / board)):
                x0 = x_low + i * board
                x1 = x0 + board
                palette = colors[(i + qx * 64) % 3]
                cells = 16
                for j in range(cells):
                    z0 = z_low + (z_high - z_low) * j / cells
                    z1 = z_low + (z_high - z_low) * (j + 1) / cells
                    if under_floor(x0, x1, z0, z1):
                        continue
                    a, b, c, d = (x0, z0), (x1, z0), (x1, z1), (x0, z1)
                    for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
                        ids = [p.add((u, FLOOR_Y, v)) for u, v in tri]
                        p.face_out(ids, rng.choice(palette), below)
            quarters[f"Lobby_Floor{qx * 2 + qz + 1}"] = p
    return quarters


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
    mat = bpy.data.materials.get("M_LowPolyLobby")
    if mat:
        bpy.data.materials.remove(mat)
    image = bpy.data.images.get("T_LowPolyLobby_Palette")
    if image:
        bpy.data.images.remove(image)


def build():
    clear()
    scene = bpy.data.scenes.new(SCENE)
    collection = bpy.data.collections.new("TR_LowPolyLobby")
    scene.collection.children.link(collection)
    parts = {}
    parts.update(lobby_parts())
    parts.update(floor_parts())

    pick = random.Random(21)
    objects, report, total = {}, [], 0
    for name, part in parts.items():
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
        report.append(f"{name}: {tris} tris, center ({-center.x:.3f}, {center.z:.3f}, {center.y:.3f}), size {size.x:.0f} x {size.z:.1f} x {size.y:.0f}")
    image = make_palette("T_LowPolyLobby_Palette")
    material = make_material(image, "M_LowPolyLobby")
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

    # Preview renders.
    data = bpy.data.lights.new("LPL_Key", "SUN")
    data.energy = 3.0
    data.angle = 0.05
    data.color = (1.0, 0.92, 0.8)
    sun = bpy.data.objects.new("LPL_Key", data)
    sun.rotation_euler = (0.84, 0, 0.56)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.get("LPL_World") or bpy.data.worlds.new("LPL_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.62, 0.78, 0.92, 1)
        background.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("LPL_Camera")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = 1.22
    cam_data.clip_end = 8000
    cam = bpy.data.objects.new("LPL_Camera", cam_data)
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
        "lobby_over": (R(70, 48, 75), R(0, 4, -5)),
        "lobby_spawn": (R(0, 9, 28), R(0, 10, -30)),
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
