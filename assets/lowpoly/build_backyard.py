"""Builds Pumpkin Patch Panic's backyard in a faceted low-poly style, plus the low-poly chef, and exports them.

Run it inside Blender. It works in its own scene, TR_LowPolyYard, saves that scene to its own .blend, and leaves the
file that's open untouched. One Blender unit is one stud, and everything is modeled where it goes in the map:
Roblox (x, y, z) is Blender (-x, z, y). The track surface and fence lines match the solid parts in the place exactly,
because those stay as the collision. Everything is flat shaded, and a palette image holds a few shades of each color.
"""

import os
import random
from math import cos, pi, sin

import bpy
import numpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/lowpoly"
EXPORT = ASSET_DIR + "/export/TurkeyRace_LowPolyYard.glb"
BLEND = ASSET_DIR + "/TurkeyRace_LowPolyYard.blend"
SCENE = "TR_LowPolyYard"

source = open("C:/Users/trevo/Projects/turkey-race/assets/props/build_props.py", encoding="utf-8").read()
kit = {"__name__": "props_toolkit"}
exec(source[: source.rindex("build()")], kit)
Part, lathe, cbox, box, tube, leaf = kit["Part"], kit["lathe"], kit["cbox"], kit["box"], kit["tube"], kit["leaf"]
PROP_COLORS = kit["PALETTE"]

SHADES = (0.94, 1.0, 1.06)
SWATCHES_ACROSS = 32
TEXTURE_SIZE = 1024
SHOULDER = V((-14.25, 0, 37.5))  # where the throwing arm joins, from the chef's feet


def R(x, y, z):
    """Roblox coordinates to Blender's."""
    return V((-x, z, y))


# Palette ---------------------------------------------------------------------------------------------------------------

swatches = {}


def swatch_for(color, shade):
    value = PROP_COLORS[color][0] if color in PROP_COLORS else color
    key = (value, shade)
    if key not in swatches:
        swatches[key] = len(swatches)
        assert len(swatches) <= SWATCHES_ACROSS**2, "too many colors for the palette"
    return swatches[key]


def swatch_uv(index):
    return ((index % SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS, (index // SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS)


def make_palette(name="T_LowPolyYard_Palette"):
    os.makedirs(ASSET_DIR + "/textures", exist_ok=True)
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    cell = TEXTURE_SIZE // SWATCHES_ACROSS
    pixels = numpy.ones((TEXTURE_SIZE, TEXTURE_SIZE, 4), dtype=numpy.float32)
    pixels[:, :, :3] = 0.5
    for (value, shade), index in swatches.items():
        rgb = [min(1.0, int(value[i : i + 2], 16) / 255 * shade) for i in (0, 2, 4)]
        x, y = index % SWATCHES_ACROSS * cell, index // SWATCHES_ACROSS * cell
        pixels[y : y + cell, x : x + cell, :3] = rgb
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = f"{ASSET_DIR}/textures/{name}.png"
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def make_material(image, name="M_LowPolyYard"):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# Shapes -----------------------------------------------------------------------------------------------------------------

ICO_T = (1 + 5**0.5) / 2
ICO_V = [(-1, ICO_T, 0), (1, ICO_T, 0), (-1, -ICO_T, 0), (1, -ICO_T, 0), (0, -1, ICO_T), (0, 1, ICO_T), (0, -1, -ICO_T), (0, 1, -ICO_T), (ICO_T, 0, -1), (ICO_T, 0, 1), (-ICO_T, 0, -1), (-ICO_T, 0, 1)]
ICO_F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]


def ico(part, center, r, colors, subdiv=1, jitter=0.1, squash=1.0, seed=1):
    """A chunky faceted lump, for foliage, rocks, heads and clouds. colors is one swatch or a list to pick from."""
    rng = random.Random(seed)
    verts = [V(v).normalized() for v in ICO_V]
    faces = list(ICO_F)
    for _ in range(subdiv):
        cache = {}
        new_faces = []

        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                verts.append((verts[a] + verts[b]).normalized())
                cache[key] = len(verts) - 1
            return cache[key]

        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            new_faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = new_faces
    center = V(center)
    ids = []
    for v in verts:
        f = 1 + rng.uniform(-jitter, jitter)
        ids.append(part.add(center + V((v.x * r * f, v.y * r * f, v.z * r * f * squash))))
    world = part.m @ center
    choices = [colors] if isinstance(colors, str) else colors
    for a, b, c in faces:
        part.face_out([ids[a], ids[b], ids[c]], rng.choice(choices), world)


def lines(low, high, step, extra=()):
    """Evenly spaced grid lines from low to high, with some exact ones added where the surface has to break."""
    count = max(1, round((high - low) / step))
    values = {round(low + (high - low) * k / count, 3) for k in range(count + 1)}
    values.update(round(v, 3) for v in extra)
    return sorted(v for v in values if low <= v <= high)


def sheet(part, xs, ys, height, color):
    """A triangulated sheet facing up, over a grid, with each triangle its own swatch. xs and ys must ascend."""
    ids = {}
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            ids[(i, j)] = part.add((x, y, height(x, y)))
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            a, b, c, d = ids[(i, j)], ids[(i + 1, j)], ids[(i + 1, j + 1)], ids[(i, j + 1)]
            for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
                center = part.center(tri)
                part.face(tri, color(center.x, center.y))


def gable_roof(p, x0, x1, y0, y1, z0, z1, colors, cols, rows, seed=1):
    """A roof with its ridge along X, in shingle patches, closed at both ends by the house walls under it."""
    rng = random.Random(seed)
    mid = (y0 + y1) / 2
    center = V(((x0 + x1) / 2, mid, z0 - 40))
    for side_y in (y0, y1):
        for i in range(cols):
            for j in range(rows):
                xa, xb = x0 + (x1 - x0) * i / cols, x0 + (x1 - x0) * (i + 1) / cols
                ta, tb = j / rows, (j + 1) / rows
                ya, yb = side_y + (mid - side_y) * ta, side_y + (mid - side_y) * tb
                za, zb = z0 + (z1 - z0) * ta, z0 + (z1 - z0) * tb
                ids = [p.add((xa, ya, za)), p.add((xb, ya, za)), p.add((xb, yb, zb)), p.add((xa, yb, zb))]
                p.face_out(ids, rng.choice(colors), center)
    for x in (x0, x1):
        ids = [p.add((x, y0, z0)), p.add((x, y1, z0)), p.add((x, mid, z1))]
        p.face_out(ids, colors[0], center)


def tree(trunks, leaves, x, y, height, seed):
    rng = random.Random(seed)
    tube(trunks, [(x, y, 0), (x + 4, y, height * 0.5), (x + 2, y + 3, height)], [24, 17, 11], "6B4A2F", n=6, smooth=False)
    colors = rng.choice((["E2782A", "EE9234", "D2641E"], ["CC4228", "DD5A2C", "B8351F"], ["F0AE32", "F6C24A", "E09A24"], ["D97F28", "EBA136", "C76A1E"]))
    ico(leaves, (x + 2, y + 3, height + 42), 92, colors, subdiv=1, jitter=0.13, seed=seed)
    for k in range(5):
        a = k * 2 * pi / 5 + rng.random()
        ico(leaves, (x + cos(a) * 72, y + sin(a) * 72, height + rng.uniform(-12, 40)), rng.uniform(46, 66), colors, subdiv=1, jitter=0.14, seed=seed * 10 + k)


def stalk(part, x, y, base, height, rng):
    dx, dy = rng.uniform(-1.8, 1.8), rng.uniform(-1.8, 1.8)
    green = rng.choice(("6FA63C", "7EB245", "639A36"))
    tube(part, [(x, y, base), (x + dx * 0.5, y + dy * 0.5, base + height * 0.55), (x + dx, y + dy, base + height)], [1.1, 0.85, 0.3], green, n=4, smooth=False)
    for k in range(3):
        a = rng.uniform(0, 2 * pi)
        at = base + height * (0.3 + k * 0.22)
        leaf(part, (x, y, at), (cos(a), sin(a), 0.45), (0, 0, 1), 9, 3.6, rng.choice(("86B84A", "9CC455")), thick=0.14, bend=-2.5, stations=3, sides=4)
    if rng.random() < 0.3:
        ico(part, (x + 1.2, y, base + height * 0.5), 1.5, "EBC440", subdiv=0, jitter=0.05, squash=2.0, seed=int(x * 7 + y))
    leaf(part, (x + dx, y + dy, base + height), (0.1, 0.1, 1), (1, 0, 0), 4, 1.3, "E8D27A", thick=0.1, stations=3, sides=3)


def sunflower(part, x, y, height, seed):
    rng = random.Random(seed)
    tube(part, [(x, y, 0), (x + 1, y, height * 0.6), (x, y, height)], [1.7, 1.3, 1.0], "5F9A3C", n=5, smooth=False)
    for sign in (-1, 1):
        leaf(part, (x, y, height * 0.5), (sign, 0.2, 0.35), (0, 0, 1), 15, 7, "6FA84A", thick=0.2, bend=-3, stations=3, sides=3)
    head = V((x, y, height))
    facing = (V((15, -570, height)) - head).normalized()
    with part.xf(Matrix.Translation(head) @ facing.to_track_quat("Z", "Y").to_matrix().to_4x4()):
        count = 10
        for k in range(count):
            a = k * 2 * pi / count
            leaf(part, (cos(a) * 5, sin(a) * 5, 0), (cos(a), sin(a), 0.1), (0, 0, 1), 11, 6.2, rng.choice(("FFD22E", "FFC61E", "FFDF4C")), thick=0.5, stations=3, sides=3)
        lathe(part, [(0, -1), (7.6, -0.6), (7.2, 0.8), (0, 1.5)], "6E4220", n=8, smooth=False)


def house_window(p, x, z, y, out):
    """A window on a wall at `y`, with `out` (+1 or -1) the way the wall faces."""
    box(p, (x, y + out, z), (76, 2, 96), "F6F6F0")
    box(p, (x, y + out * 2.3, z), (64, 0.6, 84), "8FBEDC")
    box(p, (x, y + out * 2.8, z), (64, 1, 3), "F6F6F0")
    box(p, (x, y + out * 2.8, z), (3, 1, 84), "F6F6F0")
    cbox(p, (x, y + out * 3.5, z - 49), (86, 7, 4), "F6F6F0", bevel=0.5)
    for side in (-1, 1):
        box(p, (x + side * 49, y + out, z), (19, 1.6, 96), "42687C")


# The chef ----------------------------------------------------------------------------------------------------------------


def chef_body():
    """Feet on the origin, front toward -Y, without the throwing arm. Roblox's +X is Blender's -X, so his throwing
    arm's shoulder is at -X here and his frying pan arm at +X."""
    p = Part()
    with p.xf(Matrix.Scale(1.5, 4)):
        for x in (-3.6, 3.6):
            cbox(p, (x, -0.8, 1.2), (5.4, 7.6, 2.4), "1E1E22", bevel=0.5)
            lathe(p, [(2.5, 2.4), (2.3, 12)], "4A4C55", n=6, smooth=False, center=(x, 0, 0), cap_start=False, cap_end=False)
        lathe(p, [(0, 9), (7.4, 9.6), (9.2, 14), (9.4, 22), (7.6, 30), (5.0, 33)], "F4F4F0", n=8, smooth=False, cap_end=False)
        cbox(p, (0, -8.4, 16), (11, 1.0, 13), "E4DFD2", bevel=0.2)
        box(p, (0, -8.5, 22.6), (13, 1.2, 1), "CD2F2F")
        for x in (-2.4, 2.4):
            for z in (24, 27, 30):
                ico(p, (x, -7.8 + (z - 24) * 0.3, z), 0.7, "22222A", subdiv=0, jitter=0.02)
        lathe(p, [(5.3, 31.4), (5.6, 33.2), (4.8, 34.5)], "CD2F2F", n=8, smooth=False, cap_start=False, cap_end=False)
        ico(p, (0, 0, 39.5), 6.8, "FFCDA8", subdiv=1, jitter=0.03)
        ico(p, (0, -6.4, 38.8), 1.8, "F2AE90", subdiv=0, jitter=0.03)
        for side in (-1, 1):
            ico(p, (side * 2.6, -5.5, 41), 1.7, "FAFAF5", subdiv=0, jitter=0.02)
            ico(p, (side * 2.2, -6.9, 41), 0.8, "1E1E22", subdiv=0, jitter=0.02)
            # Brows slope down toward the nose, and the moustache curls the other way.
            with p.xf(Matrix.Translation((side * 2.7, -6, 43.2)) @ Matrix.Rotation(side * 0.42, 4, "Y")):
                box(p, (0, 0, 0), (4.6, 1, 1.1), "5C3518")
            with p.xf(Matrix.Translation((side * 2.7, -6.3, 36.9)) @ Matrix.Rotation(side * -0.32, 4, "Y")):
                box(p, (0, 0, 0), (5, 1.3, 1.5), "5C3518")
            ico(p, (side * 6.9, 0, 39.3), 1.6, "FFCDA8", subdiv=0, jitter=0.03)
        lathe(p, [(6.2, 44), (6.4, 47.5), (7.8, 51.5)], "F4F4F0", n=8, smooth=False, cap_start=False, cap_end=False)
        ico(p, (0, 0, 54.5), 8.2, "FAFAF6", subdiv=1, jitter=0.1, seed=2)
        # The arm that isn't throwing, out to the side, holding a frying pan.
        ico(p, (9.5, 0, 26), 3.2, "F4F4F0", subdiv=0, jitter=0.03)
        tube(p, [(9.5, 0, 26), (13, -2, 21), (15, -6, 17)], [3.1, 2.7, 2.4], "F4F4F0", n=6, smooth=False)
        ico(p, (15, -6.5, 16.5), 2.5, "FFCDA8", subdiv=0, jitter=0.03)
        box(p, (15, -11.5, 17), (1.4, 8, 1.4), "26262B")
        lathe(p, [(0, 16), (6, 16), (6.8, 17.2), (5.8, 17.2), (0, 16.5)], lambda c, i, j: "5A6068" if i >= 2 else "26262B", n=10, smooth=False, center=(15, -20.5, 0))
    return p


def chef_arm():
    """Shoulder on the origin, hanging straight down; the game swings it."""
    p = Part()
    with p.xf(Matrix.Scale(1.5, 4)):
        ico(p, (0, 0, 0), 3.1, "F4F4F0", subdiv=0, jitter=0.03)
        lathe(p, [(3.0, -1), (2.5, -12)], "F4F4F0", n=6, smooth=False, cap_start=False, cap_end=False)
        lathe(p, [(2.8, -11.6), (2.8, -12.6)], "E4DFD2", n=6, smooth=False)
        ico(p, (0, 0, -14.4), 2.5, "FFCDA8", subdiv=0, jitter=0.03)
    return p


# The yard -----------------------------------------------------------------------------------------------------------------


def lawn_parts():
    rng = random.Random(3)

    def height(x, y):
        return 2.4 * (1 + sin(x * 0.031 + 1) * cos(y * 0.027)) + 0.7 * sin(x * 0.11 + y * 0.09)

    def color(x, y):
        stripe = int((x + 2000) // 100) % 2 == 0
        return rng.choice(("7EBB50", "86C256", "78B54A") if stripe else ("6BA843", "72AF48", "639F3D"))

    # Stops short of the kitchen, whose walls come down to z = -240 at x below -500.
    back, front = Part(), Part()
    sheet(back, lines(-600, 600, 40), lines(-1340, -245, 40), height, color)
    sheet(front, lines(-600, 495, 40), lines(-245, -170, 37.5), height, color)
    return {"Lawn": back, "LawnFront": front}


def far_parts():
    """Hills and clouds. Each hill is its own mesh, since a single part can't be wider than 2048 studs."""
    parts = {}
    hills = ((-1400, -1900, 620, "9CB88A"), (-400, -2300, 760, "A8C094"), (600, -2100, 700, "9EB98C"), (1500, -1500, 660, "A6BE92"), (-1900, -900, 560, "A2BC8E"), (1900, -700, 520, "ACC498"))
    for k, (x, y, r, c) in enumerate(hills):
        hill = Part()
        ico(hill, (x, y, -120), r, [c, c, "93B083"], subdiv=2, jitter=0.05, squash=0.5, seed=int(r))
        parts[f"Hill{k + 1}"] = hill
    clouds = Part()
    for x, y, z, r in ((-500, -1500, 620, 70), (-200, -1600, 700, 90), (300, -1450, 660, 80), (800, -1300, 600, 70), (-800, -1100, 680, 85)):
        for k in range(3):
            ico(clouds, (x + k * r * 0.9, y, z + (k % 2) * 16), r * (0.8 + (k % 2) * 0.35), ["FFFFFF", "F2F4F8"], subdiv=1, jitter=0.08, squash=0.62, seed=int(x + k) & 255)
    parts["Clouds"] = clouds
    return parts


CORN_BLOCKS = ((-38, 8, -712, -622), (-122, -82, -668, -578), (52, 92, -668, -578), (-122, 92, -578, -478))


def in_corn(rx, rz, margin=0):
    return any(x0 - margin < rx < x1 + margin and z0 - margin < rz < z1 + margin for x0, x1, z0, z1 in CORN_BLOCKS)


def surface_height(x, y):
    """The racing surface, matching the solid hill wedges in the place. Roblox's Pumpkin Hill is along z = -450."""
    rx, rz = -x, y
    if -478 <= rz <= -422:
        if -110 <= rx <= -40:
            return 40 + 14 * (rx + 110) / 70
        if -40 < rx <= 0:
            return 54
        if 0 < rx <= 60:
            return 54 - 14 * rx / 60
    return 40


def bed_parts():
    rng = random.Random(4)

    def color(x, y):
        if in_corn(-x, y):
            return rng.choice(("6B4A2E", "5E4028", "745033"))
        return rng.choice(("C2A67E", "B69A72", "CDB48C", "BCA078"))

    bed = Part()
    # East of the creek, with exact lines where the hill's slopes begin and end.
    sheet(bed, lines(-148, 122, 12, (-60, 0, 40, 110)), lines(-712, -422, 12, (-478,)), surface_height, color)
    # West of the creek: two pieces, with the gap for it between them.
    sheet(bed, lines(122, 178, 12), lines(-712, -571, 12), surface_height, color)
    sheet(bed, lines(122, 178, 12), lines(-549, -422, 12), surface_height, color)
    # The creek's banks.
    for y, size_y in ((-572, 2), (-548, 2)):
        cbox(bed, (150, y, 25), (56, size_y, 30), "6E4B30", bevel=0.4)
    cbox(bed, (121, -560, 25), (2, 24, 30), "6E4B30", bevel=0.4)
    # The outside of the hill, down to the timbers.
    xs = lines(-148, 122, 12, (-60, 0, 40, 110))
    for xa, xb in zip(xs, xs[1:]):
        ha, hb = surface_height(xa, -422), surface_height(xb, -422)
        if ha > 40 or hb > 40:
            ids = [bed.add((xa, -422, 40)), bed.add((xb, -422, 40)), bed.add((xb, -422, hb)), bed.add((xa, -422, ha))]
            bed.face(list(reversed(ids)), rng.choice(("B69A72", "A68C66")))

    pebbles = Part()
    rng = random.Random(8)
    for k in range(170):
        rx, rz = rng.uniform(-176, 146), rng.uniform(-710, -480)
        beside_creek = rx < -122 and -575 < rz < -545
        # Only near the edges of a lane, so nothing seems to be in the way.
        if not in_corn(rx, rz, 2) and not beside_creek and (rx < -168 or rx > 138 or rz < -702):
            ico(pebbles, (-rx, rz, 40.3), rng.uniform(0.7, 1.7), ["A8A198", "96918A", "BBB4AA"], subdiv=0, jitter=0.2, squash=0.6, seed=k)

    timber = Part()
    for row, z in enumerate((6.5, 20, 33.5)):
        color_row = ("7C5534", "6E4A2C", "875C38")[row]
        cbox(timber, (15, -713.5, z), (332, 3, 13), color_row, bevel=0.8)
        cbox(timber, (15, -420.5, z), (332, 3, 13), color_row, bevel=0.8)
        cbox(timber, (-149.5, -567, z), (3, 294, 13), color_row, bevel=0.8)
        cbox(timber, (179.5, -642, z), (3, 141, 13), color_row, bevel=0.8)
        cbox(timber, (179.5, -486, z), (3, 127, 13), color_row, bevel=0.8)
    for x in range(-148, 180, 54):
        cbox(timber, (x, -715, 20), (7, 3, 40), "5C3D24", bevel=0.8)
        cbox(timber, (x, -419, 20), (7, 3, 40), "5C3D24", bevel=0.8)
    return {"Bed": bed, "Pebbles": pebbles, "Timber": timber}


def corn_part():
    rng = random.Random(5)
    corn = Part()
    for x0, x1, z0, z1 in CORN_BLOCKS:
        x = x0 + 4
        while x < x1:
            z = z0 + 4
            while z < z1:
                # The middle of the big block stays clear for the barbecue's base.
                if not (abs(x + 15) < 70 and z0 == -578):
                    stalk(corn, -(x + rng.uniform(-2.5, 2.5)), z + rng.uniform(-2.5, 2.5), 40, rng.uniform(30, 44), rng)
                z += 11
            x += 11
    return corn


def pickets_part():
    """White picket fence along the same lines as the solid fence posts in the place."""
    p = Part()

    def picket(x, y):
        base = surface_height(x, y)
        box(p, (x, y, base + 7.2), (1.5, 0.8, 14.5), "F6F6EE")
        lathe(p, [(1.05, base + 14.4), (0, base + 16.2)], "FFFFFA", n=4, smooth=False, center=(x, y, 0), phase=0.5)

    def rail(points):
        for lift in (4, 10):
            tube(p, [(x, y, surface_height(x, y) + lift) for x, y in points], 0.5, "ECECE2", n=4, smooth=False)

    east = [(-148, y) for y in range(-712, -422, 9)]
    west_n = [(178, y) for y in range(-712, -574, 9)]
    west_s = [(178, y) for y in range(-546, -422, 9)]
    # North runs along Roblox z = -712, stopping either side of the corn that reaches it.
    north_a = [(x, -712) for x in range(-148, -14, 9)]
    north_b = [(x, -712) for x in range(46, 179, 9)]
    south = [(x, -423) for x in range(-148, 179, 9)]
    for run in (east, west_n, west_s, north_a, north_b, south):
        for x, y in run:
            picket(x, y)
        rail(run)
    return p


def fence_part():
    p = Part()
    colors = ("B07E52", "A47448", "BC8A5C", "A87A4E")

    def plank(x, y, along_x, color):
        width = 22
        size = (width, 3, 92) if along_x else (3, width, 92)
        box(p, (x, y, 46), size, color)
        half = V((width / 2, 0, 0)) if along_x else V((0, width / 2, 0))
        ids = [p.add(V((x, y, 92)) + half), p.add(V((x, y, 92)) - half), p.add((x, y, 99))]
        p.face(ids, color)
        p.face(list(reversed(ids)), color)

    k = 0
    for x in range(-485, 516, 24):
        plank(x, -1010, True, colors[k % 4])
        k += 1
    for y in range(-1010, -262, 24):
        plank(-485, y, False, colors[k % 4])
        plank(515, y, False, colors[(k + 2) % 4])
        k += 1
    return p


def house_part():
    """1000 wide, so its corner stays clear of the kitchen."""
    p = Part()
    x0, x1 = -505, 495
    mid = (x0 + x1) / 2
    box(p, (mid, -227, 150), (x1 - x0, 70, 300), "F0E4CE")
    for z in range(24, 296, 24):
        box(p, (mid, -262.3, z), (x1 - x0, 0.6, 1.4), "D8CAB2")
        box(p, (mid, -191.7, z), (x1 - x0, 0.6, 1.4), "D8CAB2")
    for x in range(-385, 396, 156):
        house_window(p, x, 222, -262, -1)
        house_window(p, x, 222, -192, 1)
    for x in (-375, -215, 235, 385):
        house_window(p, x, 84, -262, -1)
        house_window(p, x, 84, -192, 1)
    # Sliding doors onto the patio, at the back.
    box(p, (15, -263, 67), (226, 2, 134), "F6F6F0")
    for x in (-40, 70):
        box(p, (x, -264.2, 66), (104, 0.8, 122), "8FBEDC")
    box(p, (15, -264.8, 66), (4, 1.2, 124), "F6F6F0")
    cbox(p, (15, -277, 3.5), (240, 30, 7), "B0A99E", bevel=0.8)
    # The front door, facing the lobby.
    box(p, (15, -191, 61), (76, 2, 122), "F6F6F0")
    box(p, (15, -189.8, 57), (64, 1.6, 114), "A03628")
    for z in (30, 82):
        box(p, (15, -189, z), (44, 0.8, 42), "882C22")
    ico(p, (-9, -188.6, 56), 2.5, "E2B84C", subdiv=0, jitter=0.02)
    cbox(p, (15, -177, 3.5), (110, 30, 7), "B0A99E", bevel=0.8)
    # Roof, eaves, chimney.
    gable_roof(p, x0 - 10, x1 + 10, -274, -180, 303, 405, ("5A5258", "4E474C", "65595F", "544C51"), 26, 5, seed=4)
    box(p, (mid, -227, 303), (x1 - x0 + 24, 94, 6), "F6F6F0")
    box(p, (-245, -227, 370), (58, 48, 150), "A8533E")
    cbox(p, (-245, -227, 448), (66, 56, 7), "B0A99E", bevel=1)
    return p


def patio_part():
    rng = random.Random(6)
    p = Part()
    sheet(p, lines(-305, 335, 40), lines(-382, -262, 40), lambda x, y: 4.6, lambda x, y: rng.choice(("B4AEA2", "A8A296", "BEB8AC", "9E988C")))
    spot = V((205, -322, 4.6))
    lathe(p, [(4, 0), (3, 38), (40, 39), (40, 41.5), (0, 41.5)], "E8E2D2", n=8, smooth=False, center=spot)
    tube(p, [spot, spot + V((0, 0, 132))], 1.7, "F6F6F0", n=5, smooth=False)
    shades = ["DC4032", "F6F4EC"]
    for k in range(8):
        a, b = k * pi / 4, (k + 1) * pi / 4
        ids = [p.add(spot + V((cos(a) * 62, sin(a) * 62, 114))), p.add(spot + V((cos(b) * 62, sin(b) * 62, 114))), p.add(spot + V((0, 0, 136)))]
        p.face(ids, shades[k % 2])
        p.face(list(reversed(ids)), shades[k % 2])
    for k in range(4):
        a = k * pi / 2 + pi / 4
        with p.xf(Matrix.Translation(spot + V((cos(a) * 56, sin(a) * 56, 0))) @ Matrix.Rotation(a + pi / 2, 4, "Z")):
            cbox(p, (0, 0, 24), (26, 26, 3), "F0ECE0", bevel=0.4)
            cbox(p, (0, 13, 39), (26, 3, 30), "F0ECE0", bevel=0.4)
            for x in (-11, 11):
                for y in (-11, 11):
                    box(p, (x, y, 11.5), (2.4, 2.4, 23), "4A4C55")
    return p


def tree_parts():
    trunks, leaves = Part(), Part()
    for x, z, height, seed in ((-440, -880, 170, 11), (-430, -410, 150, 12), (-180, -950, 180, 13), (120, -950, 160, 14), (420, -700, 170, 15), (430, -350, 150, 16), (-640, -720, 210, 17), (620, -560, 220, 18), (-20, -1120, 200, 19)):
        tree(trunks, leaves, -x, z, height, seed)
    return {"Trunks": trunks, "Leaves": leaves}


def things_part():
    rng = random.Random(7)
    p = Part()
    # Shed, with its doors facing the garden.
    sx, sy = -360, -900
    box(p, (sx, sy, 60), (170, 130, 120), "76A07A")
    gable_roof(p, sx - 92, sx + 92, sy - 72, sy + 72, 120, 180, ("5A5258", "4E474C", "65595F"), 8, 3, seed=5)
    for side in (-1, 1):
        box(p, (sx + side * 26, sy + 65.6, 48), (50, 1.2, 96), "F6F6F0")
        with p.xf(Matrix.Translation((sx + side * 26, sy + 66.4, 48)) @ Matrix.Rotation(side * 0.47, 4, "Y")):
            box(p, (0, 0, 0), (5, 0.8, 104), "5F8A64")
    box(p, (sx + 85.6, sy, 74), (1, 56, 44), "8FBEDC")
    # Trampoline.
    tx, ty = -340, -420
    lathe(p, [(75, 25), (75, 30), (62, 30.4), (0, 29)], lambda c, i, j: "2E78C8" if i < 2 else "2A2A30", n=10, smooth=False, center=(tx, ty, 0))
    for k in range(5):
        a = k * 2 * pi / 5
        tube(p, [(tx + cos(a) * 66, ty + sin(a) * 66, 0), (tx + cos(a) * 66, ty + sin(a) * 66, 26)], 2, "4A4C55", n=4, smooth=False)
    # Swing set.
    wx, wy = 400, -600
    for end in (-75, 75):
        for side in (-42, 42):
            tube(p, [(wx + side, wy + end, 0), (wx, wy + end, 112)], 3, "D63C32", n=4, smooth=False)
    tube(p, [(wx, wy - 75, 112), (wx, wy + 75, 112)], 3, "F4C232", n=4, smooth=False)
    for y in (-38, 38):
        box(p, (wx, wy + y, 26), (10, 24, 2), "F4C232")
        for o in (-9, 9):
            box(p, (wx, wy + y + o, 69), (0.8, 0.8, 86), "4A4A50")
    # Veg patches.
    soil = ("5E4028", "6B4A2E")
    sheet(p, lines(215, 305, 30), lines(-795, -645, 30), lambda x, y: 4.5, lambda x, y: rng.choice(soil))
    for x in (235, 262, 290):
        for y in range(-785, -650, 30):
            ico(p, (x, y, 13), 11.5, ["6EB24E", "84C462", "5CA044"], subdiv=1, jitter=0.1, squash=0.85, seed=x + y)
    sheet(p, lines(205, 295, 30), lines(-505, -395, 27.5), lambda x, y: 4.5, lambda x, y: rng.choice(soil))
    for y in (-490, -450, -410):
        for x in (232, 268):
            ico(p, (x, y, 26), 15, ["3E8C3A", "4C9C44", "348034"], subdiv=1, jitter=0.15, squash=1.5, seed=x * 3 + y)
            for k in range(5):
                a = k * 1.8
                ico(p, (x + cos(a) * 11, y + sin(a) * 11, 16 + k * 5), 3.2, ["E0342A", "D22A22"], subdiv=0, jitter=0.05, seed=k)
    sheet(p, lines(-260, -195, 32.5), lines(-705, -575, 32.5), lambda x, y: 4.5, lambda x, y: rng.choice(soil))
    for y in range(-695, -585, 22):
        for x in (-240, -214):
            lathe(p, [(3.4, 4.4), (2.4, 9), (0, 10)], "F27A20", n=5, smooth=False, center=(x, y, 0))
            ico(p, (x, y, 15), 6, ["5CA63E", "6DB84A"], subdiv=0, jitter=0.2, seed=y)
    # The pond, with stones and lilies, where the creek's waterfall comes down.
    lathe(p, [(0, 5), (24, 5.2)], "4FA8D8", n=10, smooth=False, center=(200, -560, 0), radial=lambda a, i: 1 + 0.12 * sin(3 * a))
    for k in range(13):
        a = k * 2 * pi / 13
        ico(p, (200 + cos(a) * 26, -560 + sin(a) * 26, 6), rng.uniform(3.5, 6.5), ["9A958C", "8A857C", "ABA59C"], subdiv=0, jitter=0.2, squash=0.7, seed=k)
    for x, y in ((191, -570), (208, -554), (195, -547)):
        lathe(p, [(0, 5.4), (4.5, 5.5)], "50A550", n=6, smooth=False, center=(x, y, 0))
        ico(p, (x, y, 6.2), 1.7, "FAAAC8", subdiv=0, jitter=0.05)
    # Gnomes.
    for x, y in ((196, -420), (-170, -400), (212, -700), (-180, -730)):
        lathe(p, [(8, 3), (7.4, 19)], "3468B4", n=6, smooth=False, center=(x, y, 0))
        ico(p, (x, y, 25), 7, "FFCDA8", subdiv=0, jitter=0.03)
        ico(p, (x, y - 3, 21), 6, "F8F8F0", subdiv=0, jitter=0.08)
        lathe(p, [(7.8, 28), (0, 45)], "D63028", n=6, smooth=False, center=(x, y, 0))
    return p


def sunflowers_part():
    p = Part()
    k = 0
    for x in range(-135, 170, 44):
        k += 1
        sunflower(p, x, -398, 66 + k % 3 * 12, k)
        sunflower(p, x - 12, -736, 72 + k % 3 * 12, k + 20)
    for y in range(-700, -429, 48):
        k += 1
        sunflower(p, -170, y, 70 + k % 3 * 12, k + 40)
    return p


def neighbors_part():
    p = Part()
    for x, y, color in ((330, -1230, "D6C4AA"), (-340, -1240, "BAC8D2")):
        box(p, (x, y, 110), (320, 170, 220), color)
        gable_roof(p, x - 168, x + 168, y - 92, y + 92, 220, 300, ("5A5258", "4E474C"), 8, 2, seed=6)
    return p


def barbecue_parts():
    """On a stone plinth rising out of the corn, since the corn's no longer a solid block to stand on."""
    rng = random.Random(9)
    p = Part()
    base = R(-15, 68, -528)
    half_x, half_y = 66, 46
    stones = ("B4AEA2", "A8A296", "BEB8AC", "9E988C", "C4BEB2")
    box(p, base + V((0, 0, -14)), (half_x * 2 - 2, half_y * 2 - 2, 28), "7F7A72")
    # Courses of stone blocks around the sides, each row offset from the one below.
    for course in range(3):
        z = -14 + (course - 1) * 9.4
        shift = (course % 2) * 11
        for side in (-1, 1):
            x = -half_x + 11 + shift
            while x <= half_x - 11 + 0.1:
                cbox(p, base + V((x, side * (half_y - 1.5), z)), (21.4, 3, 9), rng.choice(stones), bevel=0.7)
                x += 22
            y = -half_y + 11 + shift
            while y <= half_y - 11 + 0.1:
                cbox(p, base + V((side * (half_x - 1.5), y, z)), (3, 21.4, 9), rng.choice(stones), bevel=0.7)
                y += 22
    sheet(p, lines(base.x - half_x, base.x + half_x, 22), lines(base.y - half_y, base.y + half_y, 23), lambda x, y: 68.2, lambda x, y: rng.choice(stones))
    cbox(p, base + V((0, 0, 14)), (112, 78, 28), "A8533E", bevel=1.2)
    for z in (5, 12, 19, 25):
        box(p, base + V((0, 0, z)), (112.4, 78.4, 0.6), "8F4532")
    cbox(p, base + V((0, 0, 29.5)), (120, 86, 3), "B8B2A6", bevel=0.8)
    box(p, base + V((0, 0, 31.4)), (72, 52, 1), "2A2422")
    for x in range(-30, 31, 10):
        box(p, base + V((x, 0, 33)), (1.4, 54, 1), "34343A")
    cbox(p, base + V((-52, -30, 36)), (22, 22, 74), "A8533E", bevel=1.2)
    cbox(p, base + V((-52, -30, 75)), (28, 28, 4), "B8B2A6", bevel=0.6)
    for k in range(6):
        ico(p, base + V((-52 + k * 1.5, -30 - k * 1.5, 88 + k * 14)), 5 + k * 1.6, ["E8E8E6", "F4F4F2"], subdiv=0, jitter=0.15, seed=k)
    coals = Part()
    box(coals, base + V((0, 0, 32)), (66, 46, 0.8), "FF8A28")
    return {"BBQ": p, "BBQ_Coals_Glow": coals}


# Scene, export, preview ---------------------------------------------------------------------------------------------------


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


def make_mesh(name, part, rng):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(part.verts, [], [ids for ids, _, _ in part.faces])
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, (_, color, _) in zip(mesh.polygons, part.faces):
        polygon.use_smooth = False
        uv = swatch_uv(swatch_for(color, rng.choice(SHADES)))
        for i in polygon.loop_indices:
            uv_layer.data[i].uv = uv
    return mesh


def bounds_of(part):
    low = V((min(v.x for v in part.verts), min(v.y for v in part.verts), min(v.z for v in part.verts)))
    high = V((max(v.x for v in part.verts), max(v.y for v in part.verts), max(v.z for v in part.verts)))
    return low, high


def build():
    clear()
    scene = bpy.data.scenes.new(SCENE)
    collection = bpy.data.collections.new("TR_LowPolyYard")
    scene.collection.children.link(collection)

    parts = {}
    parts.update(lawn_parts())
    parts.update(far_parts())
    parts.update(bed_parts())
    parts["Corn"] = corn_part()
    parts["Pickets"] = pickets_part()
    parts["Fence"] = fence_part()
    parts["House"] = house_part()
    parts["Patio"] = patio_part()
    parts.update(tree_parts())
    parts["Things"] = things_part()
    parts["Sunflowers"] = sunflowers_part()
    parts["Neighbors"] = neighbors_part()
    parts.update(barbecue_parts())

    rng = random.Random(21)
    objects = {}
    report = []
    total = 0
    for name, part in parts.items():
        obj = bpy.data.objects.new(name, make_mesh(name, part, rng))
        collection.objects.link(obj)
        objects[name] = obj
        tris = sum(len(ids) - 2 for ids, _, _ in part.faces)
        total += tris
        low, high = bounds_of(part)
        size = high - low
        assert tris < 20000, f"{name} has {tris} triangles, over Roblox's limit for a mesh"
        assert max(size.x, size.y, size.z) < 2048, f"{name} is too big for one part"
        report.append(f"{name}: {tris} tris, {size.x:.0f} x {size.z:.0f} x {size.y:.0f}")

    # The chef's meshes are modeled around his feet and his shoulder. Roblox centers a mesh on its bounds, so the game
    # needs to know where those centers are from the feet and shoulder.
    feet = R(-15, 101.6, -528)
    for name, part, at in (("Chef_Body", chef_body(), feet), ("Chef_Arm", chef_arm(), feet + SHOULDER)):
        obj = bpy.data.objects.new(name, make_mesh(name, part, rng))
        obj.location = at
        collection.objects.link(obj)
        tris = sum(len(ids) - 2 for ids, _, _ in part.faces)
        total += tris
        low, high = bounds_of(part)
        center = (low + high) / 2
        report.append(f"{name}: {tris} tris, center in Roblox terms ({-center.x:.3f}, {center.z:.3f}, {center.y:.3f})")

    image = make_palette()
    material = make_material(image)
    for obj in collection.objects:
        obj.data.materials.append(material)
    print("\n".join(report))
    print(f"meshes: {len(collection.objects)}, total tris: {total}, swatches: {len(swatches)}")

    # A plain preview, to check the shapes before anything's uploaded.
    data = bpy.data.lights.new("LPY_Key", "SUN")
    data.energy = 3.0
    data.angle = 0.05
    data.color = (1.0, 0.91, 0.78)
    sun = bpy.data.objects.new("LPY_Key", data)
    sun.rotation_euler = (0.84, 0, 0.56)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.get("LPY_World") or bpy.data.worlds.new("LPY_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.62, 0.78, 0.92, 1)
        background.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("LPY_Camera")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = 1.22
    cam_data.clip_end = 8000
    cam = bpy.data.objects.new("LPY_Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 702
    scene.render.image_settings.file_format = "PNG"
    eye, target = R(-15, 330, -940), R(-15, 40, -400)
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = ASSET_DIR + "/TurkeyRace_LowPolyYard_preview.png"
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], scene=scene):
        bpy.ops.render.render(write_still=True, scene=SCENE)

    # Export. Show the scene in the window while exporting: overriding the scene and view layer in the operator's
    # context crashed Blender 5.2 in its scene update.
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
    clear()
    for name in ("M_LowPolyYard",):
        mat = bpy.data.materials.get(name)
        if mat:
            bpy.data.materials.remove(mat)
    image = bpy.data.images.get("T_LowPolyYard_Palette")
    if image:
        bpy.data.images.remove(image)
    print("still open:", bpy.data.filepath, "dirty:", bpy.data.is_dirty, "scenes:", [s.name for s in bpy.data.scenes])


build()
