"""Builds the dining room and restaurant kitchen in the same faceted low-poly style as the backyard, and exports them.

Run it inside Blender, like build_backyard.py, whose helpers it borrows. It works in its own scene, saves that to its own
.blend, and leaves the file that's open untouched. Everything is modeled where it goes in the map. The dining room is
written in Blender's axes and the kitchen in Roblox's, through the ROBLOX matrix, so its numbers match the place's.

The kitchen's counters, cabinets, sinks, oven and small items come from kitchen_parts.txt, a list of the original parts:
each one is rebuilt with the same size and color, with chamfered blocks, many-sided cylinders and faceted balls.
Text can't be part of a mesh, so signs and portraits are added as real parts by MapBuilders/RoomsLowPoly.luau.
"""

import os
import random
from math import cos, pi, radians, sin

import bpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/lowpoly"
EXPORT = ASSET_DIR + "/export/TurkeyRace_LowPolyRooms.glb"
BLEND = ASSET_DIR + "/TurkeyRace_LowPolyRooms.blend"
RENDERS = ASSET_DIR + "/renders"
SCENE = "TR_LowPolyRooms"

helpers = {"__name__": "backyard_helpers"}
yard_source = open(ASSET_DIR + "/build_backyard.py", encoding="utf-8").read()
exec(yard_source[: yard_source.rindex("build()")], helpers)
Part, lathe, cbox, box, tube, ico = helpers["Part"], helpers["lathe"], helpers["cbox"], helpers["box"], helpers["tube"], helpers["ico"]
lines, sheet, R = helpers["lines"], helpers["sheet"], helpers["R"]
make_mesh, make_palette, make_material, bounds_of = helpers["make_mesh"], helpers["make_palette"], helpers["make_material"], helpers["bounds_of"]
PIECES = helpers["kit"]["PIECES"]

rng = random.Random(5)


def merge(part, other, matrix=None):
    """Adds a copy of another part's geometry."""
    m = part.m @ (matrix or Matrix.Identity(4))
    offset = len(part.verts)
    part.verts.extend(m @ v for v in other.verts)
    part.faces.extend(([i + offset for i in ids], color, smooth) for ids, color, smooth in other.faces)


def folds(part, u0, u1, depth0, depth1, z0, z1, count, colors):
    """A zigzag sheet, like hanging cloth: the facets catch the light. Runs along X, facing +Y."""
    for k in range(count):
        ua, ub = u0 + (u1 - u0) * k / count, u0 + (u1 - u0) * (k + 1) / count
        da, db = (depth1, depth0) if k % 2 else (depth0, depth1)
        ids = [part.add((ua, da, z0)), part.add((ub, db, z0)), part.add((ub, db, z1)), part.add((ua, da, z1))]
        part.face(list(reversed(ids)), colors[k % 2])


# The dining room ---------------------------------------------------------------------------------------------------------

MID = 500


def wall(p, width):
    """On the origin, with +Y into the room and X along it."""
    box(p, (0, -4, 140), (width + 16, 8, 280), "22483F")
    box(p, (0, -8.6, 143), (width + 22, 1, 286), "EEDFC4")  # the outside
    u = -width / 2 + 18
    while u < width / 2:
        box(p, (u, 0.2, 167), (18, 0.4, 166), "2E5C50")
        u += 36
    box(p, (0, 1, 48), (width, 2, 72), "6A3A22")
    box(p, (0, 1.7, 6), (width, 3.4, 12), "48261A")
    box(p, (0, 2, 84), (width, 4, 5), "D8AE48")
    count = int(width // 62)
    spacing = width / count
    for i in range(count):
        cbox(p, (-width / 2 + (i + 0.5) * spacing, 2.2, 46), (spacing - 14, 1.4, 50), "54301C", bevel=0.6)
    box(p, (0, 0.7, 259), (width, 1.4, 22), "EEE4CC")
    box(p, (0, 1, 247), (width, 2, 3), "D8AE48")
    cbox(p, (0, 2.5, 275), (width, 5, 10), "EEE4CC", bevel=1)


def window(p, glass, u):
    w = 100
    box(glass, (u, 0.8, 159), (w, 1, 134), "DCEFFF")
    for side in (-1, 1):
        box(p, (u + side * (w / 2 + 3), 2, 159), (6, 4, 138), "F0E8D6")
        box(p, (u + side * w / 6, 2.6, 159), (3, 2.4, 134), "F0E8D6")
        lo, hi = u + side * (w / 2 + 2), u + side * (w / 2 + 28)
        folds(p, min(lo, hi), max(lo, hi), 4, 10, 10, 238, 6, ["A02A3C", "842030"])
        cbox(p, ((lo + hi) / 2, 11, 92), (28, 3, 4), "D8AE48", bevel=0.4)
    for z in (137, 182):
        box(p, (u, 2.6, z), (w, 2.4, 3), "F0E8D6")
    cbox(p, (u, 3.5, 91), (w + 18, 7, 4), "F0E8D6", bevel=0.4)
    folds(p, u - 80, u + 80, 6, 12, 232, 256, 14, ["A02A3C", "842030"])
    box(p, (u, 9, 232), (164, 8, 3), "D8AE48")


def chair(p, x, y, yaw):
    with p.xf(Matrix.Translation((x, y, 0)) @ Matrix.Rotation(yaw, 4, "Z")):
        for cx in (-15, 15):
            for cy in (-15, 15):
                lathe(p, [(2.2, 0), (1.7, 24)], "48261A", n=4, smooth=False, center=(cx, cy, 0), cap_start=False)
            cbox(p, (cx * 1.05, 16.5, 59), (3.8, 3.8, 66), "48261A", bevel=0.5)
            ico(p, (cx * 1.05, 16.5, 94), 2.6, "E2B84C", subdiv=0, jitter=0.03)
        cbox(p, (0, 0, 26), (37, 37, 4), "6A3A22", bevel=0.8)
        cbox(p, (0, 0, 29.6), (33, 33, 3.6), "A02A3C", bevel=1.1, edge="842030")
        cbox(p, (0, 16.5, 89), (36, 3.6, 6), "6A3A22", bevel=0.7)
        cbox(p, (0, 16.5, 61), (26, 2.6, 44), "A02A3C", bevel=0.9, edge="842030")


def dining_parts():
    floor = Part()
    sheet(floor, lines(-440, 440, 40), lines(210, 790, 40), lambda x, y: 0.3, lambda x, y: rng.choice(("8E5A34", "7E4E2C", "986440", "744628")))

    rug = Part()

    def rug_color(x, y):
        edge = min(330 - abs(x), 225 - abs(y - MID))
        if edge < 11:
            return rng.choice(("6E1826", "641522"))
        if edge < 22:
            return "D8AE48"
        return rng.choice(("962236", "8A1E30", "A0283C"))

    sheet(rug, lines(-330, 330, 22), lines(MID - 225, MID + 225, 22.5), lambda x, y: 0.7, rug_color)

    shell, glass = Part(), Part()
    frames = {
        "south": Matrix.Translation((0, 220, 0)),
        "north": Matrix.Translation((0, 780, 0)) @ Matrix.Rotation(pi, 4, "Z"),
        "east": Matrix.Translation((430, MID, 0)) @ Matrix.Rotation(pi / 2, 4, "Z"),
        "west": Matrix.Translation((-430, MID, 0)) @ Matrix.Rotation(-pi / 2, 4, "Z"),
    }
    for name, m in frames.items():
        with shell.xf(m):
            wall(shell, 860 if name in ("south", "north") else 560)
    flames = Part()
    for name in ("east", "west"):
        with shell.xf(frames[name]), glass.xf(frames[name]), flames.xf(frames[name]):
            for u in (-140, 140):
                window(shell, glass, u)
            for u in (-46, 46):
                cbox(shell, (u, 1, 130), (7, 1.4, 15), "D8AE48", bevel=0.3)
                box(shell, (u, 5, 127), (2, 10, 2), "D8AE48")
                lathe(shell, [(1.7, 127), (1.7, 138)], "FAF0D8", n=5, smooth=False, center=(u, 10, 0))
                ico(flames, (u, 10, 140.5), 2.2, "FFD76A", subdiv=0, jitter=0.05)
            # Gold frames; the pictures and name plates are added in the game.
            for u in (0, -249):
                box(shell, (u, 1.2, 170), (54, 2.4, 66), "D8AE48")
    box(shell, (0, 500, 283), (884, 584, 6), "EEE4CC")
    for y in range(332, 700, 112):
        box(shell, (0, y, 276.5), (860, 10, 7), "DCCDAC")
    for x in (-287, -143, 0, 143, 287):
        box(shell, (x, 500, 276.5), (10, 560, 7), "DCCDAC")

    # The table. Roblox has a gap across it at x -60 to -48, on the far side (z 570 to 640), which is Blender x 48 to 60.
    table = Part()
    cloth = ("F2DDB0", "EAD2A2", "E0C694", "F8E6BE")

    def cloth_color(x, y):
        return rng.choice(cloth)

    height = lambda x, y: 40
    sheet(table, lines(-210, 48, 28), lines(360, 640, 28), height, cloth_color)
    sheet(table, lines(60, 210, 28), lines(360, 640, 28), height, cloth_color)
    sheet(table, lines(48, 60, 12), lines(360, 570, 28), height, cloth_color)
    # Dark edges on the gap, so it's easy to see coming.
    for x in (47.5, 60.5):
        box(table, (x, 605, 38), (1, 70, 4), "48261A")
    box(table, (54, 569.5, 38), (13, 1, 4), "48261A")
    for x in (45, 63):
        box(table, (x, 605, 40.05), (4, 70, 0.1), "A8742E")
    skirt = ["E8D2A4", "CDB487"]
    with table.xf(Matrix.Translation((0, 360, 0)) @ Matrix.Rotation(pi, 4, "Z")):
        folds(table, -210, 210, 0.5, 3.5, 20, 40, 42, skirt)
    with table.xf(Matrix.Translation((-105, 640, 0))):
        folds(table, -105, 153, 0.5, 3.5, 20, 40, 26, skirt)
    with table.xf(Matrix.Translation((135, 640, 0))):
        folds(table, -75, 75, 0.5, 3.5, 20, 40, 15, skirt)
    with table.xf(Matrix.Translation((210, 500, 0)) @ Matrix.Rotation(-pi / 2, 4, "Z")):
        folds(table, -140, 140, 0.5, 3.5, 20, 40, 28, skirt)
    with table.xf(Matrix.Translation((-210, 500, 0)) @ Matrix.Rotation(pi / 2, 4, "Z")):
        folds(table, -140, 140, 0.5, 3.5, 20, 40, 28, skirt)
    for x in (-195, 195):
        for y in (375, 625):
            lathe(table, [(11, 0), (9, 3), (6, 7), (10, 12), (6, 18), (7, 30), (7, 38)], lambda c, i, j: "D8AE48" if i == 0 else "48261A", n=6, smooth=False, center=(x, y, 0))
    cbox(table, (0, 500, 42), (280, 140, 4.1), "A62A40", bevel=0.5, edge="842030")
    for sign in (-1, 1):
        box(table, (0, 500 + sign * 56, 44.08), (280, 6, 0.2), "E2B84C")
        box(table, (0, 500 + sign * 46, 44.08), (280, 2, 0.2), "E2B84C")
    # The serving platter and the chef's cake stand, whose top is his spot in the place.
    middle = (0, 500, 0)
    lathe(table, [(0, 44), (42, 44), (48, 45.4), (48, 46), (40, 46), (0, 45.2)], "E8E6DE", n=14, smooth=False, center=middle)
    lathe(table, [(20, 46), (19, 47.5), (6, 49), (6.5, 57), (31, 57.2), (33, 58.4), (28, 59.4), (0, 59.4)], lambda c, i, j: "E2B84C" if i == 3 else "C8CDD4", n=10, smooth=False, center=middle)
    # The roast, and a pie to balance it.
    roast = (92, 500, 0)
    lathe(table, [(0, 44), (36, 44), (42, 45.4), (42, 46), (0, 45.6)], "E8E6DE", n=12, smooth=False, center=roast)
    ico(table, (92, 500, 62), 25, ["C87430", "B8662A", "D4843A"], subdiv=1, jitter=0.06, squash=0.85, seed=4)
    for side in (-1, 1):
        tube(table, [(92 + side * 14, 485, 66), (92 + side * 18, 468, 74), (92 + side * 18, 462, 84)], [7, 4.5, 2], "B8662A", n=6, smooth=False)
        ico(table, (92 + side * 18, 461, 86), 3, "F6EEDC", subdiv=0, jitter=0.05)
    lathe(table, [(0, 44), (36, 44), (42, 45.4), (42, 46), (0, 45.6)], "E8E6DE", n=12, smooth=False, center=(-92, 500, 0))
    merge(table, PIECES["Pie"](), Matrix.Translation((-92, 500, 46)) @ Matrix.Scale(4.2, 4))
    # Candelabras.
    for y in (450, 550):
        lathe(table, [(9, 44), (5, 46), (1.6, 48), (1.6, 68)], "E2B84C", n=6, smooth=False, center=(0, y, 0))
        box(table, (0, y, 68), (30, 2, 2), "E2B84C")
        for x, h in ((-15, 69), (0, 74), (15, 69)):
            lathe(table, [(1.7, h), (1.7, h + 11)], "FAF0D8", n=5, smooth=False, center=(x, y, 0))
            ico(flames, (x, y, h + 13), 2.2, "FFD76A", subdiv=0, jitter=0.05, squash=1.5)

    # The chandelier, well above the chef's hat.
    light = Part()
    at = V((0, MID, 0))
    tube(light, [at + V((0, 0, 280)), at + V((0, 0, 240))], 1.6, "E2B84C", n=4, smooth=False)
    ico(light, at + V((0, 0, 232)), 12, "E2B84C", subdiv=1, jitter=0.03, squash=0.9)
    ico(light, at + V((0, 0, 215)), 6, "D2A63E", subdiv=0, jitter=0.03)
    ring_radius = 74
    ring = [at + V((cos(k * pi / 8) * ring_radius, sin(k * pi / 8) * ring_radius, 222)) for k in range(17)]
    tube(light, ring, 1.7, "E2B84C", n=4, smooth=False)
    for k in range(12):
        a = k * pi / 6
        x, y = cos(a) * ring_radius, sin(a) * ring_radius
        tube(light, [at + V((x * 0.1, y * 0.1, 230)), at + V((x, y, 222))], 1.2, "E2B84C", n=4, smooth=False)
        lathe(light, [(1.8, 223), (1.8, 234)], "FAF0D8", n=5, smooth=False, center=at + V((x, y, 0)))
        ico(flames, at + V((x, y, 237.5)), 2.4, "FFD76A", subdiv=0, jitter=0.05, squash=1.5)
        ico(light, at + V((x, y, 216.5)), 2, "D8ECFA", subdiv=0, jitter=0.05, squash=1.6)

    chairs = Part()
    for x in (-150, -50, 50, 150):
        chair(chairs, x, 336, 0)
        chair(chairs, x, 664, pi)
    chair(chairs, -234, MID, -pi / 2)
    chair(chairs, 234, MID, pi / 2)

    room, fire = Part(), Part()
    with room.xf(frames["north"]), fire.xf(frames["north"]), flames.xf(frames["north"]):
        cbox(room, (0, 9, 59), (200, 18, 118), "E0DCD2", bevel=1.5)
        box(room, (0, 18.4, 39), (124, 2, 78), "221C1C")
        box(room, (0, 22, 2), (232, 44, 4), "BEB9AE")
        cbox(room, (0, 14, 122), (226, 32, 9), "6A3A22", bevel=1.2)
        cbox(room, (0, 14, 127.5), (232, 34, 3), "48261A", bevel=0.5)
        for side in (-1, 1):
            box(room, (side * 84, 20, 59), (16, 6, 118), "F0ECE2")
            lathe(room, [(2, 128), (2, 144)], "FAF0D8", n=5, smooth=False, center=(side * 92, 14, 0))
            ico(flames, (side * 92, 14, 147), 2.6, "FFD76A", subdiv=0, jitter=0.05, squash=1.5)
        for x in (-30, 0, 30):
            tube(room, [(x - 18, 22, 12), (x + 18, 22, 12)], 5, "54341C", n=5, smooth=False)
        for x, h, r in ((-32, 22, 13), (0, 34, 16), (32, 22, 13), (-14, 18, 10), (16, 20, 11)):
            ico(fire, (x, 23, 12 + h * 0.55), r, "FF8A28", subdiv=0, jitter=0.15, squash=1.5, seed=x & 255)
        box(room, (0, 1.2, 196), (114, 2.4, 82), "D8AE48")
    with room.xf(frames["south"]):
        box(room, (0, 1.5, 88), (156, 3, 176), "F0E8D6")
        cbox(room, (0, 4, 181), (176, 8, 10), "D8AE48", bevel=1)
        for side in (-1, 1):
            box(room, (side * 34, 4, 80), (66, 3, 160), "6A3A22")
            for z in (44, 118):
                cbox(room, (side * 34, 6, z), (46, 1.2, 56), "54301C", bevel=0.5)
            ico(room, (side * 8, 7, 76), 3, "E2B84C", subdiv=0, jitter=0.03)
            # China cabinet.
            cbox(room, (side * 250, 15, 95), (124, 30, 190), "6A3A22", bevel=1.5)
            cbox(room, (side * 250, 16, 195), (136, 36, 10), "48261A", bevel=1.2)
            box(room, (side * 250, 30.4, 132), (106, 1, 116), "E2D6BC")
            for z in (88, 126, 164):
                box(room, (side * 250, 31, z - 15), (106, 1.4, 2.4), "48261A")
                for px in (-38, -13, 13, 38):
                    with room.xf(Matrix.Translation((side * 250 + px, 31.6, z)) @ Matrix.Rotation(-pi / 2, 4, "X")):
                        lathe(room, [(11, 0), (11, 0.6), (5, 0.9), (0, 0.9)], lambda c, i, j: "A82838" if i >= 2 else "F6F2E8", n=8, smooth=False)
            cbox(room, (side * 250, 31, 36), (104, 1.4, 54), "48261A", bevel=0.5)
    with room.xf(frames["north"]):
        for side in (-1, 1):
            u = side * 280
            cbox(room, (u, 15, 27), (130, 30, 42), "6A3A22", bevel=1.2)
            cbox(room, (u, 16, 49.5), (136, 34, 3), "E0DCD2", bevel=0.4)
            for ox in (-42, 0, 42):
                cbox(room, (u + ox, 30.6, 28), (36, 1.4, 28), "48261A", bevel=0.4)
                ico(room, (u + ox, 32, 28), 1.8, "E2B84C", subdiv=0, jitter=0.03)
            ico(room, (u, 16, 63), 12, "C8CDD4", subdiv=1, jitter=0.03)
        cbox(room, (-152, 11, 17), (38, 20, 34), "48261A", bevel=1)
        cbox(room, (-152, 10, 86), (28, 15, 104), "6A3A22", bevel=1)
        cbox(room, (-152, 11, 160), (38, 20, 44), "48261A", bevel=1)
        with room.xf(Matrix.Translation((-152, 21.5, 160)) @ Matrix.Rotation(-pi / 2, 4, "X")):
            lathe(room, [(15, 0), (15, 0.8), (0, 0.8)], "F6F2E8", n=10, smooth=False)
            box(room, (0, 0.95, 4.5), (1.6, 0.1, 9), "1E1E22")
            box(room, (5.5, 0.95, 0), (11, 0.1, 1.2), "1E1E22")
    for x, y in ((150, 754), (-392, 254), (392, 254), (-392, 746), (392, 746)):
        lathe(room, [(13, 0), (17, 24), (19, 27), (19, 30), (14, 30)], lambda c, i, j: "E2B84C" if i >= 2 else "E0D8C4", n=7, smooth=False, center=(x, y, 0))
        ico(room, (x, y, 50), 21, ["4E9A52", "5CAA5C", "438C48"], subdiv=1, jitter=0.15, seed=int(x) & 255)
        for k in range(5):
            a = k * 2 * pi / 5
            ico(room, (x + cos(a) * 18, y + sin(a) * 18, 44 + k % 2 * 12), 13, ["5CAA5C", "6CB866", "4E9A52"], subdiv=0, jitter=0.15, seed=k)

    return {
        "Dining_Floor": floor,
        "Dining_Rug": rug,
        "Dining_Shell": shell,
        "Dining_Windows_Glow": glass,
        "Dining_Table": table,
        "Dining_Chandelier": light,
        "Dining_Candles_Glow": flames,
        "Dining_Chairs": chairs,
        "Dining_Furniture": room,
        "Dining_Fire_Glow": fire,
    }


# The kitchen ---------------------------------------------------------------------------------------------------------------

# Everything below is in Roblox coordinates and axes: (x, y, z) with Y up.
ROBLOX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

STEEL, STEEL_LIGHT, STEEL_DARK = "9DA3A9", "B8BDC2", "686E74"
RUBBER = "26262A"
COPPER = "C4703E"
CREAM = "FAF4E2"
WOOD = "B07C4A"
RED, YELLOW = "CD2828", "F5C828"
STATION = V((-700, 0, 0))


def look(position, target):
    """A frame on `position` looking at `target`: into the room is -Z, as with CFrame.lookAt."""
    position, target = V(position), V(target)
    forward = (target - position).normalized()
    right = forward.cross(V((0, 1, 0))).normalized()
    up = right.cross(forward)
    return Matrix(((right.x, up.x, -forward.x, position.x), (right.y, up.y, -forward.y, position.y), (right.z, up.z, -forward.z, position.z), (0, 0, 0, 1)))


def at(x, y, z, yaw=0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(radians(yaw), 4, "Y")


def post(p, height, diameter, position, color, n=8):
    position = V(position)
    lathe(p, [(diameter / 2, -height / 2), (diameter / 2, height / 2)], color, n=n, smooth=False, center=position, axis="Y")


def ball(p, diameter, position, colors, subdiv=0, jitter=0.05, seed=1):
    ico(p, position, diameter / 2, colors, subdiv=subdiv, jitter=jitter, seed=seed)


def pipe(p, a, b, diameter, color, n=6):
    tube(p, [a, b], diameter / 2, color, n=n, smooth=False)


def faceted_top(p, x0, x1, z0, z1, y, colors, cell):
    """A flat surface broken into triangles of slightly different shades, facing up."""
    below = p.m @ V(((x0 + x1) / 2, y - 50, (z0 + z1) / 2))
    xs, zs = lines(x0, x1, cell), lines(z0, z1, cell)
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            a, b, c, d = (xs[i], zs[j]), (xs[i + 1], zs[j]), (xs[i + 1], zs[j + 1]), (xs[i], zs[j + 1])
            for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
                ids = [p.add((u, y, v)) for u, v in tri]
                p.face_out(ids, rng.choice(colors), below)


def tile_wall(p, frame, width, high, colors):
    """A wall of tiles, each two triangles in slightly different shades, on the frame's plane, facing into the room."""
    with p.xf(frame):
        behind = p.m @ V((0, high / 2, 40))
        columns, rows = max(1, round(width / 32)), max(1, round(high / 14))
        for i in range(columns):
            for j in range(rows):
                xa, xb = -width / 2 + width * i / columns, -width / 2 + width * (i + 1) / columns
                ya, yb = high * j / rows, high * (j + 1) / rows
                a, b, c, d = (xa, ya), (xb, ya), (xb, yb), (xa, yb)
                for tri in ((a, b, c), (a, c, d)):
                    ids = [p.add((u, v, -0.1)) for u, v in tri]
                    p.face_out(ids, rng.choice(colors), behind)


def add_original_part(p, line):
    """Rebuilds one part from kitchen_parts.txt, keeping its size, place and color."""
    shape, x, y, z, rx, ry, rz, sx, sy, sz, color = line
    m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(radians(ry), 4, "Y") @ Matrix.Rotation(radians(rx), 4, "X") @ Matrix.Rotation(radians(rz), 4, "Z")
    with p.xf(m):
        if shape == "O":
            ico(p, (0, 0, 0), sy / 2, color, subdiv=1 if sy >= 5 else 0, jitter=0.04, seed=int(abs(x * 3 + z)))
        elif shape == "C":
            sides = 12 if sy >= 12 else 8 if sy >= 3 else 6
            lathe(p, [(sy / 2, -sx / 2), (sy / 2, sx / 2)], color, n=sides, smooth=False, axis="X")
        else:
            thin = min(sx, sy, sz)
            if thin < 1:
                box(p, (0, 0, 0), (sx, sy, sz), color)
            else:
                cbox(p, (0, 0, 0), (sx, sy, sz), color, bevel=min(0.6, thin * 0.2))


def hanging_pan(p, position, diameter, color, turned):
    with p.xf(Matrix.Translation(position) @ Matrix.Rotation(turned, 4, "Y")):
        box(p, (0, -3, 0), (0.8, 6, 0.8), STEEL_DARK)
        box(p, (0, -11, 0), (1.4, 12, 0.8), RUBBER)
        center = V((0, -17 - diameter / 2, 0))
        lathe(p, [(0, -0.2), (diameter / 2, -0.2), (diameter / 2 * 0.9, 1.4), (0, 1.4)], color, n=8, smooth=False, center=center, axis="Z")


def pot_rack(p, start, end):
    start, end = V(start), V(end)
    pipe(p, start, end, 2.2, STEEL_DARK, n=4)
    for t in (0.1, 0.9):
        top = start.lerp(end, t)
        box(p, (top.x, (170 + top.y) / 2, top.z), (1, 170 - top.y, 1), STEEL_DARK)
    along = end - start
    from math import atan2

    turned = atan2(along.x, along.z) + pi / 2
    count = 7
    for i in range(1, count + 1):
        hanging_pan(p, start.lerp(end, i / (count + 1)), 8 + (i * 3) % 7, COPPER if i % 2 == 0 else RUBBER, turned)


def shelves(p, frame, x, width, seed):
    rand = random.Random(seed)
    with p.xf(frame):
        for y in (112, 142):
            cbox(p, (x, y, -8), (width, 1.6, 15), STEEL_LIGHT, bevel=0.3)
            cx = x - width / 2 + 9
            while cx < x + width / 2 - 7:
                spot = V((cx, y + 0.8, -8))
                kind = rand.randint(1, 4)
                if kind == 1:
                    size = rand.uniform(11, 15)
                    post(p, size, size, spot + V((0, size / 2, 0)), STEEL_LIGHT if rand.random() < 0.5 else COPPER)
                    post(p, 1, size + 1, spot + V((0, size + 0.5, 0)), STEEL_DARK)
                    step = size + 3
                elif kind == 2:
                    color = rand.choice(("CD3C28", "EBAF3C", "6E9646"))
                    post(p, 11, 6.5, spot + V((0, 5.5, 0)), color, n=6)
                    post(p, 1.4, 7, spot + V((0, 11.7, 0)), STEEL_DARK, n=6)
                    step = 9
                elif kind == 3:
                    for level in range(4):
                        post(p, 2.2, 13 - level, spot + V((0, 1.1 + level * 2.2, 0)), CREAM)
                    step = 16
                else:
                    color = RED if rand.random() < 0.5 else "F0E1BE"
                    cbox(p, spot + V((0, 7.5, 0)), (11, 15, 9), color, bevel=1.2)
                    step = 14
                cx += step


def kitchen_parts():
    # The floor, in red quarry tile, with each 48-stud tile two triangles.
    floor = Part()
    floor.m = ROBLOX.copy()
    below = ROBLOX @ V((-700, -50, -40))
    for i in range(9):
        for j in range(9):
            # The walls are at x -500 and z 160, so the last row and column are narrower.
            x0, z0 = -900 + i * 48, -240 + j * 48
            x1, z1 = min(x0 + 48, -500), min(z0 + 48, 160)
            odd = (i + j) % 2 == 1
            shades = ("96402E", "A04632", "8C3A2A") if odd else ("7E3226", "88382A", "742E22")
            a, b, c, d = (x0, z0), (x1, z0), (x1, z1), (x0, z1)
            for tri in ((a, b, c), (a, c, d)) if odd else ((a, b, d), (b, c, d)):
                ids = [floor.add((u, 0.45, v)) for u, v in tri]
                floor.face_out(ids, rng.choice(shades), below)

    # Walls, ceiling and the outside of the building.
    walls = Part()
    walls.m = ROBLOX.copy()
    tiles = ("ECEEEA", "E2E4E0", "F4F6F2")
    box(walls, (-704, 85, 156), (392, 170, 8), "E8EAE6")
    box(walls, (-700, 85, -236), (400, 170, 8), "E8EAE6")
    box(walls, (-504, 85, -72), (8, 170, 336), "E8EAE6")
    box(walls, (-896, 85, -40), (8, 170, 400), "E8EAE6")
    tile_wall(walls, look((-704, 0, 151.9), (-704, 0, 0)), 392, 170, tiles)
    tile_wall(walls, look((-700, 0, -231.9), (-700, 0, 0)), 400, 170, tiles)
    tile_wall(walls, look((-508.1, 0, -72), (-700, 0, -72)), 336, 170, tiles)
    tile_wall(walls, look((-891.9, 0, -40), (-700, 0, -40)), 400, 170, tiles)
    outside = "EEE1C8"
    box(walls, (-704, 88, 160.6), (404, 176, 1), outside)
    box(walls, (-700, 88, -240.6), (404, 176, 1), outside)
    box(walls, (-900.6, 88, -40), (1, 176, 404), outside)
    box(walls, (-499.4, 88, -72), (1, 176, 336), outside)
    box(walls, (-700, 172, -40), (404, 4, 404), "E0E0DA")
    pipe(walls, (-888, 156, -222), (-516, 156, -222), 18, STEEL, n=8)
    for x in (-820, -700, -580):
        pipe(walls, (x - 1.5, 156, -222), (x + 1.5, 156, -222), 21, STEEL_DARK, n=8)

    lights = Part()
    lights.m = ROBLOX.copy()
    for x in (-825, -575):
        for z in (-190, -90, 10, 110):
            box(lights, (x, 169.4, z), (90, 1.2, 16), "FAFAF0")
    for z in (-200, 110):
        box(lights, (-700, 169.4, z), (90, 1.2, 16), "FAFAF0")
    for z in (-44, 44):
        box(lights, (-700, 148.3, z), (170, 0.6, 7), "FFF5DC")

    # The original parts: counters, cabinet doors, sinks, oven and small items.
    groups = {"Counters": Part(), "Doors": Part(), "Fittings": Part(), "Sinks": Part(), "Oven": Part(), "Items": Part()}
    for part in groups.values():
        part.m = ROBLOX.copy()
    # Without real metal to reflect things, the original steel colors come out nearly white, so they're darkened.
    darker = {"CCD0D4": STEEL_LIGHT, "ACB2B8": STEEL, "DBDBE3": "C4C8CE"}
    steel_top = ("B8BDC2", "AEB3B8", "C2C7CC", "A8ADB2")
    wood_top = ("B07C4A", "A6723F", "BC8656", "9E6C3C")
    with open(ASSET_DIR + "/kitchen_parts.txt", encoding="utf-8") as f:
        for raw in f:
            if raw.startswith("#") or not raw.strip():
                continue
            fields = raw.split()
            group, name, shape = fields[0], fields[1], fields[2]
            numbers = [float(v) for v in fields[3:12]]
            color = darker.get(fields[12], fields[12])
            x, y, z, rx, ry, rz, sx, sy, sz = numbers
            if group == "Counters" and name in ("Top", "IslandTop"):
                # The racing surface: exactly where the solid part's top is, broken into facets.
                top = groups["Counters"]
                box(top, (x, y - 0.02, z), (sx, sy, sz), color)
                faceted_top(top, x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2, y + sy / 2, wood_top if name == "IslandTop" else steel_top, 22)
                continue
            if group == "Decor" and name in ("Door", "Handle"):
                target = groups["Doors"]
            elif group in ("Decor", "Ground"):
                target = groups["Fittings"]
            elif group == "Fixtures":
                target = groups["Sinks"]
            elif group == "Oven":
                target = groups["Oven"]
            elif group == "Counters":
                target = groups["Counters"]
            else:
                target = groups["Items"]
            add_original_part(target, (shape, x, y, z, rx, ry, rz, sx, sy, sz, color))
    # Yellow lines along the inside of the counters, so the edge of the track is easy to see.
    lines_part = groups["Counters"]
    for center, size in (((-700, 40.08, 109), (296, 0.1, 1.6)), ((-700, 40.08, -109), (296, 0.1, 1.6)), ((-849, 40.08, 0), (1.6, 0.1, 218)), ((-551, 40.08, 0), (1.6, 0.1, 218))):
        box(lines_part, center, size, YELLOW)

    # Hanging pots over the lanes, and shelves full of stock.
    racks = Part()
    racks.m = ROBLOX.copy()
    pot_rack(racks, (-860, 106, 130), (-770, 106, 130))
    pot_rack(racks, (-600, 106, 130), (-540, 106, 130))
    pot_rack(racks, (-760, 106, -130), (-640, 106, -130))
    pot_rack(racks, (-530, 106, -90), (-530, 106, 0))
    pot_rack(racks, (-870, 106, -110), (-870, 106, -40))
    north = look((-700, 0, 152), (-700, 0, 0))
    shelves(racks, north, 130, 120, 1)
    shelves(racks, north, -130, 100, 2)
    shelves(racks, look((-508, 0, -28), (-700, 0, -28)), 0, 240, 3)
    west = look((-892, 0, 0), (0, 0, 0))
    shelves(racks, west, -125, 90, 4)
    shelves(racks, west, 110, 90, 5)

    # The pass: the window food goes out through, on the west wall.
    pass_part, warm, heat = Part(), Part(), Part()
    for part in (pass_part, warm, heat):
        part.m = ROBLOX @ west
    width = 124
    box(warm, (0, 92, -0.6), (width, 52, 0.8), "EBC387")
    box(pass_part, (0, 120, -1.5), (width + 8, 5, 3), STEEL_DARK)
    for side in (-1, 1):
        box(pass_part, (side * (width / 2 + 2), 92, -1.5), (4, 52, 3), STEEL_DARK)
    cbox(pass_part, (0, 64.5, -8), (width + 14, 3, 16), STEEL_LIGHT, bevel=0.4)
    foods = ("BE6E32", "E6AA3C", "78AA46", "CD4628", "BE6E32")
    for i, color in enumerate(foods):
        center = V((-48 + i * 24, 66.6, -8))
        post(pass_part, 1.2, 14, center, CREAM, n=8)
        ball(pass_part, 8, center + V((0, 3, 0)), color, subdiv=0, seed=i)
    for x in (-36, -12, 12, 36):
        box(pass_part, (x, 111, -8), (0.7, 12, 0.7), RUBBER)
        post(pass_part, 6, 9, (x, 103, -8), RED, n=6)
        ball(heat, 5, (x, 100, -8), "FF5028", subdiv=0, seed=x & 255)
    box(pass_part, (0, 130, -1.4), (width, 2.4, 1.6), STEEL_DARK)
    for i in range(1, 8):
        box(pass_part, (-54 + i * 13.5 + (i % 2) * 1.5, 123 - (i % 3), -2.4), (9, 13, 0.3), CREAM)

    # The cook station in the middle, with the chef on top.
    station = Part()
    station.m = ROBLOX @ Matrix.Translation(STATION)
    flames = Part()
    flames.m = ROBLOX @ Matrix.Translation(STATION)
    cbox(station, (0, 19, 0), (192, 34, 118), STEEL, bevel=1.2)
    box(station, (0, 1.5, 0), (186, 3, 112), RUBBER)
    cbox(station, (0, 37.5, 0), (200, 3, 126), STEEL_LIGHT, bevel=0.6)
    for side in (-1, 1):
        for x in range(-80, 81, 32):
            cbox(station, (x, 20, side * 59.4), (29, 26, 1), STEEL_LIGHT, bevel=0.3)
            box(station, (x, 29, side * 60.2), (19, 1.4, 1.2), RUBBER)
        cbox(station, (side * 96.4, 20, 0), (1, 26, 96), STEEL_LIGHT, bevel=0.3)
        box(station, (side * 97.2, 29, 0), (1.2, 1.4, 70), RUBBER)
    for z in (-30, 30):
        base = V((-72, 39, z))
        post(station, 1, 34, base + V((0, 0.5, 0)), RUBBER, n=10)
        post(flames, 1.4, 28, base + V((0, 1.2, 0)), "FF8228", n=10)
        post(station, 24, 30, base + V((0, 14, 0)), COPPER, n=10)
        post(station, 2, 32, base + V((0, 26, 0)), STEEL_LIGHT, n=10)
        post(station, 1, 28, base + V((0, 26.4, 0)), "E2963C", n=10)
    box(station, (72, 39.7, 0), (50, 1.4, 84), "282626")
    for ox, oz in ((58, -26), (84, -18), (62, 8), (86, 22), (62, 30)):
        post(station, 1.6, 11, (ox, 41.2, oz), "784224", n=8)
    box(station, (-30, 43, 40), (24, 9, 20), WOOD)
    for x in (-7, 0, 7):
        for z in (-5, 5):
            ball(station, 7.5, (-30 + x, 49, 40 + z), "E12D23", subdiv=0, seed=x + z)
    for level in range(4):
        post(station, 2.4, 18, (30, 40.2 + level * 2.5, 42), "DCA050", n=8)
        post(station, 2.5, 14, (30, 40.2 + level * 2.5, 42), "EB8232", n=8)
    for level in range(5):
        post(station, 1.4, 16, (30, 40 + level * 1.6, -42), RUBBER, n=8)
    cbox(station, (0, 158, 0), (214, 16, 140), STEEL_LIGHT, bevel=1.5)
    cbox(station, (0, 150, 0), (218, 3, 144), STEEL_DARK, bevel=0.5)
    for x in (-96, 96):
        for z in (-60, 60):
            box(station, (x, 168, z), (2, 4, 2), STEEL_DARK)

    # Along the south wall, and things on the floor.
    south = Part()
    south.m = ROBLOX.copy()
    walk = look((-700, 0, -232), (-700, 0, 0))
    with south.xf(walk):
        cbox(south, (0, 70, -2), (150, 140, 4), STEEL, bevel=0.6)
        cbox(south, (0, 58, -5), (96, 116, 3), STEEL_LIGHT, bevel=0.6)
        cbox(south, (36, 60, -8), (3, 26, 4), RUBBER, bevel=0.5)
        for y in (22, 96):
            box(south, (-46, y, -7), (10, 8, 2), STEEL_DARK)
    with south.xf(look((-597, 0, -232), (-597, 0, 0))):
        box(south, (0, 118, -0.8), (50, 46, 1.4), WOOD)
    base = V((-820, 0, -214))
    for x in (-44, 44):
        for z in (-14, 14):
            post(south, 120, 2.4, base + V((x, 60, z)), STEEL_DARK, n=4)
    rand = random.Random(7)
    for y in (14, 48, 82, 116):
        cbox(south, base + V((0, y, 0)), (92, 1.6, 30), STEEL_LIGHT, bevel=0.3)
        for x in range(-32, 33, 21):
            if y < 116:
                cbox(south, base + V((x, y + 10.8, 0)), (17, 20, 20), rand.choice(("F0E1BE", "C8A06E")), bevel=2.5)
            else:
                post(south, 14, 13, base + V((x, y + 7.8, 0)), STEEL, n=8)
    extinguisher = V((-632, 42, -226))
    post(south, 20, 7, extinguisher, RED, n=8)
    post(south, 3, 3, extinguisher + V((0, 11.5, 0)), RUBBER, n=6)
    box(south, extinguisher + V((0, 13.5, 0)), (6, 1, 2), RUBBER)
    # Mats and drains.
    for z in (80, -80):
        faceted_top(south, -807, -593, z - 13, z + 13, 0.8, ("26262A", "2E2E32", "222226"), 22)
    for x in (-828, -572):
        box(south, (x, 0.6, 0), (22, 0.4, 150), "46484C")
    bucket = V((-826, 0, 88))
    post(south, 18, 22, bucket + V((0, 11, 0)), YELLOW, n=8)
    post(south, 1, 18, bucket + V((0, 20, 0)), "789696", n=8)
    pipe(south, bucket + V((2, 14, 0)), bucket + V((14, 66, -6)), 2, "BEA06E", n=4)
    for level in range(3):
        cbox(south, (-572, 7 + level * 13.4, 86 - level), (20, 13, 20), "2858AA" if level == 1 else RED, bevel=0.8)
    cbox(south, (-572, 7, 62), (20, 13, 20), "2858AA", bevel=0.8)
    post(south, 34, 26, (-572, 17, -86), "464A50", n=8)
    post(south, 3, 29, (-572, 35.5, -86), "32363C", n=8)
    rack = V((-826, 0, -84))
    for x in (-13, 13):
        for z in (-13, 13):
            post(south, 66, 1.6, rack + V((x, 33, z)), STEEL_DARK, n=4)
    for level in range(6):
        y = 8 + level * 11
        box(south, rack + V((0, y, 0)), (26, 1, 26), STEEL_LIGHT)
        if level % 2 == 0:
            for x in (-6, 6):
                post(south, 3.4, 9, rack + V((x, y + 2.2, 0)), "D6A05A", n=6)

    return {
        "Kitchen_Floor": floor,
        "Kitchen_Walls": walls,
        "Kitchen_Lights_Glow": lights,
        "Kitchen_Counters": groups["Counters"],
        "Kitchen_Doors": groups["Doors"],
        "Kitchen_Fittings": groups["Fittings"],
        "Kitchen_Sinks": groups["Sinks"],
        "Kitchen_Oven": groups["Oven"],
        "Kitchen_Items": groups["Items"],
        "Kitchen_Racks": racks,
        "Kitchen_Pass": pass_part,
        "Kitchen_Pass_Glow": warm,
        "Kitchen_Heat_Glow": heat,
        "Kitchen_Station": station,
        "Kitchen_Flames_Glow": flames,
        "Kitchen_South": south,
    }


# Scene, preview, export ------------------------------------------------------------------------------------------------------

SHELL = {"Dining_Floor", "Dining_Rug", "Dining_Shell", "Kitchen_Floor", "Kitchen_Walls"}
GLOW_PREVIEW = {
    "Dining_Windows_Glow": ("DCEFFF", 1.4),
    "Dining_Candles_Glow": ("FFD76A", 2.5),
    "Dining_Fire_Glow": ("FF8A28", 3.0),
    "Kitchen_Lights_Glow": ("FFFFF4", 1.5),
    "Kitchen_Pass_Glow": ("EBC387", 1.0),
    "Kitchen_Heat_Glow": ("FF5028", 3.0),
    "Kitchen_Flames_Glow": ("FF8228", 3.0),
}


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
    for name in ("M_LowPolyRooms", "LPR_Preview_Glow"):
        mat = bpy.data.materials.get(name)
        if mat:
            bpy.data.materials.remove(mat)
    image = bpy.data.images.get("T_LowPolyRooms_Palette")
    if image:
        bpy.data.images.remove(image)


def build():
    clear()
    scene = bpy.data.scenes.new(SCENE)
    collection = bpy.data.collections.new("TR_LowPolyRooms")
    scene.collection.children.link(collection)

    parts = {}
    parts.update(dining_parts())
    parts.update(kitchen_parts())

    pick = random.Random(21)
    objects = {}
    report = []
    total = 0
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
        report.append(f"{name}: {tris} tris, center ({-center.x:.2f}, {center.z:.2f}, {center.y:.2f}), size {size.x:.0f} x {size.z:.0f} x {size.y:.0f}")
    image = make_palette("T_LowPolyRooms_Palette")
    material = make_material(image, "M_LowPolyRooms")
    for obj in objects.values():
        obj.data.materials.append(material)
    print("\n".join(report))
    print(f"meshes: {len(objects)}, total tris: {total}, swatches: {len(helpers['swatches'])}")

    # Export first, with the plain palette on everything.
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

    # Preview renders. Glowing pieces get an emission look here; in the game they're Neon.
    for name, (hex_value, strength) in GLOW_PREVIEW.items():
        glow = bpy.data.materials.new("LPR_Preview_Glow")
        glow.use_nodes = True
        nodes = glow.node_tree.nodes
        nodes.clear()
        emission = nodes.new("ShaderNodeEmission")
        rgb = [int(hex_value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
        emission.inputs["Color"].default_value = (*[c**2.2 for c in rgb], 1)
        emission.inputs["Strength"].default_value = strength
        output = nodes.new("ShaderNodeOutputMaterial")
        glow.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
        objects[name].data.materials[0] = glow
    for name in SHELL:
        objects[name].visible_shadow = False
    data = bpy.data.lights.new("LPR_Key", "SUN")
    data.energy = 3.0
    data.angle = 0.05
    data.color = (1.0, 0.92, 0.8)
    sun = bpy.data.objects.new("LPR_Key", data)
    sun.rotation_euler = (0.84, 0, 0.56)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.get("LPR_World") or bpy.data.worlds.new("LPR_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.75, 0.82, 0.92, 1)
        background.inputs[1].default_value = 1.0
    cam_data = bpy.data.cameras.new("LPR_Camera")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = 1.22
    cam_data.clip_end = 8000
    cam = bpy.data.objects.new("LPR_Camera", cam_data)
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
        "dining_over": (R(-400, 260, 250), R(120, 40, 560)),
        "dining_gap": (R(30, 64, 605), R(-120, 42, 605)),
        "kitchen_west": (R(-870, 75, 110), R(-620, 60, -60)),
        "kitchen_east": (R(-535, 70, -115), R(-880, 70, 40)),
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
