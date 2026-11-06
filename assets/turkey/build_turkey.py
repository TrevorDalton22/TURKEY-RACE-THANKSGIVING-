"""Builds the Turkey Race turkey in the open Blender file. Safe to run again: it replaces only what it made.

The model faces -Y (Blender's front view), stands on Z = 0 with its feet, and is sized so 1 Blender unit is
about 1 stud. Each part that moves on its own is a separate object with its origin at its joint, parented
in a chain under Turkey_Root, and its vertices are in a vertex group named after its bone (Body, Head,
Wing_L, ...). So it can be rigged either way: parts + Motor6Ds in Roblox, or join everything into one mesh
and add an armature with those bone names for a single skinned mesh.

All colors come from one palette texture (every face's UVs sit on one swatch), so the whole turkey is one
material, and a new skin is just a different palette image.
"""

import math
import os
from math import cos, pi, radians, sin

import bpy
from mathutils import Matrix
from mathutils import Vector as V

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/turkey"

# name: (sRGB hex, roughness, metalness)
PALETTE = {
    # Body, darkest on the back to lightest on the belly
    "back_dark": ("54290F", 0.7, 0.0),
    "body_dark": ("6B3517", 0.7, 0.0),
    "body_mid": ("86471F", 0.7, 0.0),
    "body_warm": ("A65C27", 0.7, 0.0),
    "breast": ("C86F2B", 0.65, 0.0),
    "belly": ("E2A357", 0.7, 0.0),
    "cream": ("FBEBC6", 0.7, 0.0),
    "gold": ("FFC42E", 0.5, 0.1),
    "rust": ("CC5426", 0.6, 0.0),
    "chestnut": ("74391A", 0.65, 0.0),
    "dark": ("361B0B", 0.6, 0.0),
    # Tail colors; the teal and plum have a metallic sheen, like a real turkey's iridescence
    "red": ("E0302A", 0.5, 0.0),
    "orange": ("F88427", 0.5, 0.0),
    "marigold": ("FFB516", 0.5, 0.0),
    "teal": ("12ABA0", 0.32, 0.55),
    "plum": ("7D3DB0", 0.32, 0.55),
    # The shaded side of a feather's rib
    "red_d": ("B4201F", 0.5, 0.0),
    "orange_d": ("D76816", 0.5, 0.0),
    "marigold_d": ("E7970B", 0.5, 0.0),
    "teal_d": ("0B8780", 0.32, 0.55),
    "plum_d": ("612C90", 0.32, 0.55),
    "rust_d": ("A5401B", 0.6, 0.0),
    "chestnut_d": ("5B2A11", 0.65, 0.0),
    "cream_d": ("E9D3A6", 0.7, 0.0),
    "gold_d": ("E5A71C", 0.5, 0.1),
    "body_warm_d": ("8A4A1D", 0.7, 0.0),
    # Head and neck
    "head": ("71CFE3", 0.55, 0.0),
    "head_light": ("9BE2EF", 0.55, 0.0),
    "head_shade": ("49ADC9", 0.55, 0.0),
    "blush": ("F58E9B", 0.55, 0.0),
    "neck": ("EE6A5F", 0.5, 0.0),
    "neck_dark": ("C9413E", 0.5, 0.0),
    "wattle": ("E8212E", 0.32, 0.0),
    "wattle_dark": ("B51521", 0.32, 0.0),
    "beak": ("FFBB22", 0.35, 0.0),
    "beak_dark": ("F2920F", 0.35, 0.0),
    "mouth": ("7E1620", 0.5, 0.0),
    "tongue": ("FF7F92", 0.35, 0.0),
    # Legs and feet
    "foot": ("FF8C12", 0.42, 0.0),
    "foot_dark": ("E56E06", 0.42, 0.0),
    "claw": ("FFF0CF", 0.35, 0.0),
    # The saddle stays the same on every skin
    "saddle": ("7D4722", 0.5, 0.0),
    "saddle_dark": ("4F2A12", 0.5, 0.0),
    "blanket": ("C92F2C", 0.7, 0.0),
    "blanket_trim": ("FFC42E", 0.45, 0.2),
    # Eyes
    "eye_white": ("FFFFFF", 0.12, 0.0),
    "pupil": ("14100D", 0.08, 0.0),
    "highlight": ("FFFFFF", 0.1, 0.0),
}
RIB_SHADE = {
    "red": "red_d",
    "orange": "orange_d",
    "marigold": "marigold_d",
    "teal": "teal_d",
    "plum": "plum_d",
    "rust": "rust_d",
    "chestnut": "chestnut_d",
    "cream": "cream_d",
    "gold": "gold_d",
    "body_warm": "body_warm_d",
}
SWATCH_NAMES = list(PALETTE)
SWATCHES_ACROSS = 8
TEXTURE_SIZE = 256


def swatch_uv(name):
    i = SWATCH_NAMES.index(name)
    return ((i % SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS, (i // SWATCHES_ACROSS + 0.5) / SWATCHES_ACROSS)


# Geometry helpers ---------------------------------------------------------------------------------------


def clamp(x, low, high):
    return max(low, min(high, x))


def frame(T, hint):
    """Two axes X, Y across direction T, with X x Y = T, so rings built on them wind outward."""
    T = T.normalized()
    X = hint.cross(T)
    if X.length < 1e-4:
        X = V((1, 0, 0)).cross(T)
    X.normalize()
    return X, T.cross(X)


def ring(center, X, Y, rx, ry, n, phase=0.0):
    points = []
    for j in range(n):
        a = 2 * pi * (j + phase) / n
        points.append(center + X * (rx * cos(a)) + Y * (ry * sin(a)))
    return points


class Part:
    """Vertices and faces for one object; each face names its palette swatch."""

    def __init__(self, group):
        self.verts = []
        self.groups = []
        self.faces = []
        self.group = group

    def add(self, p):
        self.verts.append(V(p))
        self.groups.append(self.group)
        return len(self.verts) - 1

    def face(self, ids, color, smooth=False):
        self.faces.append((list(ids), color, smooth))

    def center(self, ids):
        total = V((0, 0, 0))
        for i in ids:
            total += self.verts[i]
        return total / len(ids)

    def loft(self, rings, color, smooth=False, cap_start=True, cap_end=True):
        """Skins rings in order into quads. A ring of one point is a pole. color is a swatch name or
        color(face_center, gap, segment). Rings must follow frame(): the spine runs along X x Y."""
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

    def mirrored(self, group):
        other = Part(group)
        other.verts = [V((-p.x, p.y, p.z)) for p in self.verts]
        other.groups = [group for _ in self.verts]
        other.faces = [(list(reversed(ids)), color, smooth) for ids, color, smooth in self.faces]
        return other


def blob(part, center, rx, ry, rz, color, n=6, rings=3):
    """A faceted lump."""
    X, Y = frame(V((0, 0, 1)), V((0, 1, 0)))
    points = [[center + V((0, 0, -rz))]]
    for i in range(1, rings + 1):
        a = -pi / 2 + pi * i / (rings + 1)
        points.append(ring(center + V((0, 0, rz * sin(a))), X, Y, rx * cos(a), ry * cos(a), n, phase=(i % 2) * 0.5))
    points.append([center + V((0, 0, rz))])
    part.loft(points, color)


def feather_width(t):
    """Narrow at the quill, full by the middle, rounded at the tip."""
    if t < 0.55:
        return 0.34 + 0.66 * (t / 0.55) ** 0.8
    x = (t - 0.55) / 0.45
    return math.sqrt(max(0.0, 1 - x * x))


def feather(part, base, T, N, length, width, stops, bands, thick=0.09, bend=0.0, sweep=0.0, back=None):
    """A whole feather with a raised rib, seen from both sides. stops are positions along it (the last is the
    tip point), and bands[i] colors the stretch from stops[i] to stops[i + 1]. back recolors the far side."""
    T = T.normalized()
    N = (N - T * N.dot(T)).normalized()
    S = N.cross(T)

    def spine(t):
        return base + T * (length * t) + N * (bend * length * t * t) + S * (sweep * length * t * t)

    rings = []
    for t in stops[:-1]:
        c = spine(t)
        w = width * 0.5 * feather_width(t)
        h = thick * (0.45 + 0.55 * feather_width(t))
        rings.append([c + S * w, c + N * h, c - S * w, c - N * h])
    rings.append([spine(1.0)])

    def color(center, i, j):
        i = min(i, len(bands) - 1)
        name = back[i] if back and j >= 2 else bands[i]
        # One side of the rib is painted darker, so it looks folded whatever the lighting.
        return RIB_SHADE.get(name, name) if j % 2 == 1 else name

    part.loft(rings, color)


# (along, across) around a body feather: quill, right side, rounded tip, left side.
SHELL_OUTLINE = [(0.0, 0.0), (0.36, -0.5), (0.72, -0.47), (0.97, -0.25), (0.97, 0.25), (0.72, 0.47), (0.36, 0.5)]


def shell(part, base, T, N, length, width, color, tip_color, lift=0.2, project=None):
    """A small one-sided feather lying on a surface, tip lifted a little so rows overlap like shingles, with a
    colored band across its rounded tip. project(point) gives the surface point and normal to hug; without it
    the shell is flat."""
    T = (T - N * T.dot(N)).normalized()
    S = N.cross(T)

    def place(t, s, extra=0.0):
        p = base + T * (length * t) + S * (width * s)
        if project:
            q, n = project(p)
            return q + n * (lift * t + 0.03 + extra)
        return p + N * (lift * t + extra)

    quill, right, right_top, tip_right, tip_left, left_top, left = [part.add(place(t, s)) for t, s in SHELL_OUTLINE]
    middle = part.add(place(0.42, 0.0, 0.1))
    for a, b in ((quill, right), (right, right_top), (right_top, left_top), (left_top, left), (left, quill)):
        part.face([middle, a, b], color)
    part.face([right_top, tip_right, tip_left, left_top], tip_color)


# The body: an egg lofted from chest to rump. (y, center z, half width, half height) ------------------------

BODY_Z = 4.3
BODY_RINGS = [
    (-3.05, 4.55, 0.75, 0.75),
    (-2.70, 4.45, 1.90, 1.85),
    (-1.95, 4.35, 2.70, 2.40),
    (-1.00, 4.30, 3.00, 2.55),
    (0.10, 4.35, 3.00, 2.45),
    (1.25, 4.55, 2.60, 2.10),
    (2.20, 4.85, 1.90, 1.55),
    (2.90, 5.25, 1.05, 0.90),
    (3.20, 5.45, 0.40, 0.35),
]


def body_at(y):
    if y <= BODY_RINGS[0][0] or y >= BODY_RINGS[-1][0]:
        return None
    for a, b in zip(BODY_RINGS, BODY_RINGS[1:]):
        if a[0] <= y <= b[0]:
            k = (y - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * k for i in (1, 2, 3))
    return None


def inside_body(p):
    r = body_at(p.y)
    if not r:
        return False
    cz, rx, rz = r
    return (p.x / rx) ** 2 + ((p.z - cz) / rz) ** 2 <= 1


def body_surface(p):
    """The point on the body straight out from its core through p, and the outward direction there."""
    core = V((0, 0, BODY_Z))
    d = p - core
    if d.length < 1e-4:
        d = V((0, 0, 1))
    d.normalize()
    low, high = 0.0, 8.0
    for _ in range(22):
        mid = (low + high) / 2
        if inside_body(core + d * mid):
            low = mid
        else:
            high = mid
    return core + d * low, d


# Where the rider sits: the middle of the saddle's seat, along the turkey and at the top of the seat.
SEAT_Y = 0.5
SEAT_TOP = 7.39


def build_saddle(m, core, X, Y):
    """A red blanket with a gold edge draped over the back, a leather seat on it, and a girth strap."""
    xs = (-2.1, -1.72, -0.86, 0.0, 0.86, 1.72, 2.1)
    ys = (-0.85, -0.55, 0.5, 1.6, 1.9)
    grid = []
    for y in ys:
        row = []
        cz, rx, rz = body_at(y)
        for x in xs:
            # Straight down onto the top of the body at this spot.
            z = cz + rz * math.sqrt(max(0.0, 1 - (x / rx) ** 2))
            n = V((x / rx**2, 0, (z - cz) / rz**2)).normalized()
            # Hugging the body at the outer edge, so there's no gap to see under it.
            edge = max(abs(x) / 2.1, abs(y - SEAT_Y) / 1.4)
            row.append(m.add(V((x, y, z)) + n * (0.14 if edge > 0.99 else 0.36)))
        grid.append(row)
    for i in range(len(ys) - 1):
        for j in range(len(xs) - 1):
            trim = i in (0, len(ys) - 2) or j in (0, len(xs) - 2)
            m.face([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]], "blanket_trim" if trim else "blanket")

    # The seat dips in the middle, with a pommel in front and a higher cantle behind.
    rings = [[V((0, SEAT_Y - 1.2, 7.48))]]
    for dy, z, rx, rz in ((-1.15, 7.4, 0.9, 0.36), (-0.8, 7.25, 1.2, 0.3), (0.0, 7.15, 1.35, 0.24), (0.8, 7.25, 1.2, 0.3), (1.2, 7.48, 0.95, 0.38)):
        rings.append(ring(V((0, SEAT_Y + dy, z)), X, Y, rx, rz, 8))
    rings.append([V((0, SEAT_Y + 1.3, 7.6))])
    m.loft(rings, lambda c, i, j: "saddle_dark" if i in (0, 1, 4, 5) else "saddle")

    # The girth strap around the belly, just proud of the body.
    strap = []
    for y in (SEAT_Y - 0.22, SEAT_Y + 0.22):
        cz, rx, rz = body_at(y)
        strap.append(ring(V((0, y, cz)), X, Y, rx * 1.03, rz * 1.03, 16))
    m.loft(strap, "saddle_dark", cap_start=False, cap_end=False)


def build_body():
    m = Part("Body")
    X, Y = frame(V((0, 1, 0)), V((0, 0, 1)))

    def color(center, i, j):
        z = center.z
        if center.y < -1.7 and z > 2.6:
            return "breast"
        if z > 5.9:
            return "back_dark"
        if z > 5.0:
            return "body_dark"
        if z > 4.0:
            return "body_mid"
        if z > 2.9:
            return "body_warm"
        return "belly"

    rings = [[V((0, -3.25, 4.6))]]
    for y, cz, rx, rz in BODY_RINGS:
        # frame() made X sideways and Y up here.
        rings.append(ring(V((0, y, cz)), X, Y, rx, rz, 16))
    rings.append([V((0, 3.35, 5.5))])
    m.loft(rings, color)

    core = V((0, 0, BODY_Z))

    def lay(d, flow, length, width, base_color, tip_color, lift=0.22):
        q, n = body_surface(core + d * 8)
        shell(m, q, flow, n, length, width, base_color, tip_color, lift, project=body_surface)

    def both_sides(angles):
        """Each angle and its mirror, so the two halves match."""
        return [a * s for a in angles for s in ((1, -1) if a else (1,))]

    # A bib of neat scales down the chest, each row staggered from the last, reddest at the top and
    # paling toward the belly. (height above the middle of the chest in degrees, then across it)
    chest = (
        (20.5, (0, 18, 36), "rust", "marigold"),
        (8, (9, 27, 45), "breast", "marigold"),
        (-4.5, (0, 18, 36, 54), "breast", "belly"),
        (-17, (9, 27, 45), "breast", "belly"),
        (-29.5, (0, 18, 36), "belly", "cream"),
    )
    for pitch, yaws, base_color, tip_color in chest:
        for yaw in both_sides(yaws):
            ya, pa = radians(yaw), radians(pitch)
            d = V((sin(ya) * cos(pa), -cos(ya) * cos(pa), sin(pa)))
            lay(d, V((0, 0.35, -1)), 1.08, 1.08, base_color, tip_color)

    # Feathers behind the saddle flowing toward the tail, and a few along the flanks below the wings.
    # (how far along the body, then around it from the spine)
    cape = (
        (1.95, (0, 24, 48, 72), "body_warm", "breast"),
        (2.6, (12, 36, 60), "body_mid", "body_warm"),
        (-0.75, (116, 138), "body_warm", "belly"),
        (1.3, (112, 134), "body_warm", "belly"),
    )
    for y, angles, base_color, tip_color in cape:
        cz, rx, rz = body_at(y)
        for angle in both_sides(angles):
            a = radians(angle)
            d = (V((sin(a) * rx, y, cz + cos(a) * rz)) - core).normalized()
            lay(d, V((sin(a) * 0.25, 1, -0.15)), 1.3, 1.26, base_color, tip_color)

    build_saddle(m, core, X, Y)

    # The little beard real toms have, hanging off the chest.
    for dx, length in ((-0.2, 1.05), (0.2, 1.05), (0.0, 1.3)):
        feather(m, V((dx, -2.98, 4.15)), V((dx * 0.25, -0.2, -1)), V((0, -1, 0.1)), length, 0.34, (0, 0.5, 1), ("dark", "back_dark"), thick=0.07)
    return m


def build_neck():
    m = Part("Neck")
    points = [(V((0, -1.9, 5.3)), 1.0), (V((0, -2.55, 6.3)), 0.86), (V((0, -2.95, 7.2)), 0.68), (V((0, -2.95, 7.95)), 0.62)]
    rings = []
    for i, (c, r) in enumerate(points):
        a = points[max(i - 1, 0)][0]
        b = points[min(i + 1, len(points) - 1)][0]
        X, Y = frame(b - a, V((0, 1, 0)))
        rings.append(ring(c, X, Y, r, r, 10))
    m.loft(rings, lambda c, i, j: "neck_dark" if i == 0 else "neck")

    # A zigzag collar of iridescent feathers where the neck meets the body.
    up = V((0, -0.545, 0.838)).normalized()
    center = V((0, -2.42, 6.25))
    X, Y = frame(-up, V((0, 1, 0)))
    tufts = 10

    def over_body(p, gap):
        """Behind the neck the collar would sink into the body; lift it to lie on top instead."""
        if inside_body(p):
            q, n = body_surface(p)
            return q + n * gap
        return p

    back = V((0, up.z, -up.y))  # along the back, toward the saddle

    def collar_ring(drop, radius, gap, tuck, phase=0.0):
        """A ring around the neck, pulled in behind the neck so it stops short of the saddle."""
        middle = center - up * drop
        points = []
        for p in ring(middle, X, Y, radius, radius, tufts, phase):
            out = (p - middle).normalized()
            points.append(over_body(middle + out * (radius * (1 - tuck * max(0.0, out.dot(back)))), gap))
        return [m.add(p) for p in points]

    top = collar_ring(0.0, 0.96, 0.08, 0.0)
    notches = collar_ring(0.42, 1.42, 0.2, 0.22)
    tips = collar_ring(0.95, 2.05, 0.42, 0.42, phase=0.5)
    for j in range(tufts):
        k = (j + 1) % tufts
        m.face([top[j], top[k], notches[k], notches[j]], "teal" if j % 2 else "plum")
        m.face([notches[j], notches[k], tips[j]], "gold")
    return m


# The head --------------------------------------------------------------------------------------------------

HEAD = V((0, -3.15, 8.95))
EYE_L = HEAD + V((0.94, -1.12, 0.46))
EYE_R = HEAD + V((-0.94, -1.16, 0.38))
EYE_L_RADIUS = 0.98
EYE_R_RADIUS = 0.82
# The way each pupil points. They disagree, which is the joke.
LOOK_L = V((0.30, -1, 0.12)).normalized()
LOOK_R = V((-0.08, -1, -0.20)).normalized()
JAW = HEAD + V((0, -1.3, -0.66))


def eyelid(m, center, radius, look, opening, tilt):
    """A cap over the top of an eye. opening is how far above the pupil its edge sits, in degrees; tilt turns
    it around the eye for expression."""
    up = (V((0, 0, 1)) - look * V((0, 0, 1)).dot(look)).normalized()
    side = look.cross(up)
    t = radians(tilt)
    up = up * cos(t) + side * sin(t)
    rim = radians(76)
    pole_angle = radians(opening) + rim
    pole = look * cos(pole_angle) + up * sin(pole_angle)
    X, Y = frame(-pole, look)
    outer = radius * 1.07
    rings = [[center + pole * outer]]
    for angle, r in ((rim * 0.55, outer), (rim, outer), (rim, radius * 0.98)):
        rings.append(ring(center + pole * (r * cos(angle)), X, Y, r * sin(angle), r * sin(angle), 12))
    m.loft(rings, lambda c, i, j: "head_shade" if i >= 2 else "head", cap_end=False)


def build_head():
    m = Part("Head")
    X, Y = frame(V((0, 0, 1)), V((0, 1, 0)))

    def color(center, i, j):
        rel = center - HEAD
        if abs(rel.x) > 1.0 and -0.8 < rel.z < -0.3 and rel.y < -0.45:
            return "blush"
        if rel.z < -0.9:
            return "head_shade"
        if rel.z > 0.95:
            return "head_light"
        return "head"

    rings = [[HEAD + V((0, 0, -1.62))]]
    for dz, rx, ry, dy in ((-1.35, 0.9, 0.85, -0.05), (-0.75, 1.5, 1.4, -0.1), (0.0, 1.75, 1.6, -0.05), (0.7, 1.6, 1.45, 0.0), (1.25, 1.05, 0.95, 0.0)):
        rings.append(ring(HEAD + V((0, dy, dz)), X, Y, rx, ry, 12))
    rings.append([HEAD + V((0, 0, 1.6))])
    m.loft(rings, color)

    # Upper beak, curving down at the tip; dark mouth color underneath.
    bx, by = frame(V((0, -1, 0)), V((0, 0, 1)))
    base = HEAD + V((0, -1.28, -0.34))

    def beak_color(center, i, j):
        if center.z < base.z - 0.1 - i * 0.05:
            return "mouth"
        return "beak_dark" if i >= 2 else "beak"

    beak = []
    for d, drop, rx, rz in ((0.0, 0.0, 0.82, 0.52), (0.75, 0.0, 0.68, 0.44), (1.3, -0.1, 0.4, 0.27)):
        beak.append(ring(base + V((0, -d, drop)), bx, by, rx, rz, 8))
    beak.append([base + V((0, -1.72, -0.36))])
    m.loft(beak, beak_color)

    eyelid(m, EYE_L, EYE_L_RADIUS, LOOK_L, 40, 8)
    eyelid(m, EYE_R, EYE_R_RADIUS, LOOK_R, 14, -10)

    # A silly cowlick on top.
    top = HEAD + V((0, 0.1, 1.45))
    for dx, lean, length, colors in ((0, 0.0, 1.35, ("rust", "gold")), (0.3, 0.55, 1.05, ("rust", "orange")), (-0.3, -0.55, 1.05, ("rust", "orange"))):
        feather(m, top + V((dx, 0, 0)), V((lean, 0.35, 1)), V((0, -1, 0.3)), length, 0.42, (0, 0.5, 1), colors, thick=0.07, bend=-0.32)
    return m


def build_eye(center, radius, look, name):
    m = Part(name)
    X, Y = frame(-look, V((0, 0, 1)))
    angles = (17, 31, 50, 72, 96, 124)
    rings = [[center + look * radius]]
    for degrees in angles:
        a = radians(degrees)
        rings.append(ring(center + look * (radius * cos(a)), X, Y, radius * sin(a), radius * sin(a), 16))
    m.loft(rings, lambda c, i, j: "pupil" if i <= 1 else "eye_white", smooth=True, cap_end=False)

    # A glint on the pupil, on the same side of both eyes and low enough to clear the eyelids.
    glint = (look + V((-0.27, 0, 0.09))).normalized()
    gx, gy = frame(glint, V((0, 0, 1)))
    disc = ring(center + glint * (radius * 1.012), gx, gy, radius * 0.16, radius * 0.16, 8)
    ids = [m.add(p) for p in disc]
    middle = m.add(center + glint * (radius * 1.03))
    for i in range(8):
        m.face([middle, ids[i], ids[(i + 1) % 8]], "highlight")
    return m


def build_beak_lower():
    m = Part("Beak_Lower")
    X, Y = frame(V((0, -1, -0.32)), V((0, 0, 1)))
    T = V((0, -1, -0.32)).normalized()

    def color(center, i, j):
        lift = (center - JAW).dot(Y)
        return "mouth" if lift > 0.02 else "beak_dark"

    rings = []
    for d, rx, ry in ((0.0, 0.66, 0.26), (0.6, 0.52, 0.22)):
        rings.append(ring(JAW + T * d, X, Y, rx, ry, 8))
    rings.append([JAW + T * 1.12 + Y * -0.04])
    m.loft(rings, color)

    # The tongue flops out of one side.
    tongue = []
    points = [(JAW + T * 0.1 + Y * 0.2, 0.26, 0.09), (JAW + T * 0.7 + Y * 0.22 + X * 0.05, 0.25, 0.09), (JAW + T * 1.05 + Y * -0.02 + V((0.2, 0, 0)), 0.2, 0.08)]
    for i, (c, rx, ry) in enumerate(points):
        a = points[max(i - 1, 0)][0]
        b = points[min(i + 1, len(points) - 1)][0]
        tx, ty = frame(b - a, V((0, 0, 1)))
        tongue.append(ring(c, tx, ty, rx, ry, 6))
    tongue.append([JAW + T * 1.32 + Y * -0.26 + V((0.24, 0, 0))])
    m.loft(tongue, "tongue")
    return m


def build_snood():
    """The floppy red thing that drapes over a turkey's beak."""
    m = Part("Snood")
    points = [
        (HEAD + V((0.05, -1.5, -0.02)), 0.22),
        (HEAD + V((0.2, -1.98, 0.02)), 0.24),
        (HEAD + V((0.46, -2.34, -0.3)), 0.21),
        (HEAD + V((0.58, -2.46, -0.85)), 0.26),
    ]
    rings = []
    for i, (c, r) in enumerate(points):
        a = points[max(i - 1, 0)][0]
        b = points[min(i + 1, len(points) - 1)][0]
        X, Y = frame(b - a, V((1, 0, 0)))
        rings.append(ring(c, X, Y, r, r, 6))
    rings.append([HEAD + V((0.6, -2.48, -1.22))])
    m.loft(rings, lambda c, i, j: "wattle_dark" if i >= 3 else "wattle")
    return m


def build_wattle():
    m = Part("Wattle")
    blob(m, HEAD + V((0.34, -0.95, -1.4)), 0.46, 0.42, 0.58, "wattle")
    blob(m, HEAD + V((-0.32, -0.9, -1.5)), 0.5, 0.44, 0.62, "wattle")
    blob(m, HEAD + V((0.0, -0.95, -2.02)), 0.36, 0.32, 0.46, "wattle_dark")
    return m


# Wings, tail and legs ------------------------------------------------------------------------------------------

SHOULDER_L = V((2.72, -0.75, 5.2))


def build_wing_left():
    """A comically small wing, held a little out from the body: a stub of an arm with a few chunky feathers."""
    m = Part("Wing_L")
    T = V((0.52, 0.72, -0.42)).normalized()
    N = V((0.85, -0.5, 0.25))
    N = (N - T * N.dot(T)).normalized()
    X, Y = frame(T, N)  # X lies in the wing and points up and back; Y points out of it

    arm = []
    for t, wide, deep in ((-0.3, 0.3, 0.24), (0.2, 0.56, 0.34), (0.7, 0.58, 0.28), (1.0, 0.36, 0.16)):
        arm.append(ring(SHOULDER_L + T * t, X, Y, wide, deep, 8))
    m.loft(arm, lambda c, i, j: "rust" if i < 2 else "breast")

    # Primary feathers fanning from the end of the arm, like stubby fingers.
    primaries = ((30, 0.34, 1.3, "cream"), (10, 0.16, 1.55, "marigold"), (-10, 0.0, 1.65, "cream"), (-30, -0.18, 1.5, "marigold"), (-50, -0.34, 1.2, "cream"))
    for angle, offset, length, tip in primaries:
        a = radians(angle)
        direction = T * cos(a) + X * sin(a)
        base = SHOULDER_L + T * 0.6 + X * offset + Y * (0.08 - abs(offset) * 0.12)
        feather(m, base, direction, N, length, 0.74, (0, 0.42, 0.72, 0.93, 1), ("rust", "orange", tip, tip), thick=0.13, bend=-0.14, back=("chestnut", "rust", tip, tip))

    # Shorter coverts over the top of them.
    for angle, offset, length in ((24, 0.28, 0.95), (-8, 0.0, 1.1), (-40, -0.28, 0.9)):
        a = radians(angle)
        direction = T * cos(a) + X * sin(a)
        base = SHOULDER_L + T * 0.12 + X * offset + Y * 0.26
        feather(m, base, direction, N, length, 0.66, (0, 0.6, 0.92, 1), ("rust", "gold", "gold"), thick=0.11, bend=-0.12)
    return m


TAIL_BASE = V((0, 2.55, 5.35))
TAIL_LEAN = radians(17)
# The big fan's colors, from the middle feather out to the edge.
FAN_COLORS = ("red", "orange", "marigold", "teal", "red", "plum")


def build_tail():
    m = Part("Tail")
    up = V((0, sin(TAIL_LEAN), cos(TAIL_LEAN)))
    side = V((1, 0, 0))
    front = side.cross(up).normalized()  # toward the head

    def spoke(angle):
        a = radians(angle)
        return side * sin(a) + up * cos(a)

    # The big fan. The middle feather sits in front and the rest step back, like a hand of cards.
    stops = (0, 0.22, 0.54, 0.74, 0.83, 0.95, 1)
    count = 11
    for i in range(count):
        step = i - (count - 1) // 2
        m.group = f"TailFeather_{i + 1:02d}"
        main = FAN_COLORS[abs(step)]
        direction = spoke(step * 16.8)
        base = TAIL_BASE + direction * 0.3 + front * (-abs(step) * 0.08)
        feather(
            m, base, direction, front, 5.5, 1.62, stops,
            ("chestnut", main, main, "dark", "cream", "cream"),
            thick=0.24, bend=-0.07,
            back=("back_dark", main, main, "dark", "cream", "cream"),
        )

    # Two shorter layers in front of it, still chunky so they read from far away.
    m.group = "Tail"
    count = 9
    for i in range(count):
        step = i - (count - 1) // 2
        direction = spoke(step * 18.5)
        base = TAIL_BASE + front * (0.42 - abs(step) * 0.05)
        feather(m, base, direction, front, 3.75, 1.35, (0, 0.38, 0.72, 0.86, 0.97, 1), ("chestnut", "body_warm", "dark", "gold", "gold"), thick=0.18, bend=-0.05)
    count = 7
    for i in range(count):
        step = i - (count - 1) // 2
        direction = spoke(step * 20)
        base = TAIL_BASE + front * (0.82 - abs(step) * 0.04)
        feather(m, base, direction, front, 2.4, 1.1, (0, 0.6, 0.93, 1), ("body_dark", "rust", "rust"), thick=0.14, bend=-0.04)

    # Fluffy feathers covering the rump from behind.
    for x, z, length in ((0, 5.2, 1.5), (0.72, 5.3, 1.3), (-0.72, 5.3, 1.3)):
        feather(m, V((x, 3.0, z + 0.3)), V((x * 0.25, 0.35, -1)), V((0, 1, 0.2)), length, 1.05, (0, 0.6, 0.93, 1), ("chestnut", "belly", "belly"), thick=0.12)
    return m


HIP_L = V((1.52, 0.5, 3.25))
KNEE_L = V((1.64, 0.38, 1.6))
ANKLE_L = V((1.62, 0.18, 0.52))


def build_thigh_left():
    m = Part("Thigh_L")
    X, Y = frame(KNEE_L - HIP_L, V((0, 1, 0)))
    span = KNEE_L - HIP_L
    # A plump drumstick that flares into a fluffy cuff above the bare leg.
    rings = []
    for t, r in ((-0.1, 0.8), (0.35, 1.08), (0.68, 1.0), (0.8, 1.02), (0.9, 0.5), (1.02, 0.3)):
        rings.append(ring(HIP_L + span * t, X, Y, r, r, 8, phase=0.5))
    m.loft(rings, lambda c, i, j: "body_warm" if i < 2 else ("belly" if i < 4 else "body_mid"))
    return m


def build_shank_left():
    m = Part("Shank_L")
    X, Y = frame(ANKLE_L - KNEE_L, V((0, 1, 0)))
    span = ANKLE_L - KNEE_L
    rings = []
    for t, r in ((-0.12, 0.3), (0.45, 0.25), (1.05, 0.25)):
        rings.append(ring(KNEE_L + span * t, X, Y, r, r, 6))
    m.loft(rings, lambda c, i, j: "foot_dark" if i == 0 else "foot")
    return m


def build_foot_left():
    m = Part("Foot_L")
    palm = V((ANKLE_L.x, 0.1, 0.0))
    blob(m, palm + V((0, 0, 0.3)), 0.62, 0.62, 0.3, "foot", n=8, rings=2)

    def toe(angle, length, width):
        a = radians(angle)
        T = V((sin(a), -cos(a), 0))
        X, Y = frame(T, V((0, 0, 1)))
        rings = []
        # A hexagon's flat bottom sits 0.866 of its radius below the center, so this rests on the ground.
        for t, rx, rz in ((0.0, width, 0.27), (0.48, width * 0.86, 0.25), (0.8, width * 0.58, 0.18)):
            height = rz / 0.866 * 0.866
            rings.append(ring(palm + T * (length * t) + V((0, 0, height)), X, Y, rx, rz / 0.866, 6))
        rings.append([palm + T * length + V((0, 0, 0.07))])
        m.loft(rings, lambda c, i, j: "claw" if i >= 2 else ("foot_dark" if c.z < 0.12 else "foot"))

    toe(-33, 1.75, 0.4)
    toe(0, 2.1, 0.44)
    toe(33, 1.75, 0.4)
    toe(180, 1.05, 0.34)
    return m


# Putting it in Blender ------------------------------------------------------------------------------------------

NOTES = """TURKEY RACE TURKEY
Facing -Y, feet on Z = 0, about 1 Blender unit to 1 stud. TR_Preview is only a stage for renders; leave it out of exports.

TR_Rig is the game version: Turkey_Mesh (one skinned mesh) on the armature Turkey_Rig. Its bones are Root, Body, Neck,
Head, Eye_L/R, Beak_Lower, Snood, Wattle, Wing_L/R, Tail, TailFeather_01..11, Thigh_L/R, Shank_L/R and Foot_L/R. Every
vertex is weighted 100% to one bone. Root has no vertices, and stays at the origin. Export Turkey_Rig to get both.

TR_Turkey (excluded from the view layer) is the source: the same parts as separate objects, each with its origin at
its joint.

Colors: every face's UVs sit on one swatch of T_Turkey_Color (with matching T_Turkey_Roughness and T_Turkey_Metalness),
so it's one material, and a new skin only needs a new color image.

build_turkey.py rebuilds all of this; hand edits to the model are lost if it's run again.
"""


def remove_collection(name):
    coll = bpy.data.collections.get(name)
    if not coll:
        return
    for child in list(coll.children):
        remove_collection(child.name)
    for obj in list(coll.objects):
        data = obj.data
        bpy.data.objects.remove(obj)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)
    bpy.data.collections.remove(coll)


def clear_defaults():
    """Takes out Blender's startup objects, which sit right where the turkey goes, and their empty collections."""
    for name in ("Cube", "Camera", "Light"):
        obj = bpy.data.objects.get(name)
        if obj:
            data = obj.data
            bpy.data.objects.remove(obj)
            if data and data.users == 0:
                if isinstance(data, bpy.types.Mesh):
                    bpy.data.meshes.remove(data)
                elif isinstance(data, bpy.types.Camera):
                    bpy.data.cameras.remove(data)
                elif isinstance(data, bpy.types.Light):
                    bpy.data.lights.remove(data)
    for name in ("Collection", "Collection 2"):
        coll = bpy.data.collections.get(name)
        if coll and len(coll.objects) == 0 and len(coll.children) == 0:
            bpy.data.collections.remove(coll)


def make_palette_images():
    os.makedirs(ASSET_DIR + "/textures", exist_ok=True)
    cell = TEXTURE_SIZE // SWATCHES_ACROSS

    def channel(i, which):
        if i >= len(SWATCH_NAMES):
            return (0.5, 0.5, 0.5) if which == "color" else (0.5, 0.5, 0.5) if which == "rough" else (0, 0, 0)
        hex_value, rough, metal = PALETTE[SWATCH_NAMES[i]]
        if which == "color":
            return tuple(int(hex_value[k : k + 2], 16) / 255 for k in (0, 2, 4))
        v = rough if which == "rough" else metal
        return (v, v, v)

    images = {}
    for which, name, colorspace in (("color", "T_Turkey_Color", "sRGB"), ("rough", "T_Turkey_Roughness", "Non-Color"), ("metal", "T_Turkey_Metalness", "Non-Color")):
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


def make_material(images):
    old = bpy.data.materials.get("M_Turkey_Palette")
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new("M_Turkey_Palette")
    mat.use_nodes = True
    # Roblox doesn't draw the backs of faces, so don't here either: a flipped face shows up now, not in-game.
    mat.use_backface_culling = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        output = nodes.new("ShaderNodeOutputMaterial")
        output.location = (300, 0)
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    for k, (which, socket) in enumerate((("color", "Base Color"), ("metal", "Metallic"), ("rough", "Roughness"))):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = images[which]
        tex.interpolation = "Closest"
        tex.location = (-420, 240 - k * 280)
        links.new(tex.outputs["Color"], bsdf.inputs[socket])
    return mat


def make_object(part, name, origin, parent, collection, material):
    """A mesh object with its origin at `origin` (its joint) and no rotation or scale."""
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata([v - origin for v in part.verts], [], [ids for ids, _, _ in part.faces])
    mesh.update()
    mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, (_, color, smooth) in zip(mesh.polygons, part.faces):
        polygon.use_smooth = smooth
        uv = swatch_uv(color)
        for loop_index in polygon.loop_indices:
            uv_layer.data[loop_index].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    parent_origin = parent.matrix_world.translation if parent else V((0, 0, 0))
    if parent:
        obj.parent = parent
    obj.location = origin - parent_origin
    obj.matrix_world.translation = origin
    # A vertex group per bone, so joining everything later gives a mesh that's already weighted.
    by_group = {}
    for index, group in enumerate(part.groups):
        by_group.setdefault(group, []).append(index)
    for group, indices in by_group.items():
        obj.vertex_groups.new(name=group).add(indices, 1.0, "REPLACE")
    bpy.context.view_layer.update()
    return obj


def build():
    remove_collection("TR_Turkey")
    clear_defaults()

    images = make_palette_images()
    material = make_material(images)

    scene = bpy.context.scene
    top = bpy.data.collections.new("TR_Turkey")
    scene.collection.children.link(top)
    sections = {}
    for name in ("Body", "Head", "Wings", "Tail", "Legs"):
        sections[name] = bpy.data.collections.new("Turkey_" + name)
        top.children.link(sections[name])

    root = bpy.data.objects.new("Turkey_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 1.5
    top.objects.link(root)

    made = {}

    def add(part, name, origin, parent, section):
        made[name] = make_object(part, name, origin, parent, sections[section], material)
        return made[name]

    body = add(build_body(), "Turkey_Body", V((0, 0, BODY_Z)), root, "Body")
    neck = add(build_neck(), "Turkey_Neck", V((0, -1.9, 5.3)), body, "Body")
    head = add(build_head(), "Turkey_Head", V((0, -2.95, 7.8)), neck, "Head")
    add(build_eye(EYE_L, EYE_L_RADIUS, LOOK_L, "Eye_L"), "Turkey_Eye_L", EYE_L, head, "Head")
    add(build_eye(EYE_R, EYE_R_RADIUS, LOOK_R, "Eye_R"), "Turkey_Eye_R", EYE_R, head, "Head")
    add(build_beak_lower(), "Turkey_Beak_Lower", JAW, head, "Head")
    add(build_snood(), "Turkey_Snood", HEAD + V((0.05, -1.5, -0.02)), head, "Head")
    add(build_wattle(), "Turkey_Wattle", HEAD + V((0, -0.95, -1.05)), head, "Head")

    wing = build_wing_left()
    add(wing, "Turkey_Wing_L", SHOULDER_L, body, "Wings")
    add(wing.mirrored("Wing_R"), "Turkey_Wing_R", SHOULDER_L * V((-1, 1, 1)), body, "Wings")
    add(build_tail(), "Turkey_Tail", TAIL_BASE, body, "Tail")

    mirror = V((-1, 1, 1))
    thigh = build_thigh_left()
    thigh_l = add(thigh, "Turkey_Thigh_L", HIP_L, body, "Legs")
    thigh_r = add(thigh.mirrored("Thigh_R"), "Turkey_Thigh_R", HIP_L * mirror, body, "Legs")
    shank = build_shank_left()
    shank_l = add(shank, "Turkey_Shank_L", KNEE_L, thigh_l, "Legs")
    shank_r = add(shank.mirrored("Shank_R"), "Turkey_Shank_R", KNEE_L * mirror, thigh_r, "Legs")
    foot = build_foot_left()
    add(foot, "Turkey_Foot_L", ANKLE_L, shank_l, "Legs")
    add(foot.mirrored("Foot_R"), "Turkey_Foot_R", ANKLE_L * mirror, shank_r, "Legs")

    bpy.context.view_layer.update()

    notes = bpy.data.texts.get("Turkey_Notes") or bpy.data.texts.new("Turkey_Notes")
    notes.clear()
    notes.write(NOTES)

    # What it came to.
    total = 0
    low = V((1e9, 1e9, 1e9))
    high = -low
    for name, obj in made.items():
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        total += tris
        print(f"{name:20s} {tris:5d} tris   {len(obj.data.vertices):5d} verts   groups {len(obj.vertex_groups)}")
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            low = V((min(low.x, p.x), min(low.y, p.y), min(low.z, p.z)))
            high = V((max(high.x, p.x), max(high.y, p.y), max(high.z, p.z)))
    print(f"TOTAL {total} tris in {len(made)} meshes, 1 material, {len(SWATCH_NAMES)} swatches")
    print(f"bounds x {low.x:.2f}..{high.x:.2f}  y {low.y:.2f}..{high.y:.2f}  z {low.z:.2f}..{high.z:.2f}")


# The rig: one skinned mesh and an armature, built from the separate parts above --------------------------------


def rig():
    window = bpy.context.window or bpy.context.window_manager.windows[0]
    view_layer = window.view_layer
    remove_collection("TR_Rig")
    old = bpy.data.armatures.get("Turkey_Rig_Data")
    if old:
        bpy.data.armatures.remove(old)

    collection = bpy.data.collections.new("TR_Rig")
    bpy.context.scene.collection.children.link(collection)

    def origin(name):
        return bpy.data.objects[name].matrix_world.translation.copy()

    # (bone, parent, start, end). Each bone starts at its part's joint. Root stays at the origin with no
    # vertices on it, as Roblox asks.
    def side(suffix, x):
        wing = origin("Turkey_Wing_" + suffix)
        return [
            ("Wing_" + suffix, "Body", wing, wing + V((0.52 * x, 0.72, -0.42)) * 2.2),
            ("Thigh_" + suffix, "Body", origin("Turkey_Thigh_" + suffix), origin("Turkey_Shank_" + suffix)),
            ("Shank_" + suffix, "Thigh_" + suffix, origin("Turkey_Shank_" + suffix), origin("Turkey_Foot_" + suffix)),
            ("Foot_" + suffix, "Shank_" + suffix, origin("Turkey_Foot_" + suffix), origin("Turkey_Foot_" + suffix) + V((0, -1.4, -0.4))),
        ]

    tail = origin("Turkey_Tail")
    up = V((0, sin(TAIL_LEAN), cos(TAIL_LEAN)))
    bones = [
        ("Root", None, V((0, 0, 0)), V((0, 0, 1))),
        ("Body", "Root", origin("Turkey_Body"), origin("Turkey_Body") + V((0, 0, 1.2))),
        ("Neck", "Body", origin("Turkey_Neck"), origin("Turkey_Head")),
        ("Head", "Neck", origin("Turkey_Head"), origin("Turkey_Head") + V((0, -0.2, 2.2))),
        ("Eye_L", "Head", origin("Turkey_Eye_L"), origin("Turkey_Eye_L") + LOOK_L),
        ("Eye_R", "Head", origin("Turkey_Eye_R"), origin("Turkey_Eye_R") + LOOK_R),
        ("Beak_Lower", "Head", origin("Turkey_Beak_Lower"), origin("Turkey_Beak_Lower") + V((0, -1, -0.32))),
        ("Snood", "Head", origin("Turkey_Snood"), origin("Turkey_Snood") + V((0.55, -0.95, -1.0))),
        ("Wattle", "Head", origin("Turkey_Wattle"), origin("Turkey_Wattle") + V((0, 0, -1.2))),
        ("Tail", "Body", tail, tail + up * 2.0),
    ]
    bones += side("L", 1) + side("R", -1)
    count = 11
    for i in range(count):
        step = i - (count - 1) // 2
        a = radians(step * 16.8)
        direction = V((sin(a), 0, 0)) + up * cos(a)
        start = tail + direction * 0.3
        bones.append((f"TailFeather_{i + 1:02d}", "Tail", start, start + direction * 4.5))

    data = bpy.data.armatures.new("Turkey_Rig_Data")
    armature = bpy.data.objects.new("Turkey_Rig", data)
    collection.objects.link(armature)
    with bpy.context.temp_override(window=window, active_object=armature, object=armature, selected_objects=[armature], selected_editable_objects=[armature]):
        view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for name, parent, start, end in bones:
            bone = data.edit_bones.new(name)
            bone.head = start
            bone.tail = end
            bone.use_connect = False
            if parent:
                bone.parent = data.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")

    # One copy of every part, in world space, joined into a single mesh.
    sources = [o for o in bpy.data.collections["TR_Turkey"].all_objects if o.type == "MESH"]
    copies = []
    for source in sources:
        copy = source.copy()
        copy.data = source.data.copy()
        collection.objects.link(copy)
        copy.parent = None
        copy.data.transform(source.matrix_world)
        copy.data.update()
        copy.matrix_world = Matrix.Identity(4)
        copies.append(copy)
    body = next(c for c in copies if c.name.startswith("Turkey_Body"))
    with bpy.context.temp_override(window=window, active_object=body, object=body, selected_objects=copies, selected_editable_objects=copies):
        view_layer.objects.active = body
        bpy.ops.object.join()
    body.name = "Turkey_Mesh"
    body.data.name = "Turkey_Mesh_Data"
    body.parent = armature
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature

    # The separate parts stay in the file as the source, out of the way.
    def find_layer(layer):
        if layer.collection.name == "TR_Turkey":
            return layer
        for child in layer.children:
            found = find_layer(child)
            if found:
                return found
        return None

    layer = find_layer(view_layer.layer_collection)
    if layer:
        layer.exclude = True

    groups = {g.name for g in body.vertex_groups}
    names = {b[0] for b in bones}
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"RIG {len(bones)} bones, mesh {tris} tris, {len(body.data.vertices)} verts, {len(body.data.materials)} material")
    print("bones without verts:", sorted(names - groups))
    print("groups without a bone:", sorted(groups - names))


build()
rig()
