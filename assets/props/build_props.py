"""Builds Turkey Race's item box, boost pad and track pieces in their own scene, TR_Props, and renders preview shots.

Run it inside Blender. It leaves other scenes alone and replaces its own scene each time. Everything shares one palette
texture, in the same low-poly style as the turkey. One Blender unit is one stud, and a piece's front faces -Y, which
is the way it faces in Roblox after import. Pieces named *_Glow become Neon in the game.
"""

import math
import os
import random
from contextlib import contextmanager
from math import cos, pi, radians, sin

import bpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/props"
RENDER_DIR = ASSET_DIR + "/renders"
SCENE_NAME = "TR_Props"

# name: (sRGB hex, roughness, metalness)
PALETTE = {
    "plum": ("5C2A92", 0.42, 0.0),
    "plum_dark": ("371659", 0.5, 0.0),
    # Part metal: full metal only looks gold where there's something bright to reflect.
    "gold": ("FFD24A", 0.3, 0.55),
    "gold_dark": ("EBA92B", 0.36, 0.45),
    "feather_red": ("E5392F", 0.6, 0.0),
    "feather_orange": ("FF8C1F", 0.6, 0.0),
    "feather_teal": ("1FA6A0", 0.6, 0.0),
    "feather_tip": ("FFF0C8", 0.6, 0.0),
    "charcoal": ("2C2C33", 0.5, 0.2),
    "black": ("1A1A1F", 0.5, 0.1),
    "steel_dark": ("5A6068", 0.4, 0.9),
    "steel": ("B4BBC2", 0.25, 1.0),
    "silver": ("DCE1E6", 0.16, 1.0),
    "rail_orange": ("FF7A1A", 0.38, 0.0),
    "white": ("F5F5F0", 0.5, 0.0),
    "wood": ("B07A45", 0.7, 0.0),
    "wood_dark": ("6E4426", 0.7, 0.0),
    "brass": ("D9A441", 0.3, 1.0),
    "china": ("F7F3E9", 0.22, 0.0),
    "mash": ("FFF1C9", 0.7, 0.0),
    "mash2": ("F8E7BD", 0.75, 0.0),
    "gravy": ("7A4520", 0.12, 0.0),
    "gravy2": ("9A5C2C", 0.1, 0.0),
    "bean": ("5C9E3A", 0.6, 0.0),
    "corn": ("FFD23F", 0.42, 0.0),
    "corn2": ("EDB31C", 0.48, 0.0),
    "husk": ("A8C765", 0.7, 0.0),
    "husk2": ("7DA545", 0.7, 0.0),
    "cran": ("B3123C", 0.12, 0.0),
    "cran2": ("8E0C2E", 0.15, 0.0),
    "pumpkin": ("F58220", 0.52, 0.0),
    "pumpkin2": ("D9660F", 0.58, 0.0),
    "stem": ("6E7B35", 0.8, 0.0),
    "butter": ("FFE070", 0.32, 0.0),
    "butter2": ("FFCF45", 0.28, 0.0),
    "tomato": ("E22D25", 0.2, 0.0),
    "tomato2": ("BE1F1B", 0.25, 0.0),
    "leaf": ("3E9B3A", 0.6, 0.0),
    "crust": ("E0A050", 0.7, 0.0),
    "crust2": ("C98838", 0.7, 0.0),
    "filling": ("E8782A", 0.38, 0.0),
    "cream": ("FFFBEF", 0.6, 0.0),
    "pan": ("26262B", 0.32, 0.7),
    "egg": ("FFFCEF", 0.5, 0.0),
    "yolk": ("FFBE22", 0.28, 0.0),
    "meat": ("C8742E", 0.48, 0.0),
    "meat2": ("A85A20", 0.52, 0.0),
    "bone": ("F7EFDC", 0.6, 0.0),
    "straw": ("E6C65C", 0.85, 0.0),
    "straw2": ("D4AE45", 0.85, 0.0),
    "straw3": ("F0D677", 0.85, 0.0),
    "twine": ("8A5A2B", 0.9, 0.0),
    "plaid": ("C43A32", 0.8, 0.0),
    "plaid_dark": ("5C1F1C", 0.8, 0.0),
    "denim": ("3B5B8C", 0.8, 0.0),
    "sack": ("C9A874", 0.9, 0.0),
    "hat": ("6B4A2A", 0.85, 0.0),
    "stone": ("9A958C", 0.9, 0.0),
    "stone2": ("7F7A72", 0.9, 0.0),
    "bark": ("6B4A2F", 0.9, 0.0),
    "bark2": ("523824", 0.9, 0.0),
    "log_end": ("D2AE78", 0.8, 0.0),
    "moss": ("6C9A3A", 0.9, 0.0),
    "mixer": ("D32F2F", 0.22, 0.2),
    "mixer2": ("A71F1F", 0.25, 0.2),
    "flour": ("F3EBD6", 0.85, 0.0),
    "flour2": ("D8CDB0", 0.85, 0.0),
    "stripe_blue": ("3A6FB5", 0.7, 0.0),
    "display": ("6CF2A0", 0.3, 0.0),
    "cavity": ("E8DFA8", 0.5, 0.0),
    "toast": ("D9A25C", 0.8, 0.0),
    "toast2": ("A8672A", 0.8, 0.0),
    "onion": ("A8507E", 0.42, 0.0),
    "onion2": ("C878A0", 0.42, 0.0),
    "carrot": ("F47B20", 0.48, 0.0),
    "carrot2": ("D9650F", 0.52, 0.0),
    "pepper": ("3A3A40", 0.5, 0.0),
    "soup": ("D8552A", 0.15, 0.0),
    "start": ("F5F1E6", 0.6, 0.0),
    "glow": ("FFE27A", 0.4, 0.0),
}

SWATCH_NAMES = list(PALETTE)
SWATCHES_ACROSS = 16
TEXTURE_SIZE = 512
assert len(SWATCH_NAMES) <= SWATCHES_ACROSS * SWATCHES_ACROSS


def swatch_uv(name):
    i = SWATCH_NAMES.index(name)
    return ((i % SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS, (i // SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS)


# Geometry helpers --------------------------------------------------------------------------------------------------

ZERO = V((0, 0, 0))
AXES = {
    "X": (V((0, 1, 0)), V((0, 0, 1)), V((1, 0, 0))),
    "Y": (V((0, 0, 1)), V((1, 0, 0)), V((0, 1, 0))),
    "Z": (V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))),
}


class Part:
    """Vertices and faces for one object; each face names its palette swatch."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.m = Matrix.Identity(4)

    def add(self, p):
        self.verts.append(self.m @ V(p))
        return len(self.verts) - 1

    def face(self, ids, color, smooth=False):
        self.faces.append((list(ids), color, smooth))

    def face_out(self, ids, color, center, smooth=False):
        """Adds a face wound so it points away from `center` (already in final space)."""
        points = [self.verts[i] for i in ids]
        normal = ZERO.copy()
        for k, p in enumerate(points):
            q = points[(k + 1) % len(points)]
            normal += V((p.y * q.z - p.z * q.y, p.z * q.x - p.x * q.z, p.x * q.y - p.y * q.x))
        middle = sum(points, ZERO.copy()) / len(points)
        if normal.dot(middle - center) < 0:
            ids = list(reversed(ids))
        self.face(ids, color, smooth)

    def center(self, ids):
        return sum((self.verts[i] for i in ids), ZERO.copy()) / len(ids)

    @contextmanager
    def xf(self, matrix):
        """Everything added inside goes through `matrix`. Use only rotations, moves and positive scales."""
        old = self.m
        self.m = old @ matrix
        yield
        self.m = old

    def loft(self, rings, color, smooth=False, cap_start=True, cap_end=True):
        """Skins rings in order into quads; a ring of one point is a pole. color is a swatch name or
        color(face_center, gap, segment). The spine must run along X x Y of each ring."""
        ids = [[self.add(p) for p in r] for r in rings]

        def pick(face, i, j):
            return color if isinstance(color, str) else color(self.center(face), i, j)

        for i in range(len(ids) - 1):
            a, b = ids[i], ids[i + 1]
            n = max(len(a), len(b))
            for j in range(n):
                k = (j + 1) % n
                if len(a) == 1:
                    face = [a[0], b[k], b[j]]
                elif len(b) == 1:
                    face = [a[j], a[k], b[0]]
                else:
                    face = [a[j], a[k], b[k], b[j]]
                self.face(face, pick(face, i, j), smooth)
        if cap_start and len(ids[0]) > 2:
            self.face(list(reversed(ids[0])), pick(ids[0], 0, 0), smooth)
        if cap_end and len(ids[-1]) > 2:
            self.face(ids[-1], pick(ids[-1], len(ids) - 2, 0), smooth)


def ring(center, X, Y, rx, ry, n, phase=0.0, radial=None):
    points = []
    for j in range(n):
        a = 2 * pi * (j + phase) / n
        f = radial(a) if radial else 1.0
        points.append(center + X * (rx * f * cos(a)) + Y * (ry * f * sin(a)))
    return points


def lathe(part, profile, color, n=16, smooth=True, center=ZERO, radial=None, axis="Z", cap_start=True, cap_end=True, phase=0.0):
    """Spins a list of (radius, height) around `axis`. radial(angle, ring_index) can scale a ring as it goes around."""
    X, Y, T = AXES[axis]
    center = V(center)
    rings = []
    for index, (r, h) in enumerate(profile):
        c = center + T * h
        if r <= 0.001:
            rings.append([c])
        else:
            f = (lambda a, index=index: radial(a, index)) if radial else None
            rings.append(ring(c, X, Y, r, r, n, phase=phase, radial=f))
    part.loft(rings, color, smooth, cap_start, cap_end)


def box(part, center, size, color):
    """A plain 12-triangle block."""
    c, h = V(center), V(size) / 2
    corners = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corners[(sx, sy, sz)] = part.add(c + V((sx * h.x, sy * h.y, sz * h.z)))
    world = part.m @ c
    for axis in range(3):
        u, v = (axis + 1) % 3, (axis + 2) % 3
        for s in (-1, 1):
            ids = []
            for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corner = [0, 0, 0]
                corner[axis], corner[u], corner[v] = s, su, sv
                ids.append(corners[tuple(corner)])
            part.face_out(ids, color, world)


def cbox(part, center, size, color, bevel=0.1, edge=None, smooth=False):
    """A block with chamfered edges, which catch the light and read as chunky. edge colors the chamfers."""
    c, h = V(center), V(size) / 2
    bevel = min(bevel, h.x * 0.9, h.y * 0.9, h.z * 0.9)
    if bevel <= 0:
        return box(part, center, size, color)
    # Each corner has three vertices, one on each of the three big faces that meet there.
    idx = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                signs = (sx, sy, sz)
                for axis in range(3):
                    p = [sx * h.x, sy * h.y, sz * h.z]
                    for k in range(3):
                        if k != axis:
                            p[k] -= signs[k] * bevel
                    idx[(sx, sy, sz, axis)] = part.add(c + V(p))
    world = part.m @ c
    for axis in range(3):
        u, v = (axis + 1) % 3, (axis + 2) % 3
        for s in (-1, 1):
            ids = []
            for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corner = [0, 0, 0]
                corner[axis], corner[u], corner[v] = s, su, sv
                ids.append(idx[(corner[0], corner[1], corner[2], axis)])
            part.face_out(ids, color, world, smooth)
    for along in range(3):
        a, b = (along + 1) % 3, (along + 2) % 3
        for sa in (-1, 1):
            for sb in (-1, 1):

                def at(s, which):
                    corner = [0, 0, 0]
                    corner[a], corner[b], corner[along] = sa, sb, s
                    return idx[(corner[0], corner[1], corner[2], which)]

                part.face_out([at(-1, a), at(-1, b), at(1, b), at(1, a)], edge or color, world, smooth)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                part.face_out([idx[(sx, sy, sz, 0)], idx[(sx, sy, sz, 1)], idx[(sx, sy, sz, 2)]], edge or color, world, smooth)


def tube(part, points, radius, color, n=8, smooth=True, squash=1.0, cap_start=True, cap_end=True):
    """A pipe along `points`. radius is a number or one per point. squash flattens it across its second axis."""
    points = [V(p) for p in points]
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
    rings = []
    X = None
    for i, p in enumerate(points):
        before, after = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
        T = (after - before).normalized()
        if X is None:
            hint = V((0, 1, 0)) if abs(T.z) > 0.95 else V((0, 0, 1))
            X = hint.cross(T).normalized()
        else:
            X = (X - T * X.dot(T)).normalized()
        Y = T.cross(X)
        rings.append(ring(p, X, Y, radii[i], radii[i] * squash, n))
    part.loft(rings, color, smooth, cap_start, cap_end)


def blob(part, center, rx, ry, rz, color, n=8, rings=3, smooth=True, jitter=0.0, seed=1):
    """A rounded lump, optionally knobbly."""
    X, Y, _ = AXES["Z"]
    center = V(center)
    random_source = random.Random(seed)

    def shake():
        return 1 + random_source.uniform(-jitter, jitter) if jitter else 1

    points = [[center + V((0, 0, -rz))]]
    for i in range(1, rings + 1):
        a = -pi / 2 + pi * i / (rings + 1)
        layer = []
        for j in range(n):
            angle = 2 * pi * (j + (i % 2) * 0.5) / n
            f = shake()
            layer.append(center + X * (rx * cos(a) * cos(angle) * f) + Y * (ry * cos(a) * sin(angle) * f) + V((0, 0, rz * sin(a))))
        points.append(layer)
    points.append([center + V((0, 0, rz))])
    part.loft(points, color, smooth)


def leaf(part, base, direction, normal, length, width, color, tip=None, thick=0.1, bend=0.0, stations=5, sides=6):
    """A closed lens shape, for feathers, leaves and tufts. It's solid so it looks right from both sides."""
    base, T, N = V(base), V(direction).normalized(), V(normal).normalized()
    X = N.cross(T).normalized()
    N = T.cross(X).normalized()
    rings = []
    for i in range(stations):
        t = i / (stations - 1)
        center = base + T * (length * t) + N * (bend * t * t)
        w = width * sin(pi * (0.08 + 0.92 * t) ** 0.8) ** 0.8
        w = max(w, width * 0.05)
        rings.append(ring(center, X, N, w / 2, thick / 2, sides))

    def pick(center, i, j):
        return tip if tip and i >= stations - 2 else color

    part.loft(rings, pick if tip else color, True)


def prism(part, points, z0, z1, color, side=None):
    """A flat shape extruded from z0 to z1. points run counterclockwise seen from above and must be convex."""
    low = [part.add((x, y, z0)) for x, y in points]
    high = [part.add((x, y, z1)) for x, y in points]
    part.face(list(reversed(low)), side or color)
    part.face(high, color)
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        part.face([low[i], low[j], high[j], high[i]], side or color)


def checker(a, b):
    return lambda center, i, j: a if (i + j) % 2 == 0 else b


def segments(a, b, every=2):
    return lambda center, i, j: a if j % every == 0 else b


# The pieces -----------------------------------------------------------------------------------------------------------

PIECES = {}


def piece(name):
    def register(fn):
        PIECES[name] = fn
        return fn

    return register


# Item box ---------------------------------------------------------------------------------------------------------------

BOX_HALF = 3.3


@piece("ItemBox_Body")
def item_box_body():
    p = Part()
    cbox(p, ZERO, (BOX_HALF * 2,) * 3, "plum", bevel=0.5, edge="plum_dark")
    for sign in (-1, 1):
        box(p, (sign * (BOX_HALF + 0.02), 0, 0), (0.1, 4.9, 4.9), "plum_dark")
        box(p, (0, sign * (BOX_HALF + 0.02), 0), (4.9, 0.1, 4.9), "plum_dark")
        box(p, (0, 0, sign * (BOX_HALF + 0.02)), (4.9, 4.9, 0.1), "plum_dark")
    # Gold straps along every edge, with a stud on each corner.
    inset = BOX_HALF - 0.05
    for a in (-1, 1):
        for b in (-1, 1):
            box(p, (0, a * inset, b * inset), (5.6, 0.75, 0.75), "gold_dark")
            box(p, (a * inset, 0, b * inset), (0.75, 5.6, 0.75), "gold_dark")
            box(p, (a * inset, b * inset, 0), (0.75, 0.75, 5.6), "gold_dark")
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                blob(p, (sx * inset, sy * inset, sz * inset), 0.85, 0.85, 0.85, "gold", n=6, rings=2)
    # A tuft of feathers on top, turkey colors.
    top = V((0, 0, BOX_HALF - 0.1))
    for angle, color, length in ((-32, "feather_red", 4.6), (32, "feather_teal", 4.6), (0, "feather_orange", 5.4)):
        a = radians(angle)
        direction = V((sin(a), 0.12, cos(a)))
        leaf(p, top, direction, V((0, -1, 0.12)), length, 1.9, color, tip="feather_tip", thick=0.22, bend=-0.5)
    return p


@piece("ItemBox_Glow")
def item_box_glow():
    """A neon-tube question mark on each side."""
    p = Part()
    for turn in range(4):
        with p.xf(Matrix.Rotation(turn * pi / 2, 4, "Z")):
            y = -BOX_HALF - 0.32
            center_z, radius = 0.72, 1.28
            arc = []
            for k in range(9):
                a = radians(165 - k * (240 / 8))
                arc.append((radius * cos(a), y, center_z + radius * sin(a)))
            arc += [(0.1, y, -0.72)]
            tube(p, arc, 0.36, "glow", n=6)
            blob(p, (0.1, y, -1.85), 0.5, 0.5, 0.5, "glow", n=6, rings=2)
    return p


@piece("ItemBox_Halo_Glow")
def item_box_halo():
    """A thin ring that orbits the box."""
    p = Part()
    count = 40
    R = 6.0
    rings = []
    for i in range(count + 1):
        a = 2 * pi * i / count
        center = V((R * cos(a), R * sin(a), 0))
        T = V((-sin(a), cos(a), 0))
        X = V((0, 0, 1)).cross(T).normalized()
        rings.append(ring(center, X, T.cross(X), 0.13, 0.13, 4))
    p.loft(rings, "glow", True, False, False)
    return p


# Boost pad and start mark ---------------------------------------------------------------------------------------------

BOOST_WIDTH, BOOST_LENGTH = 16, 26


def chevron_shape(part, y, z0, z1, color, grow=0.0):
    """A chevron pointing -Y, centered on `y`; grow makes it a little bigger, for the slot it sits in."""
    w, d, t = 5.6 + grow, 3.4, 2.1 + grow * 2
    tip = (0, y - d / 2 - grow)
    outer = (w, y + d / 2)
    far = (w, y + d / 2 + t)
    notch = (0, y - d / 2 + t - grow)
    prism(part, [tip, outer, far, notch], z0, z1, color)
    prism(part, [tip, notch, (-far[0], far[1]), (-outer[0], outer[1])], z0, z1, color)


@piece("BoostPad_Base")
def boost_base():
    p = Part()
    half_w, half_l = BOOST_WIDTH / 2, BOOST_LENGTH / 2
    cbox(p, (0, 0, 0.16), (BOOST_WIDTH, BOOST_LENGTH, 0.32), "charcoal", bevel=0.12)
    for sign in (-1, 1):
        cbox(p, (sign * (half_w - 0.7), 0, 0.27), (1.4, BOOST_LENGTH, 0.54), "rail_orange", bevel=0.14)
        box(p, (sign * (half_w - 0.7), 0, 0.56), (0.45, BOOST_LENGTH - 1.2, 0.06), "gold")
        # Bolts along the rails.
        for y in (-half_l + 2, -half_l / 3, half_l / 3, half_l - 2):
            lathe(p, [(0.42, 0.54), (0.42, 0.62), (0, 0.64)], "steel", n=6, smooth=False, center=(sign * (half_w - 0.7), y, 0))
    cbox(p, (0, -half_l + 0.7, 0.24), (BOOST_WIDTH - 2.8, 1.4, 0.48), "steel_dark", bevel=0.12)
    cbox(p, (0, half_l - 0.7, 0.24), (BOOST_WIDTH - 2.8, 1.4, 0.48), "steel_dark", bevel=0.12)
    # A dark slot under each glowing chevron, so they still read as arrows while they're dim.
    for y in (-7, 0, 7):
        chevron_shape(p, y - 1, 0.32, 0.36, "black", grow=0.35)
    return p


@piece("BoostPad_Chevron_Glow")
def boost_chevron():
    p = Part()
    chevron_shape(p, -1, 0.0, 0.14, "glow")
    return p


@piece("StartMark")
def start_mark():
    """A racing grid bracket, open toward the back."""
    p = Part()
    box(p, (0, -6, 0.05), (11, 1, 0.1), "start")
    for sign in (-1, 1):
        box(p, (sign * 5, -2, 0.05), (1, 7, 0.1), "start")
    return p


# Thrown food and power-ups -----------------------------------------------------------------------------------------------


@piece("Tomato")
def tomato():
    p = Part()
    profile = [(0, -3.5), (2.2, -3.25), (3.6, -1.8), (4.1, 0), (3.7, 1.8), (2.4, 3.0), (0.9, 3.25), (0, 3.0)]
    lathe(p, profile, "tomato", n=15, radial=lambda a, i: 1 + 0.05 * cos(5 * a))
    for k in range(5):
        a = k * 2 * pi / 5
        leaf(p, (0, 0, 3.05), (cos(a), sin(a), 0.1), (0, 0, 1), 2.9, 1.0, "leaf", thick=0.14, bend=-0.5, stations=4, sides=4)
    tube(p, [(0, 0, 3.0), (0.1, 0, 3.9), (0.4, 0, 4.6)], [0.3, 0.26, 0.24], "leaf", n=5)
    return p


@piece("Pie")
def pie():
    p = Part()
    crimp = lambda a, i: 1 + 0.035 * cos(12 * a) if i >= 2 else 1

    def crust_color(center, i, j):
        return "crust2" if i < 1 or (i >= 2 and j % 2 == 0) else "crust"

    lathe(p, [(0, 0), (5.2, 0), (6.0, 1.0), (6.5, 1.35), (6.5, 1.8), (5.7, 1.85)], crust_color, n=24, smooth=False, radial=crimp, cap_end=False)
    lathe(p, [(5.7, 1.82), (3.2, 1.9), (0, 1.95)], "filling", n=24, smooth=True)
    swirl = lambda a, i: 1 + 0.14 * cos(6 * a)
    lathe(p, [(2.0, 1.85), (2.1, 2.4), (1.3, 3.0), (0.75, 3.5), (0, 4.1)], "cream", n=12, smooth=True, radial=swirl)
    return p


@piece("FryingPan")
def frying_pan():
    p = Part()

    def pan_color(center, i, j):
        return "steel_dark" if i >= 3 else "pan"

    lathe(p, [(0, 0), (5.5, 0), (6.4, 1.2), (6.6, 1.35), (6.0, 1.35), (5.3, 0.4), (0, 0.4)], pan_color, n=20, smooth=False)
    tube(p, [(0, 6.2, 1.0), (0, 9, 1.25), (0, 12, 1.5), (0, 16, 1.9)], [0.62, 0.55, 0.55, 0.72], "pan", n=6, squash=0.6)
    for x in (-0.9, 0.9):
        blob(p, (x, 6.6, 1.1), 0.3, 0.3, 0.3, "steel", n=5, rings=1)
    blob(p, (0, 0, 0.55), 3.3, 2.9, 0.28, "egg", n=10, rings=2, jitter=0.1, seed=3)
    blob(p, (0.3, -0.2, 0.95), 1.15, 1.15, 0.65, "yolk", n=8, rings=3)
    return p


@piece("Drumstick")
def drumstick():
    p = Part()
    lathe(p, [(0, 0), (2.2, 0.6), (3.2, 2.4), (3.0, 4.4), (2.0, 6.2), (1.0, 7.6), (0.75, 8.3)], segments("meat", "meat2", 3), n=12, cap_end=False)
    lathe(p, [(0.75, 8.2), (0.68, 10.4), (1.2, 10.9), (1.25, 11.5), (0.6, 12), (0, 12.1)], "bone", n=10)
    for a in (0.9, 2.6, 4.4):
        blob(p, (cos(a) * 2.9, sin(a) * 2.9, 3.2), 0.5, 0.5, 0.9, "meat2", n=5, rings=2)
    return p


@piece("Butter")
def butter():
    p = Part()
    lathe(p, [(0, 0), (3.8, 0), (4.8, 0.45), (4.9, 0.62), (4.1, 0.62), (0, 0.5)], "china", n=18)
    cbox(p, (-0.5, 0, 1.2), (5.4, 3.2, 1.4), "butter", bevel=0.18, edge="butter2")
    cbox(p, (3.15, 0.1, 1.15), (1.2, 3.1, 1.3), "butter", bevel=0.15, edge="butter2")
    blob(p, (2.0, -2.0, 0.66), 1.3, 0.9, 0.1, "butter2", n=8, rings=1)
    return p


# Dinner Dash -------------------------------------------------------------------------------------------------------------


@piece("Fork")
def fork():
    """Stuck upright in the table, tines up. 35 tall, like the old one."""
    p = Part()
    X, Y, _ = AXES["Z"]
    stations = [(0, 0.8, 0.8), (6, 1.0, 0.75), (16, 1.35, 0.55), (22, 0.85, 0.5), (25, 1.0, 0.5), (26.5, 2.6, 0.5), (28, 3.5, 0.5), (29, 3.5, 0.5)]
    rings = [ring(V((0, 0, z)), X, Y, rx, ry, 8) for z, rx, ry in stations]
    p.loft(rings, "silver", True)
    for x in (-2.7, -0.9, 0.9, 2.7):
        tube(p, [(x, 0, 28.6), (x, 0.1, 31), (x, 0.35, 33), (x, 0.7, 35)], [0.55, 0.45, 0.36, 0.14], "silver", n=5)
    lathe(p, [(0.95, 3.8), (1.0, 4.2), (0.95, 4.6)], "gold", n=8, smooth=False, cap_start=False, cap_end=False)
    return p


@piece("Knife")
def knife():
    """Stuck in the table point first, handle up. 32 tall, like the old one."""
    p = Part()
    X, Y, _ = AXES["Z"]
    stations = [(0, 0.5, 0.12), (1.5, 1.8, 0.2), (5, 2.7, 0.28), (15, 2.9, 0.34), (24, 2.8, 0.42)]
    rings = [ring(V((-0.1 * (z / 24), 0, z)), X, Y, rx, ry, 8) for z, rx, ry in stations]
    p.loft(rings, "silver", True)
    cbox(p, (0, 0, 24.6), (5.2, 1.3, 1.3), "brass", bevel=0.25)
    cbox(p, (0, 0, 28.6), (2.7, 2.1, 6.9), "wood_dark", bevel=0.55, edge="wood")
    for z in (26.6, 28.6, 30.6):
        with p.xf(Matrix.Translation((0, -1.04, z))):
            lathe(p, [(0.36, 0), (0.36, -0.02), (0, -0.14)], "brass", n=6, smooth=False, axis="Y", cap_start=False)
    return p


@piece("DinnerPlate")
def dinner_plate():
    p = Part()

    def plate_color(center, i, j):
        return "gold" if i in (2, 3) else "china"

    lathe(p, [(0, 0), (6.2, 0), (7.6, 0.7), (8.7, 1.1), (9.0, 1.3), (8.5, 1.3), (7.4, 0.95), (6.0, 0.35), (0, 0.3)], plate_color, n=26)
    blob(p, (-2.3, 1.2, 0.8), 2.9, 2.5, 0.75, "mash", n=9, rings=2, jitter=0.1, seed=5)
    blob(p, (-2.3, 1.2, 1.3), 1.0, 0.9, 0.22, "gravy", n=7, rings=1)
    for k in range(5):
        y = -3.6 + k * 0.95
        tube(p, [(0.4, y, 0.55), (2.2, y + 0.25, 0.62), (4.1, y - 0.2, 0.55)], 0.28, "bean", n=5)
    cbox(p, (2.8, 2.4, 0.62), (3.6, 2.2, 0.5), "meat", bevel=0.14, edge="meat2")
    return p


@piece("GravyPuddle")
def gravy_puddle():
    p = Part()
    n = 28

    def shape(scale):
        return lambda a: scale * (1 + 0.09 * sin(3 * a + 1) + 0.06 * sin(5 * a + 2))

    X, Y, _ = AXES["Z"]
    rings = [
        ring(V((0, 0, 0)), X, Y, 15, 15, n, radial=shape(0.92)),
        ring(V((0, 0, 0.18)), X, Y, 15, 15, n, radial=shape(0.9)),
        ring(V((0, 0, 0.26)), X, Y, 15, 15, n, radial=shape(0.75)),
        ring(V((0, 0, 0.3)), X, Y, 15, 15, n, radial=shape(0.4)),
        [V((0, 0, 0.32))],
    ]

    p.loft(rings, "gravy", True, cap_start=False)
    for x, y, r in ((13, 10, 1.6), (-14, -9, 1.2), (6, -15, 1.0)):
        blob(p, (x, y, 0.12), r, r, 0.14, "gravy", n=7, rings=1)
    # A couple of glossy skins on the surface.
    blob(p, (-3.5, 2.5, 0.31), 4.2, 2.6, 0.03, "gravy2", n=9, rings=1)
    blob(p, (5, -4, 0.31), 2.2, 1.5, 0.03, "gravy2", n=7, rings=1)
    return p


@piece("CornCob")
def corn_cob():
    """Lying along X, 40 long and 6 across."""
    p = Part()
    X, Y, _ = AXES["X"]
    stations = 22
    n = 12
    rings = [[V((-20, 0, 0))]]
    for i in range(stations + 1):
        t = i / stations
        x = -19 + 38.2 * t
        r = 3.0 * (1 - t ** 3 * 0.55) * (0.9 if i % 2 else 1.0)
        rings.append(ring(V((x, 0, 0)), X, Y, r, r, n, phase=(i % 2) * 0.5))
    rings.append([V((19.8, 0, 0))])

    def kernel(center, i, j):
        return "corn" if (i + j) % 2 == 0 else "corn2"

    p.loft(rings, kernel, False)
    for k in range(5):
        a = k * 2 * pi / 5 + 0.3
        normal = V((0, cos(a), sin(a)))
        leaf(p, V((-19.5, 0, 0)) + normal * 1.6, V((1, 0, 0)), normal, 15, 5.4, "husk", tip="husk2", thick=0.18, bend=4.0, stations=6)
    tube(p, [(-22.5, 0, 0), (-19.5, 0, 0)], [0.9, 1.3], "husk2", n=6)
    return p


@piece("Cranberry")
def cranberry():
    """A jellied cranberry log, still showing the ridges of its can. 8 tall and 16 across."""
    p = Part()
    profile = [(0, 0)]
    for k in range(9):
        profile.append((7.7 if k % 2 == 0 else 8.0, k))
    profile += [(7.4, 8.15), (4.5, 8.3), (0, 8.2)]

    def color(center, i, j):
        return "cran2" if i % 2 == 1 and i < 9 else "cran"

    lathe(p, profile, color, n=20)
    return p


@piece("Pumpkin")
def pumpkin():
    """12 across, with deep cartoon ribs. Also used for the rolling ones, so it's balanced around its middle."""
    p = Part()
    ribs, per_rib = 7, 4
    profile = [(0, -5.2), (2.6, -5.1), (4.8, -3.6), (6, -1), (6, 1.2), (4.9, 3.4), (2.8, 4.8), (1.0, 4.9), (0, 4.3)]
    radial = lambda a, i: 0.87 + 0.13 * abs(sin(ribs * a / 2)) ** 0.6

    def color(center, i, j):
        return "pumpkin2" if j % per_rib in (0, per_rib - 1) else "pumpkin"

    lathe(p, profile, color, n=ribs * per_rib, radial=radial)
    tube(p, [(0, 0, 4.3), (0.15, 0, 5.4), (0.7, 0, 6.3), (1.5, 0, 6.8)], [1.25, 0.85, 0.7, 0.6], segments("stem", "husk2", 2), n=6, smooth=False)
    return p


@piece("PotatoMound")
def potato_mound():
    """A lumpy mashed potato ramp with a pool of gravy on top. It climbs and falls along X and fills the 70-wide lane."""
    p = Part()
    nx, ny = 14, 20
    half_x, half_y, peak = 20.0, 35.0, 5.0

    def height(x, y):
        along = 1 - abs(x) / half_x
        edge = min(1, (half_y - abs(y)) / 7)
        lumps = 0.45 * sin(x * 0.85 + 1.3) * sin(y * 0.55) + 0.25 * sin(x * 1.7 + y * 0.9)
        return max(0, peak * along + lumps * min(along * 3, 1) * edge) * (edge ** 0.5)

    ids = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x, y = -half_x + 2 * half_x * i / nx, -half_y + 2 * half_y * j / ny
            ids[(i, j)] = p.add((x, y, height(x, y)))
    rng = random.Random(2)
    for i in range(nx):
        for j in range(ny):
            face = [ids[(i, j)], ids[(i + 1, j)], ids[(i + 1, j + 1)], ids[(i, j + 1)]]
            center = p.center(face)
            if abs(center.x) < 4 and abs(center.y) < 11:
                color = "gravy"
            else:
                color = "mash2" if rng.random() < 0.15 else "mash"
            p.face(face, color, True)
    cbox(p, (0, 1, 5.6), (3.4, 3.0, 0.9), "butter", bevel=0.16, edge="butter2")
    return p


# Backyard ------------------------------------------------------------------------------------------------------------------


@piece("HayBale")
def hay_bale():
    """12 long (X), 7 deep and 6 tall, with straw streaks and two lengths of twine."""
    p = Part()
    rng = random.Random(4)
    X, Y, _ = AXES["X"]
    stations = 9
    n = 12
    half_y, half_z = 3.5, 3.0
    colors = ("straw", "straw2", "straw3")
    rings = []
    for i in range(stations):
        x = -6 + 12 * i / (stations - 1)
        layer = []
        for j in range(n):
            a = 2 * pi * (j + 0.5) / n
            # A rounded rectangle, with a bit of straggle.
            cy, sy = cos(a), sin(a)
            k = 1 / max(abs(cy) / half_y, abs(sy) / half_z) * (0.95 + 0.05 * rng.random())
            k = k * (0.97 if i in (0, stations - 1) else 1)
            layer.append(V((x, 0, 0)) + X * (cy * k) + Y * (sy * k))
        rings.append(layer)
    pick = {}

    def streak(center, i, j):
        key = (i // 2, j)
        if key not in pick:
            pick[key] = colors[rng.randrange(3)]
        return pick[key]

    p.loft(rings, streak, False)
    with p.xf(Matrix.Translation((0, 0, 3.0))):
        for x in (-3.2, 3.2):
            loop = []
            for k in range(9):
                a = 2 * pi * k / 8
                cy, sy = cos(a), sin(a)
                r = 1 / max(abs(cy) / (half_y + 0.08), abs(sy) / (half_z + 0.08))
                loop.append((x, cy * r, sy * r - 3.0))
            tube(p, loop, 0.13, "twine", n=4, smooth=False, cap_start=False, cap_end=False)
    for x, y, angle in ((-6, 1, 0.4), (-6, -1.6, 2.2), (6, 0.5, 4), (6, -1, 1.2), (2, -3.5, 5.3)):
        direction = V((1 if x > 0 else -1 if x < 0 else 0, -1 if y < -3 else 0, 0)) + V((0, cos(angle) * 0.5, sin(angle) * 0.5))
        leaf(p, (x, y, sin(angle) * 1.5), direction, (0, 0.2, 1), 1.9, 0.35, "straw3", thick=0.1, stations=3, sides=4)
    return p


@piece("Scarecrow")
def scarecrow():
    """Arms out along X, front toward -Y: about 18 across and 13 tall, like the old one."""
    p = Part()
    cbox(p, (0, 0, 3.0), (0.8, 0.8, 6), "wood_dark", bevel=0.12)
    cbox(p, (0, 0, 7.1), (4.6, 2.6, 4.2), "plaid", bevel=0.35, edge="plaid_dark")
    for z in (6.2, 8.0):
        box(p, (0, 0, z), (4.68, 2.68, 0.3), "plaid_dark")
    for x in (-1.2, 1.2):
        box(p, (x, 0, 7.1), (0.3, 2.68, 3.6), "plaid_dark")
    cbox(p, (0, 0, 5.2), (4.8, 2.8, 1.6), "denim", bevel=0.25)
    for x in (-1.3, 1.3):
        box(p, (x, -1.36, 7.4), (0.6, 0.12, 3.2), "denim")
    for sign in (-1, 1):
        tube(p, [(sign * 2.0, 0, 8.2), (sign * 5, 0, 8.5), (sign * 7.8, 0, 8.3)], [1.0, 0.92, 0.9], "plaid", n=7)
        cuff = V((sign * 7.9, 0, 8.3))
        for k in range(5):
            a = k * 2 * pi / 5
            leaf(p, cuff, V((sign * 1, cos(a) * 0.5, sin(a) * 0.5)), (0, 0.3, 1), 2.0, 0.5, "straw", thick=0.1, stations=3, sides=4)
    for k in range(5):
        a = k * 2 * pi / 5
        leaf(p, (0, 0, 9.3), V((cos(a), sin(a), 0.1)), (0, 0, 1), 1.9, 0.6, "straw3", thick=0.1, stations=3, sides=4)
    blob(p, (0, 0, 10.8), 1.95, 1.8, 1.8, "sack", n=10, rings=4)
    for x in (-0.7, 0.7):
        blob(p, (x, -1.72, 11.15), 0.3, 0.18, 0.3, "black", n=6, rings=1)
    for k in range(5):
        x = -1.0 + k * 0.5
        z = 10.05 - 0.28 * (1 - ((k - 2) / 2) ** 2)
        box(p, (x, -1.72, z), (0.08, 0.14, 0.42), "black")
    # A floppy hat.
    lathe(p, [(3.2, 11.9), (3.3, 12.05), (1.9, 12.25), (1.65, 13.4), (0.9, 13.8), (0, 13.9)], "hat", n=12, smooth=False, cap_start=True)
    lathe(p, [(1.92, 12.2), (1.84, 12.65)], "plaid", n=12, smooth=False, cap_start=False, cap_end=False)
    return p


@piece("Log")
def log():
    """30 long along X and 5 across, with a stump of a branch and a bit of moss."""
    p = Part()
    rng = random.Random(9)
    X, Y, _ = AXES["X"]
    rings = []
    for i in range(7):
        x = -15 + 5 * i
        r = 2.5 * (0.96 + 0.04 * rng.random())
        rings.append(ring(V((x, 0, 0)), X, Y, r, r, 10, phase=(i % 2) * 0.5))

    def bark(center, i, j):
        return "bark" if (i * 3 + j) % 3 else "bark2"

    p.loft(rings, bark, False, cap_start=False, cap_end=False)
    for sign, r in ((-1, rings[0]), (1, rings[-1])):
        end = V((sign * 15.05, 0, 0))
        ids = [p.add(v) for v in r]
        center = p.add(end)
        for j in range(len(ids)):
            k = (j + 1) % len(ids)
            p.face_out([ids[j], ids[k], center], "log_end", V((0, 0, 0)))
    tube(p, [(4, 1.8, 1.0), (5, 3.2, 1.9), (5.2, 3.9, 2.4)], [0.8, 0.6, 0.5], "bark", n=6, smooth=False)
    blob(p, (-5, 0.4, 2.35), 3.2, 1.8, 0.5, "moss", n=8, rings=2, jitter=0.15, seed=2)
    return p


@piece("Stone")
def stone():
    """A flat-topped stepping stone, about 8 across and 2 tall."""
    p = Part()
    rng = random.Random(6)
    radial = lambda a, i: 1 + 0.08 * sin(3 * a + i) + 0.05 * sin(7 * a)
    lathe(p, [(3.4, 0), (4.1, 0.9), (3.9, 1.7), (2.6, 2.05), (0, 2.1)], segments("stone", "stone2", 3), n=11, smooth=False, radial=radial)
    blob(p, (1.4, -1.5, 2.05), 1.3, 0.9, 0.14, "moss", n=7, rings=1, jitter=0.2, seed=rng.randrange(99))
    return p


# Restaurant kitchen ---------------------------------------------------------------------------------------------------------


@piece("StandMixer")
def stand_mixer():
    """About 8 wide, 13 deep and 14 tall, with the bowl at the front."""
    p = Part()
    cbox(p, (0, 0, 0.9), (7.4, 12, 1.8), "mixer", bevel=0.5, edge="mixer2")
    cbox(p, (0, 3.9, 5.2), (3.8, 3.6, 7.6), "mixer", bevel=0.8, edge="mixer2")
    tube(p, [(0, 5.6, 10.6), (0, 3, 10.9), (0, -1, 10.9), (0, -5.0, 10.4)], [2.5, 2.9, 2.7, 1.9], "mixer", n=12, squash=0.92)
    box(p, (0, 0, 13.65), (0.9, 8, 0.12), "silver")
    bowl = [(0, 1.8), (1.7, 1.8), (3.1, 3.4), (3.5, 5.8), (3.6, 6.3), (3.35, 6.3), (3.05, 4.0), (2.2, 2.8), (0, 2.6)]
    lathe(p, bowl, "silver", n=16, center=(0, -2.6, 0))
    tube(p, [(0, -2.6, 9.0), (0, -2.6, 6.8), (0, -2.6, 4.5)], [0.45, 0.32, 0.32], "silver", n=6)
    blob(p, (0, -2.6, 4.4), 1.0, 1.0, 1.1, "silver", n=7, rings=2)
    blob(p, (0, -2.6, 5.2), 2.8, 2.8, 0.35, "cream", n=10, rings=1)
    lathe(p, [(1.0, 0), (1.1, 0.5), (0.5, 0.75), (0, 0.8)], "silver", n=8, smooth=False, center=(3.0, 5.0, 10.9), axis="X")
    return p


@piece("Microwave")
def microwave():
    """A commercial microwave, 30 wide, 22 deep and 16 tall, with its door on the -Y side."""
    p = Part()
    W, D, H = 30, 22, 16
    cbox(p, (0, 0, H / 2 + 0.6), (W, D, H - 1.2 + 0.0), "steel", bevel=0.5)
    y = -D / 2 - 0.3
    cbox(p, (-3.6, y, H / 2 + 0.6), (21, 0.9, 12.6), "black", bevel=0.25)
    box(p, (-4.6, y - 0.47, H / 2 + 0.6), (14.5, 0.1, 8.6), "cavity")
    for dz in (-3, -1, 1, 3):
        box(p, (-4.6, y - 0.54, H / 2 + 0.6 + dz), (14.5, 0.06, 0.14), "pepper")
    cbox(p, (5.1, y - 0.7, H / 2 + 0.6), (1.0, 1.1, 10.4), "silver", bevel=0.2)
    box(p, (11.2, y + 0.2, H / 2 + 0.6), (6.6, 0.7, 12.6), "steel_dark")
    box(p, (11.2, y - 0.2, H / 2 + 4.8), (5.2, 0.12, 2.2), "display")
    for row in range(3):
        for col in range(3):
            box(p, (9.4 + col * 1.8, y - 0.2, H / 2 + 2.2 - row * 1.8), (1.2, 0.16, 1.2), "black" if (row + col) % 2 else "steel")
    for x in (-W / 2 + 2, W / 2 - 2):
        for yy in (-D / 2 + 2, D / 2 - 2):
            box(p, (x, yy, 0.3), (1.6, 1.6, 0.6), "black")
    return p


@piece("FlourSack")
def flour_sack():
    """A plump sack, 16 wide, 12 deep and 20 tall, tied at the top."""
    p = Part()
    X, Y, _ = AXES["Z"]
    stations = [(0, 7.0, 5.0), (0.9, 7.8, 5.8), (5, 8.0, 6.0), (11, 7.7, 5.7), (15, 6.2, 4.6), (16.6, 3.6, 2.7), (17.4, 1.5, 1.2)]
    rounder = lambda a: 1 + 0.07 * abs(sin(2 * a))
    rings = [ring(V((0, 0, z)), X, Y, rx, ry, 14, radial=rounder) for z, rx, ry in stations]

    def color(center, i, j):
        return "stripe_blue" if i == 2 else "flour2" if i == 5 or j % 7 == 0 else "flour"

    p.loft(rings, color, True, cap_end=False)
    lathe(p, [(1.5, 17.3), (1.7, 17.7), (1.5, 18.1)], "twine", n=8, smooth=False, cap_start=False, cap_end=False)
    lathe(p, [(1.4, 18.0), (2.4, 19.3), (2.5, 20), (0, 19.6)], "flour", n=8, smooth=False, cap_start=False, radial=lambda a, i: 1 + 0.25 * cos(3 * a) if i >= 1 else 1)
    return p


@piece("KnifeBlock")
def knife_block():
    """A slanted wooden block with handles sticking out of the top."""
    p = Part()
    tilt = Matrix.Translation((0, 0, 0)) @ Matrix.Rotation(radians(16), 4, "X")
    cbox(p, (0, 0.8, 4.2), (6, 8.4, 8.4), "wood", bevel=0.4, edge="wood_dark")
    with p.xf(tilt):
        for row, y in enumerate((-1.4, 1.6)):
            for k, x in enumerate((-1.6, 0, 1.6)):
                if row == 1 and k == 1:
                    continue
                cbox(p, (x, y, 9.8), (1.15, 1.5, 4.0 - row * 0.6), "black", bevel=0.2)
                box(p, (x, y, 8.0), (1.2, 1.55, 0.3), "steel")
    return p


@piece("StockPot")
def stock_pot():
    p = Part()

    def color(center, i, j):
        return "steel" if i <= 3 else "silver"

    lathe(p, [(0, 0), (9.0, 0), (9.5, 0.5), (9.5, 11.0), (9.9, 11.2), (9.9, 11.7), (9.1, 11.7), (8.9, 10.4), (0, 10.4)], color, n=20, smooth=False)
    lathe(p, [(8.9, 10.45), (0, 10.55)], "soup", n=20, cap_start=False)
    for sign in (-1, 1):
        tube(p, [(sign * 9.3, -2.2, 9.4), (sign * 11.2, -2.2, 9.7), (sign * 11.6, 0, 9.8), (sign * 11.2, 2.2, 9.7), (sign * 9.3, 2.2, 9.4)], 0.42, "steel_dark", n=5, smooth=False)
    for x, y in ((3.6, 1.5), (-2, -3.8), (-3.5, 3.2)):
        blob(p, (x, y, 10.65), 1.2, 1.2, 0.35, "carrot", n=7, rings=1)
    return p


@piece("Toaster")
def toaster():
    """Chrome, 14 wide, 9 deep and 8 tall, with two slices popping up."""
    p = Part()
    X, Y, _ = AXES["Z"]
    rounded = lambda a: 1 + 0.2 * abs(sin(2 * a))
    stations = [(0.5, 6.0, 3.6), (1.0, 6.8, 4.1), (6.6, 6.8, 4.1), (7.8, 6.3, 3.6), (8.2, 5.2, 2.8)]
    rings = [ring(V((0, 0, z)), X, Y, rx, ry, 16, radial=rounded) for z, rx, ry in stations]
    p.loft(rings, "silver", True)
    for y in (-1.3, 1.3):
        box(p, (0, y, 8.24), (8.4, 1.0, 0.08), "black")
        cbox(p, (0, y, 9.6), (6.8, 0.7, 4.2), "toast", bevel=0.28, edge="toast2")
    box(p, (0, -4.6, 0.25), (11, 1.6, 0.5), "black")
    box(p, (0, 4.6, 0.25), (11, 1.6, 0.5), "black")
    box(p, (8.3, 0, 4.2), (0.5, 1.0, 3.6), "black")
    cbox(p, (8.9, 0, 5.2), (1.0, 1.7, 0.8), "black", bevel=0.15)
    lathe(p, [(0.8, 0), (0.75, -0.5), (0, -0.55)], "black", n=8, smooth=False, center=(4.2, -4.8, 2.2), axis="Y", cap_start=False)
    return p


@piece("RollingPin")
def rolling_pin():
    """24 long along X, with its handles."""
    p = Part()
    profile = [(0, -12), (0.8, -11.9), (1.0, -11.0), (0.7, -8.6), (2.3, -8.0), (2.5, -7.4), (2.5, 7.4), (2.3, 8.0), (0.7, 8.6), (1.0, 11.0), (0.8, 11.9), (0, 12)]

    def color(center, i, j):
        return "wood_dark" if i < 3 or i >= 8 else "wood"

    lathe(p, profile, color, n=12, axis="X")
    return p


@piece("Onion")
def onion():
    p = Part()
    profile = [(0, -4.2), (2.4, -3.9), (4.2, -2.2), (4.6, 0), (3.8, 2.2), (1.7, 3.5), (0.5, 4.1), (0, 5.2)]
    lathe(p, profile, segments("onion", "onion2", 3), n=15)
    tube(p, [(0, 0, -4.1), (0, 0, -4.7)], [0.6, 0.3], "straw", n=5, smooth=False)
    return p


@piece("Carrot")
def carrot():
    """12 long along X, narrow end at +X, with its leaves."""
    p = Part()

    def color(center, i, j):
        return "carrot2" if i % 3 == 1 else "carrot"

    lathe(p, [(0, -5), (1.2, -4.9), (1.6, -3.5), (1.45, -1.5), (1.15, 1), (0.8, 3.5), (0.4, 5.6), (0, 6.6)], color, n=10, axis="X")
    for k in range(4):
        a = k * pi / 2 + 0.4
        leaf(p, (-4.9, 0, 0), (-1, cos(a) * 0.45, sin(a) * 0.45), (0, -sin(a), cos(a)), 5.2, 1.2, "leaf", thick=0.12, stations=4, sides=4)
    return p


def shaker(body):
    p = Part()
    lathe(p, [(0, 0), (2.6, 0), (3.0, 0.5), (2.7, 4.6), (2.4, 8.2)], body, n=12, cap_end=False)
    lathe(p, [(2.5, 8.1), (2.6, 9.2), (2.1, 10.6), (1.1, 11.6), (0, 12)], "silver", n=12)
    for k in range(5):
        a = k * 2 * pi / 5
        blob(p, (cos(a) * 0.65, sin(a) * 0.65, 11.82), 0.14, 0.14, 0.1, "black", n=4, rings=1, smooth=False)
    return p


@piece("Salt")
def salt():
    return shaker("white")


@piece("Pepper")
def pepper():
    return shaker("pepper")


# Which pieces get rendered together, and which share a spot. ----------------------------------------------------------------

ROWS = {
    "items": [["ItemBox_Body", "ItemBox_Glow", "ItemBox_Halo_Glow"], ["BoostPad_Base", "BoostPad_Chevron_Glow"], ["StartMark"]],
    "food": [["Tomato"], ["Pie"], ["FryingPan"], ["Drumstick"], ["Butter"], ["DinnerPlate"], ["Cranberry"]],
    "table": [["Fork"], ["Knife"], ["Pumpkin"], ["CornCob"], ["GravyPuddle"], ["PotatoMound"]],
    "yard": [["HayBale"], ["Scarecrow"], ["Log"], ["Stone"]],
    "kitchen": [["StandMixer"], ["KnifeBlock"], ["Toaster"], ["Onion"], ["Carrot"], ["RollingPin"], ["Salt"], ["Pepper"], ["FlourSack"], ["StockPot"], ["Microwave"]],
}


# Scene, materials, objects -----------------------------------------------------------------------------------------------


def remove_scene():
    scene = bpy.data.scenes.get(SCENE_NAME)
    if scene:
        for obj in list(scene.collection.all_objects):
            data = obj.data
            bpy.data.objects.remove(obj)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)
        for coll in list(scene.collection.children_recursive):
            bpy.data.collections.remove(coll)
        bpy.data.scenes.remove(scene)


def make_palette_images():
    os.makedirs(ASSET_DIR + "/textures", exist_ok=True)
    cell = TEXTURE_SIZE // SWATCHES_ACROSS

    def channel(i, which):
        if i >= len(SWATCH_NAMES):
            return (0.5, 0.5, 0.5) if which != "metal" else (0, 0, 0)
        hex_value, rough, metal = PALETTE[SWATCH_NAMES[i]]
        if which == "color":
            return tuple(int(hex_value[k : k + 2], 16) / 255 for k in (0, 2, 4))
        v = rough if which == "rough" else metal
        return (v, v, v)

    images = {}
    for which, name, colorspace in (("color", "T_Props_Color", "sRGB"), ("rough", "T_Props_Roughness", "Non-Color"), ("metal", "T_Props_Metalness", "Non-Color")):
        old = bpy.data.images.get(name)
        if old:
            bpy.data.images.remove(old)
        image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
        image.colorspace_settings.name = colorspace
        pixels = []
        for y in range(TEXTURE_SIZE):
            for x in range(TEXTURE_SIZE):
                r, g, b = channel((y // cell) * SWATCHES_ACROSS + x // cell, which)
                pixels += (r, g, b, 1.0)
        image.pixels = pixels
        image.filepath_raw = f"{ASSET_DIR}/textures/{name}.png"
        image.file_format = "PNG"
        image.save()
        image.pack()
        images[which] = image
    return images


def make_materials(images):
    for name in ("M_Props_Palette", "M_Props_Glow"):
        old = bpy.data.materials.get(name)
        if old:
            bpy.data.materials.remove(old)
    mat = bpy.data.materials.new("M_Props_Palette")
    mat.use_nodes = True
    # Roblox doesn't draw the backs of faces, so don't here either: a flipped face shows up now, not in-game.
    mat.use_backface_culling = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        output = nodes.new("ShaderNodeOutputMaterial")
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    for k, (which, socket) in enumerate((("color", "Base Color"), ("metal", "Metallic"), ("rough", "Roughness"))):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = images[which]
        tex.interpolation = "Closest"
        tex.location = (-420, 240 - k * 280)
        links.new(tex.outputs["Color"], bsdf.inputs[socket])

    glow = bpy.data.materials.new("M_Props_Glow")
    glow.use_nodes = True
    glow.use_backface_culling = True
    nodes = glow.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (1.0, 0.72, 0.2, 1)
    emission.inputs["Strength"].default_value = 3.0
    output = nodes.new("ShaderNodeOutputMaterial")
    glow.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return mat, glow


def make_object(name, part, material, collection, location):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(part.verts, [], [ids for ids, _, _ in part.faces])
    mesh.update()
    mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, (_, color, _) in zip(mesh.polygons, part.faces):
        polygon.use_smooth = False  # everything's flat shaded, to match the low-poly rooms in assets/lowpoly
        uv = swatch_uv(color)
        for loop_index in polygon.loop_indices:
            uv_layer.data[loop_index].uv = uv
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    collection.objects.link(obj)
    return obj


def add_stage(scene, stage):
    ground_mat = bpy.data.materials.get("M_Props_Ground") or bpy.data.materials.new("M_Props_Ground")
    ground_mat.use_nodes = True
    bsdf = next(n for n in ground_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.62, 0.55, 0.45, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    mesh = bpy.data.meshes.new("Props_Ground")
    s = 2000
    mesh.from_pydata([(-s, -s, -0.02), (s, -s, -0.02), (s, s, -0.02), (-s, s, -0.02)], [], [(0, 1, 2, 3)])
    mesh.materials.append(ground_mat)
    stage.objects.link(bpy.data.objects.new("Props_Ground", mesh))

    def sun(name, energy, rotation, angle, shadow=True):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = radians(angle)
        data.use_shadow = shadow
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = [radians(a) for a in rotation]
        stage.objects.link(obj)

    sun("Props_Key", 2.2, (52, 0, -35), 8)
    sun("Props_Fill", 0.7, (65, 0, 150), 30, False)
    cam_data = bpy.data.cameras.new("Props_Camera")
    cam_data.lens = 60
    cam_data.clip_end = 5000
    cam = bpy.data.objects.new("Props_Camera", cam_data)
    stage.objects.link(cam)
    scene.camera = cam

    world = bpy.data.worlds.get("Props_World") or bpy.data.worlds.new("Props_World")
    scene.world = world
    world.use_nodes = True
    background = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if background:
        background.inputs[0].default_value = (0.72, 0.8, 0.9, 1)
        background.inputs[1].default_value = 0.8

    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 620
    scene.render.image_settings.file_format = "PNG"
    return cam


def bounds(part):
    low = V((min(v.x for v in part.verts), min(v.y for v in part.verts), min(v.z for v in part.verts)))
    high = V((max(v.x for v in part.verts), max(v.y for v in part.verts), max(v.z for v in part.verts)))
    return low, high


def build():
    remove_scene()
    scene = bpy.data.scenes.new(SCENE_NAME)
    props = bpy.data.collections.new("TR_Props")
    stage = bpy.data.collections.new("TR_Props_Stage")
    scene.collection.children.link(props)
    scene.collection.children.link(stage)
    images = make_palette_images()
    palette, glow = make_materials(images)
    cam = add_stage(scene, stage)

    shots = {}
    row_objects = {}
    report = []
    row_y = 0
    for row_name, spots in ROWS.items():
        # Lay the row out left to right, with room between the pieces.
        x = 0
        row_low, row_high = V((1e9, 1e9, 1e9)), V((-1e9, -1e9, -1e9))
        row_objects[row_name] = []
        for spot in spots:
            parts = [(name, PIECES[name]()) for name in spot]
            lows, highs = zip(*[bounds(part) for _, part in parts])
            low_x = min(v.x for v in lows)
            high_x = max(v.x for v in highs)
            low_z = min(v.z for v in lows)
            at = V((x - low_x, row_y, -low_z))
            for (name, part), low, high in zip(parts, lows, highs):
                row_objects[row_name].append(make_object(name, part, glow if name.endswith("_Glow") else palette, props, at))
                size = high - low
                report.append(f"{name}: {size.x:.1f} x {size.y:.1f} x {size.z:.1f}, {sum(len(ids) - 2 for ids, _, _ in part.faces)} tris")
                row_low = V((min(row_low.x, at.x + low.x), min(row_low.y, at.y + low.y), min(row_low.z, at.z + low.z)))
                row_high = V((max(row_high.x, at.x + high.x), max(row_high.y, at.y + high.y), max(row_high.z, at.z + high.z)))
            x += high_x - low_x + max(4.0, (high_x - low_x) * 0.25)
        shots[row_name] = (row_low, row_high)
        row_y += 120

    # Preview only: the boost pad's other two chevrons, and the ring tilted the way it spins in the game.
    pad = bpy.data.objects["BoostPad_Base"]
    chevron = bpy.data.objects["BoostPad_Chevron_Glow"]
    chevron.location = pad.location + V((0, 0, 0.36))
    for y in (-7, 7):
        extra = bpy.data.objects.new("Preview_Chevron", chevron.data)
        extra.location = pad.location + V((0, y, 0.36))
        stage.objects.link(extra)
        row_objects["items"].append(extra)
    bpy.data.objects["ItemBox_Halo_Glow"].rotation_euler = (radians(18), radians(10), 0)
    # The box floats in the game, so show it floating.
    for name in ("ItemBox_Body", "ItemBox_Glow", "ItemBox_Halo_Glow"):
        bpy.data.objects[name].location.z = BOX_HALF + 4
    bpy.context.view_layer.update()

    os.makedirs(RENDER_DIR, exist_ok=True)
    for name, (low, high) in shots.items():
        # Only this row shows in its shot.
        for row, objs in row_objects.items():
            for obj in objs:
                obj.hide_render = row != name
        center = (low + high) / 2
        if name == "items":
            center.z += 3
        size = high - low
        # Enough room for the row's width at this lens, with a margin.
        reach = max(size.x, size.z * 1.9, size.y * 0.8) * 1.75
        direction = V((0.16, -1, 0.42)).normalized()
        cam.location = center + direction * reach
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{RENDER_DIR}/{name}.png"
        with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], scene=scene):
            bpy.ops.render.render(write_still=True, scene=SCENE_NAME)
    for objs in row_objects.values():
        for obj in objs:
            obj.hide_render = False
    print("\n".join(report))
    print("total tris:", sum(int(line.split(", ")[1].split()[0]) for line in report))


build()
