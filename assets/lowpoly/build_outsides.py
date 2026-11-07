"""Builds the outsides of the dining room and the kitchen, so from the lobby they look like wings of the house, and
exports them.

Run it inside Blender, like build_forest.py, whose helpers it shares. It works in its own scene, saves that to its own
.blend, and leaves the file that's open untouched.

The dining room gets the main house's cream clapboards and blue-shuttered windows, a porch over double front doors
facing the lobby, a shingled roof, and a brick chimney behind the fireplace. The kitchen is brick with clapboard gables,
a back door, and a vent on the roof; the oven, which sticks out of its east wall, is boxed in as a brick chimney.
Everything sits just outside the old walls, which stay as they are, so nothing changes inside the rooms. The oven is
where Oven Escape starts, so the chimney around it has no face inside it, only walls around its outside.
"""

import os
import random
from math import cos, pi, sin

import bpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/lowpoly"
EXPORT = ASSET_DIR + "/export/TurkeyRace_LowPolyOutsides.glb"
BLEND = ASSET_DIR + "/TurkeyRace_LowPolyOutsides.blend"
FOREST_BLEND = ASSET_DIR + "/TurkeyRace_LowPolyForest.blend"
RENDERS = ASSET_DIR + "/renders"
SCENE = "TR_LowPolyOutsides"

rooms = {"__name__": "rooms_helpers"}
rooms_source = open(ASSET_DIR + "/build_rooms.py", encoding="utf-8").read()
exec(rooms_source[: rooms_source.rindex("build()")], rooms)
Part, box, cbox, lathe, ico, R = rooms["Part"], rooms["box"], rooms["cbox"], rooms["lathe"], rooms["ico"], rooms["R"]
make_mesh, make_palette, make_material, bounds_of = rooms["make_mesh"], rooms["make_palette"], rooms["make_material"], rooms["bounds_of"]
swatches = rooms["helpers"]["swatches"]

# The main house's colors, from build_backyard.py.
SIDING = ("F0E4CE", "EADDC4", "F4EAD8")
SIDING_LINE = "D8CAB2"
TRIM = "F6F6F0"
SHUTTER = "42687C"
GLASS = "8FBEDC"
DOOR, DOOR_PANEL, BRASS = "A03628", "882C22", "E2B84C"
ROOF = ("5A5258", "4E474C", "65595F", "544C51")
STONE = ("9A948C", "8A857E", "A7A097", "B0A99E")
BRICK = ("A8533E", "9C4A36", "B25E46", "8F4432", "A04C38")
BRICK_WEIGHTS = (4, 3, 3, 2, 3)
MORTAR = "C9BFB0"
STEEL, STEEL_DARK = "9DA3A9", "686E74"
POT = "B5532A"
LEAVES = (["CC4228", "DD5A2C"], ["E2782A", "EE9234"], ["F0AE32", "F6C24A"], ["B5532A", "C4652F"])

# Roblox coordinates. The dining room's old walls and ceiling reach x -442 to 442, z 208 to 792 and 286 up; the
# kitchen's reach x -902 to -498, z -242 to 162 and 176 up, and the oven pokes out of it to z 164 and, east, to x -438.
DINING = {"x0": -443.5, "x1": 443.5, "z0": 206.5, "z1": 793.5, "top": 286.0, "slope": 0.6}
KITCHEN = {"x0": -903.5, "x1": -496.5, "z0": -243.5, "z1": 164.6, "top": 176.0, "slope": 0.55}
OVEN_STACK = {"x1": -430.0, "z0": 88.0, "z1": 172.0, "top": 320.0}  # its west side is the kitchen's east wall
ROOF_T = 4.0

rng = random.Random(41)


# Frames ----------------------------------------------------------------------------------------------------------------


def frame(cx, cz, nx, nz):
    """A frame on a wall's outer face at ground level, centered at Roblox (cx, cz) and facing Roblox (nx, nz). Local X
    runs along the wall, +Y points out of it and Z is up."""
    n = V((-nx, nz, 0))
    a = V((n.y, -n.x, 0))
    return Matrix(((a.x, n.x, 0, -cx), (a.y, n.y, 0, cz), (0, 0, 1, 0), (0, 0, 0, 1)))


def local_frame(ou, oy, nu, ny):
    """The same inside another frame: a face at (ou, oy) facing (nu, ny)."""
    return Matrix(((ny, nu, 0, ou), (-nu, ny, 0, oy), (0, 0, 1, 0), (0, 0, 0, 1)))


# Wall coverings, each on the current frame's y = 0 plane, facing +Y ---------------------------------------------------


def clapboards(p, u0, u1, h0, h1, board=16.0, lip=1.2, gable=None):
    """Boards from u0 to u1 and h0 to h1. Each leans back a little, so its face catches the light and its bottom edge
    makes a shadow line. gable = (half width, base, slope) trims them to the triangle under a roof."""
    h = h0
    while h < h1 - 0.01:
        ha, hb = h, min(h + board, h1)
        la, ra, lb, rb = u0, u1, u0, u1
        if gable:
            half, base, slope = gable
            wa = half - max(0.0, ha - base) / slope
            wb = half - max(0.0, hb - base) / slope
            if wa <= 0.5:
                break
            if wb <= 0:
                hb, wb = base + half * slope, 0.0
            la, ra, lb, rb = max(u0, -wa), min(u1, wa), max(u0, -wb), min(u1, wb)
        ids = [p.add((la, lip, ha)), p.add((ra, lip, ha)), p.add((rb, 0, hb))]
        if rb - lb > 0.01:
            ids.append(p.add((lb, 0, hb)))
        p.face_out(ids, rng.choice(SIDING), p.m @ V(((u0 + u1) / 2, -60, (ha + hb) / 2)))
        ids = [p.add((la, 0, ha)), p.add((ra, 0, ha)), p.add((ra, lip, ha)), p.add((la, lip, ha))]
        p.face_out(ids, SIDING_LINE, p.m @ V(((la + ra) / 2, lip / 2, ha + 20)))
        h = hb


def bricks(p, u0, u1, h0, h1, length=20.0, course=8.0, joint=1.0, depth=0.35):
    """Running bond on a mortar backing, each brick its own shade."""
    ids = [p.add((u0, 0, h0)), p.add((u1, 0, h0)), p.add((u1, 0, h1)), p.add((u0, 0, h1))]
    p.face_out(ids, MORTAR, p.m @ V(((u0 + u1) / 2, -60, (h0 + h1) / 2)))
    pitch = length + joint
    row, h = 0, h0
    while h < h1 - 1.5:
        hb = min(h + course, h1)
        u = u0 - (row % 2) * pitch / 2
        while u < u1 - 1.5:
            a, b = max(u, u0) + joint / 2, min(u + pitch, u1) - joint / 2
            if b - a > 1.5:
                ids = [p.add((a, depth, h + joint / 2)), p.add((b, depth, h + joint / 2)), p.add((b, depth, hb - joint / 2)), p.add((a, depth, hb - joint / 2))]
                p.face_out(ids, rng.choices(BRICK, BRICK_WEIGHTS)[0], p.m @ V(((a + b) / 2, -60, (h + hb) / 2)))
            u += pitch
        row += 1
        h = hb


def brick_box(p, u0, u1, y0, y1, h0, h1, sides):
    """Brick on the named sides of a block standing out from the wall: front (+Y), back (-Y), left (-X), right (+X)."""
    cu, cy = (u0 + u1) / 2, (y0 + y1) / 2
    faces = {
        "front": ((cu, y1), (0, 1), u1 - u0),
        "back": ((cu, y0), (0, -1), u1 - u0),
        "left": ((u0, cy), (-1, 0), y1 - y0),
        "right": ((u1, cy), (1, 0), y1 - y0),
    }
    for name in sides:
        (ou, oy), (nu, ny), width = faces[name]
        with p.xf(local_frame(ou, oy, nu, ny)):
            bricks(p, -width / 2, width / 2, h0, h1)


def foundation(p, u0, u1, height=14.0, out=2.5):
    u = u0
    while u < u1 - 1:
        b = min(u + rng.uniform(26, 42), u1)
        if u1 - b < 12:
            b = u1
        cbox(p, ((u + b) / 2, out / 2 - 0.5, height / 2), (b - u - 0.8, out + 1, height), rng.choice(STONE), bevel=0.8)
        u = b


# Windows and doors -----------------------------------------------------------------------------------------------------


def window(p, u, h, w=76.0, ht=96.0, shutters=SHUTTER, lintel=None):
    """A window centered at (u, h): a white frame standing out 3, the glass set back in it, and a sill."""
    t = 6.0
    for du, dh, sw, sh in ((0, ht / 2 - t / 2, w, t), (0, -ht / 2 + t / 2, w, t), (-w / 2 + t / 2, 0, t, ht - 2 * t), (w / 2 - t / 2, 0, t, ht - 2 * t)):
        box(p, (u + du, 1.5, h + dh), (sw, 3, sh), TRIM)
    box(p, (u, 0.6, h), (w - 2 * t + 0.2, 1.2, ht - 2 * t + 0.2), GLASS)
    box(p, (u, 1.4, h), (w - 2 * t, 1.2, 3), TRIM)
    box(p, (u, 1.4, h), (3, 1.2, ht - 2 * t), TRIM)
    cbox(p, (u, 3, h - ht / 2 - 2), (w + 10, 6, 4), TRIM if shutters else STONE[3], bevel=0.6)
    if lintel:
        cbox(p, (u, 2, h + ht / 2 + 4), (w + 12, 4, 8), lintel, bevel=0.6)
    if shutters:
        for side in (-1, 1):
            su = u + side * (w / 2 + 11)
            box(p, (su, 0.9, h), (19, 1.8, ht), shutters)
            box(p, (su, 2.0, h), (15, 0.6, 4), shutters)


def vent(p, u, h, w, ht):
    """A louvered attic vent."""
    t = 5.0
    for du, dh, sw, sh in ((0, ht / 2 - t / 2, w, t), (0, -ht / 2 + t / 2, w, t), (-w / 2 + t / 2, 0, t, ht - 2 * t), (w / 2 - t / 2, 0, t, ht - 2 * t)):
        box(p, (u + du, 1.5, h + dh), (sw, 3, sh), TRIM)
    box(p, (u, 0.5, h), (w - 2 * t + 0.2, 1, ht - 2 * t + 0.2), "3E3A3C")
    z = h - ht / 2 + t + 3
    while z < h + ht / 2 - t - 2:
        box(p, (u, 1.6, z), (w - 2 * t, 1.6, 2.6), TRIM)
        z += 6.5


def door(p, u, w, ht, leaves=1, color=DOOR, wreaths=False):
    """A door standing on the ground at u, with a white frame; two leaves make it a double door with a glass transom."""
    t = 6.0
    transom = 16.0 if leaves == 2 else 0.0
    for side in (-1, 1):
        box(p, (u + side * (w / 2 + t / 2), 1.5, (ht + transom) / 2), (t, 3, ht + transom), TRIM)
    box(p, (u, 1.5, ht + transom + t / 2), (w + 2 * t, 3, t), TRIM)
    if transom:
        box(p, (u, 0.6, ht + transom / 2), (w, 1.2, transom), GLASS)
        box(p, (u, 1.4, ht), (w, 1.4, 3), TRIM)
    leaf_w = w / leaves
    for k in range(leaves):
        lu = u - w / 2 + leaf_w * (k + 0.5)
        box(p, (lu, 0.8, ht / 2), (leaf_w - 1, 1.6, ht), color)
        for dh in (0.27, 0.7):
            box(p, (lu, 1.9, ht * dh), (leaf_w * 0.62, 0.8, ht * 0.34), DOOR_PANEL)
        # On a double door the knobs meet in the middle.
        knob = lu + (leaf_w / 2 - 8) * (1 if leaves == 1 or k == 0 else -1)
        ico(p, (knob, 3.0, ht * 0.48), 2.4, BRASS, subdiv=0, jitter=0.02)
        if wreaths:
            colors = LEAVES[k % len(LEAVES)] + LEAVES[(k + 2) % len(LEAVES)]
            for j in range(10):
                a = j * 2 * pi / 10
                ico(p, (lu + cos(a) * 10, 4.5, ht * 0.7 + sin(a) * 10), 4.0, colors, subdiv=0, jitter=0.15, seed=k * 20 + j)
            box(p, (lu, 6.5, ht * 0.7 - 11), (6, 1.5, 4), "B8351F")


# Roofs -------------------------------------------------------------------------------------------------------------------


def roof(p, length, d, base, slope, overhang, rake, rows, patch=60.0, lip=1.4, seed=1):
    """A gable roof in the current frame: ridge along X over x = +-length/2, walls at y = +-d whose tops are at `base`,
    where the roof's underside meets them. Shingles in staggered courses, white boards along the eaves and rakes, and
    an underside wherever it overhangs."""
    r = random.Random(seed)
    xa, xb = -length / 2 - rake, length / 2 + rake
    reach = d + overhang

    def under(y):
        return base + slope * (d - abs(y))

    def top(y):
        return under(y) + ROOF_T

    for side in (-1, 1):
        for j in range(rows):
            ya, yb = side * reach * (1 - j / rows), side * reach * (1 - (j + 1) / rows)
            x = xa
            w = patch * r.uniform(0.2, 1.0)
            while x < xb - 1:
                x2 = min(x + w, xb)
                if xb - x2 < 8:
                    x2 = xb
                color = r.choice(ROOF)
                ids = [p.add((x, ya, top(ya) + lip)), p.add((x2, ya, top(ya) + lip)), p.add((x2, yb, top(yb))), p.add((x, yb, top(yb)))]
                p.face_out(ids, color, p.m @ V(((x + x2) / 2, side * reach / 2, base - 400)))
                if j > 0:
                    ids = [p.add((x, ya, top(ya))), p.add((x2, ya, top(ya))), p.add((x2, ya, top(ya) + lip)), p.add((x, ya, top(ya) + lip))]
                    p.face_out(ids, ROOF[1], p.m @ V(((x + x2) / 2, 0, top(ya) + lip / 2)))
                x = x2
                w = patch * r.uniform(0.6, 1.2)
        edge = side * reach
        ids = [p.add((xa, edge, under(edge))), p.add((xb, edge, under(edge))), p.add((xb, 0, under(0))), p.add((xa, 0, under(0)))]
        p.face_out(ids, "3E3A3C", p.m @ V((0, edge / 2, base + 1000)))
        ids = [p.add((xa, edge, under(edge))), p.add((xb, edge, under(edge))), p.add((xb, edge, top(edge) + lip)), p.add((xa, edge, top(edge) + lip))]
        p.face_out(ids, TRIM, p.m @ V((0, 0, top(edge))))
        for x in (xa, xb):
            ids = [p.add((x, edge, under(edge))), p.add((x, 0, under(0))), p.add((x, 0, top(0) + lip)), p.add((x, edge, top(edge) + lip))]
            p.face_out(ids, TRIM, p.m @ V((0, edge / 2, (under(0) + under(edge)) / 2)))
    cbox(p, (0, 0, top(0) + lip), (xb - xa + 2, 10, 5), ROOF[1], bevel=1.2)


# The dining room ---------------------------------------------------------------------------------------------------------


def dining_parts():
    walls, trim, roof_part = Part(), Part(), Part()
    D = DINING
    top, slope = D["top"], D["slope"]
    half_x, half_z = (D["x1"] - D["x0"]) / 2, (D["z1"] - D["z0"]) / 2
    cz = (D["z0"] + D["z1"]) / 2
    sides = {
        "front": (frame(0, D["z0"], 0, -1), half_x),  # facing the lobby; u is Roblox x
        "back": (frame(0, D["z1"], 0, 1), half_x),
        "east": (frame(D["x1"], cz, 1, 0), half_z),
        "west": (frame(D["x0"], cz, -1, 0), half_z),
    }
    for name, (m, half) in sides.items():
        gable = name in ("east", "west")
        for part in (walls, trim):
            part.m = m
        clapboards(walls, -half, half, 14, top)
        if gable:
            clapboards(walls, -half, half, top, top + half * slope, gable=(half, top, slope))
            vent(trim, 0, top + 86, 60, 76)
        foundation(walls, -half - 2.5, half + 2.5)
        box(walls, (0, 1.2, top - 7), (2 * half + 5, 2.4, 14), TRIM)
        rows = (-190, 0, 190) if gable else (-330, -170, 170, 330)
        for u in rows:
            for h in (84, 212):
                window(trim, u, h)
        if name == "front":
            # A shallow porch: the forest's trunks stand 14 studs out from the wall, its leaves lower than the roof.
            door(trim, 0, 122, 150, leaves=2, wreaths=True)
            cbox(trim, (0, 8, 2), (210, 16, 4), STONE[3], bevel=0.8)
            for u in (-80, 80):
                lathe(trim, [(5.5, 4), (5.5, 164)], TRIM, n=8, smooth=False, center=(u, 12, 0))
                cbox(trim, (u, 12, 6), (14, 14, 4), TRIM, bevel=0.8)
                cbox(trim, (u, 12, 162), (14, 14, 5), TRIM, bevel=0.8)
            box(trim, (0, 12, 168), (190, 9, 8), TRIM)
            ids = [trim.add((-100, 17.6, 172)), trim.add((100, 17.6, 172)), trim.add((0, 17.6, 172 + 100 * 0.45))]
            trim.face_out(ids, TRIM, trim.m @ V((0, 0, 180)))
            with roof_part.xf(m @ Matrix.Translation((0, 9, 0)) @ Matrix.Rotation(pi / 2, 4, "Z")):
                roof(roof_part, 18, 100, 172, 0.45, 6, 3, rows=4, patch=40, seed=7)
        if name == "back":
            # The fireplace's chimney, coming up through the roof just inside this wall, above the ceiling; the
            # game adds smoke.
            brick_box(walls, -38, 38, -30, -4, 287, 466, ("front", "back", "left", "right"))
            cbox(walls, (0, -17, 469), (86, 36, 6), STONE[3], bevel=1)
            for u in (-14, 14):
                lathe(walls, [(6, 472), (6, 484), (7.5, 484), (7.5, 487), (0, 487)], POT, n=6, smooth=False, center=(u, -17, 0))
    for part in (walls, trim):
        part.m = Matrix.Identity(4)
    # White corner boards over the ends of the clapboards.
    for x, sx in ((D["x0"], -1), (D["x1"], 1)):
        for z, sz in ((D["z0"], -1), (D["z1"], 1)):
            box(walls, R(x + sx * 1, top / 2, z + sz * 1), (8, 8, top), TRIM)
    with roof_part.xf(Matrix.Translation((0, cz, 0))):
        roof(roof_part, 2 * half_x, half_z, top, slope, 12, 10, rows=16, seed=3)
    return {"Outside_Dining_Walls": walls, "Outside_Dining_Trim": trim, "Outside_Dining_Roof": roof_part}


# The kitchen -------------------------------------------------------------------------------------------------------------


def kitchen_parts():
    walls, trim, roof_part = Part(), Part(), Part()
    K, S = KITCHEN, OVEN_STACK
    top, slope = K["top"], K["slope"]
    cx = (K["x0"] + K["x1"]) / 2
    cz = (K["z0"] + K["z1"]) / 2
    half_x = (K["x1"] - K["x0"]) / 2
    east_cz, east_half = (K["z0"] + S["z0"]) / 2, (S["z0"] - K["z0"]) / 2
    sides = {
        "east": (frame(K["x1"], east_cz, 1, 0), east_half),  # facing the lobby, up to the oven; u is Roblox z - east_cz
        "north": (frame(cx, K["z0"], 0, -1), half_x),
        "west": (frame(K["x0"], cz, -1, 0), (K["z1"] - K["z0"]) / 2),
        "south": (frame(cx, K["z1"], 0, 1), half_x),
    }
    for name, (m, half) in sides.items():
        gable = name in ("north", "south")
        for part in (walls, trim):
            part.m = m
        bricks(walls, -half, half, 12, top)
        if gable:
            clapboards(walls, -half, half, top, top + half * slope, gable=(half, top, slope))
            vent(trim, 0, top + 52, 44, 54)
        foundation(walls, -half - (0 if name == "east" else 2.5), half + (0 if name == "east" else 2.5), height=12)
        box(walls, (0, 1.2, top - 5), (2 * half + (0 if name == "east" else 5), 2.4, 10), TRIM)
        if name == "east":
            door(trim, 0, 66, 120, color=SHUTTER)
            cbox(trim, (0, 14, 3), (100, 28, 6), STONE[3], bevel=0.8)
            with trim.xf(Matrix.Translation((0, 15, 143)) @ Matrix.Rotation(-0.38, 4, "X")):
                cbox(trim, (0, 0, 0), (104, 32, 3), ROOF[0], bevel=0.6)
            for side in (-1, 1):
                cbox(trim, (side * 46, 6, 131), (4, 12, 14), TRIM, bevel=0.4)
            for u in (-115, 105):
                window(trim, u, 92, w=70, ht=86, shutters=None, lintel=STONE[1])
        else:
            for u in (-130, 0, 130):
                window(trim, u, 92, w=70, ht=86, shutters=None, lintel=STONE[1])
        if name == "east":
            # The oven, boxed in as a chimney. Below the oven's top there's no face on its west side, which would
            # cross the oven where the race starts; the little strip past the kitchen's south wall is closed.
            u0, u1 = S["z0"] - east_cz, S["z1"] - east_cz
            depth = S["x1"] - K["x1"]
            brick_box(walls, u0, u1, 0, depth, 0, 170, ("front", "left", "right"))
            with walls.xf(local_frame((K["z1"] - east_cz + u1) / 2, 0, 0, -1)):
                bricks(walls, -(u1 - (K["z1"] - east_cz)) / 2, (u1 - (K["z1"] - east_cz)) / 2, 0, 170)
            brick_box(walls, u0, u1, 0, depth, 170, S["top"], ("front", "back", "left", "right"))
            cbox(walls, ((u0 + u1) / 2, depth / 2, S["top"] + 3), (u1 - u0 + 8, depth + 8, 6), STONE[3], bevel=1)
            for du in (-16, 16):
                lathe(walls, [(6, S["top"] + 6), (6, S["top"] + 18), (7.5, S["top"] + 18), (7.5, S["top"] + 21), (0, S["top"] + 21)], POT, n=6, smooth=False, center=((u0 + u1) / 2 + du, depth / 2, 0))
    for part in (walls, trim):
        part.m = Matrix.Identity(4)
    # Stone quoins on the corners.
    for x, sx in ((K["x0"], -1), (K["x1"], 1)):
        for z, sz in ((K["z0"], -1), (K["z1"], 1)):
            if sx == 1 and sz == 1:
                continue  # the oven chimney is there
            for k in range(10):
                h0 = 12 + k * 15.4
                a, b = (26, 15) if k % 2 == 0 else (15, 26)
                xa, xb = sorted((x - sx * a, x + sx * 2.5))
                za, zb = sorted((z - sz * b, z + sz * 2.5))
                cbox(walls, R((xa + xb) / 2, h0 + 7, (za + zb) / 2), (xb - xa, zb - za, 14), rng.choice(STONE[:3]), bevel=0.8)
    with roof_part.xf(Matrix.Translation((-cx, cz, 0)) @ Matrix.Rotation(pi / 2, 4, "Z")):
        roof(roof_part, K["z1"] - K["z0"], half_x, top, slope, 10, 7, rows=11, seed=5)
    # A vent on the roof, on the side facing the lobby.
    x, z = -640, -140
    base = top + slope * (half_x - abs(x - cx)) + ROOF_T - 4
    lathe(trim, [(10, base), (10, base + 30), (16, base + 31), (16, base + 35), (0, base + 41)], STEEL, n=8, smooth=False, center=R(x, 0, z))
    return {"Outside_Kitchen_Walls": walls, "Outside_Kitchen_Trim": trim, "Outside_Kitchen_Roof": roof_part}


# Checks against the forest -----------------------------------------------------------------------------------------------

# Roblox boxes (x0, x1, y0, y1, z0, z1) of the new things that stand out from the old walls.
STANDING_OUT = {
    "dining walls": (-447, 447, 0, 300, 202.5, 797.5),
    "dining porch": (-111, 111, 0, 225, 183, 206.5),
    "dining chimney": (-48, 48, 287, 495, 758, 798),
    "dining eaves": (-454, 454, 268, 480, 194, 806),
    "kitchen walls": (-907, -492.5, 0, 190, -247, 168.5),
    "kitchen chimney": (-496.5, -426, 0, 345, 84, 176),
    "kitchen door": (-496.5, -466, 0, 160, -135, -20),
    "kitchen eaves": (-914, -486, 165, 300, -252, 173),
}


def forest_check(scene):
    """Counts forest points inside the boxes above. Returns the forest's collection, linked into `scene` for previews."""
    with bpy.data.libraries.load(FOREST_BLEND, link=False) as (src, dst):
        dst.scenes = [n for n in src.scenes if n == "TR_LowPolyForest"]
    forest_scene = dst.scenes[0]
    coll = forest_scene.collection.children[0]
    hits = {}
    for obj in coll.all_objects:
        if obj.type != "MESH":
            continue
        m = obj.matrix_world
        for v in obj.data.vertices:
            w = m @ v.co
            x, y, z = -w.x, w.z, w.y
            for name, (x0, x1, y0, y1, z0, z1) in STANDING_OUT.items():
                if x0 < x < x1 and y0 < y < y1 and z0 < z < z1:
                    key = (name, obj.name)
                    hits[key] = hits.get(key, 0) + 1
    print("forest points in the way:", hits or "none")
    scene.collection.children.link(coll)
    return forest_scene


# Scene, export, previews -------------------------------------------------------------------------------------------------


def remove_scene(name):
    scene = bpy.data.scenes.get(name)
    if not scene:
        return
    for obj in list(scene.collection.all_objects):
        data = obj.data
        bpy.data.objects.remove(obj)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)
        elif isinstance(data, (bpy.types.Camera, bpy.types.Light)) and data.users == 0:
            (bpy.data.cameras if isinstance(data, bpy.types.Camera) else bpy.data.lights).remove(data)
    for coll in list(scene.collection.children_recursive):
        bpy.data.collections.remove(coll)
    bpy.data.scenes.remove(scene)


def clear():
    remove_scene(SCENE)
    remove_scene("TR_LowPolyForest")
    for name in ("M_LowPolyOutsides", "M_LowPolyForest"):
        mat = bpy.data.materials.get(name)
        if mat:
            bpy.data.materials.remove(mat)
    for name in ("T_LowPolyOutsides_Palette", "T_LowPolyForest_Palette"):
        image = bpy.data.images.get(name)
        if image:
            bpy.data.images.remove(image)
    world = bpy.data.worlds.get("LPO_World")
    if world:
        bpy.data.worlds.remove(world)


def build():
    clear()
    scene = bpy.data.scenes.new(SCENE)
    collection = bpy.data.collections.new("TR_LowPolyOutsides")
    scene.collection.children.link(collection)
    parts = {}
    parts.update(dining_parts())
    parts.update(kitchen_parts())

    pick = random.Random(23)
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
        report.append(f"{name}: {tris} tris, center ({-center.x:.3f}, {center.z:.3f}, {center.y:.3f}), size {size.x:.1f} x {size.z:.1f} x {size.y:.1f}")
    image = make_palette("T_LowPolyOutsides_Palette")
    material = make_material(image, "M_LowPolyOutsides")
    for obj in objects.values():
        obj.data.materials.append(material)
    print("\n".join(report))
    print(f"meshes: {len(objects)}, total tris: {total}, swatches: {len(swatches)}")

    os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
    window_ = bpy.context.window
    previous = window_.scene
    window_.scene = scene
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
        window_.scene = previous
    bpy.data.libraries.write(BLEND, {scene}, fake_user=True, compress=True)
    print("glb KB:", os.path.getsize(EXPORT) // 1024, "blend KB:", os.path.getsize(BLEND) // 1024)

    forest_check(scene)

    # Previews from the lobby, with the forest; the lobby itself isn't in this scene.
    data = bpy.data.lights.new("LPO_Key", "SUN")
    data.energy = 3.0
    data.angle = 0.05
    data.color = (1.0, 0.92, 0.8)
    sun = bpy.data.objects.new("LPO_Key", data)
    sun.rotation_euler = (0.84, 0, 0.56)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("LPO_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.62, 0.78, 0.92, 1)
        background.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("LPO_Camera")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = 1.22
    cam_data.clip_end = 8000
    cam = bpy.data.objects.new("LPO_Camera", cam_data)
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
        "outsides_south": (R(30, 24, 40), R(0, 120, 300)),
        "outsides_west": (R(10, 24, -5), R(-500, 110, -20)),
        "outsides_east": (R(-20, 24, -5), R(250, 110, 230)),
        "outsides_over": (R(260, 430, -380), R(-330, 60, 300)),
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
