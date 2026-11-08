"""Makes one palette image per skin from the base palette in build_turkey.py, plus the shared maps skins can use:
shinier roughness and metalness for metallic skins, and a mask that makes the tail glow for "neon tail" skins.

Each skin only names a few colors; every swatch on the turkey is worked out from them. Anything a skin leaves out
keeps the Classic color. Run it inside Blender; the images go in export/ so they can be uploaded to Roblox.
"""

import colorsys

import bpy

ASSET_DIR = "C:/Users/trevo/Projects/turkey-race/assets/turkey"
OUT = ASSET_DIR + "/export"

# The palette and its layout come from the build script, so they can't drift apart.
source = open(ASSET_DIR + "/build_turkey.py", encoding="utf-8").read()
start = source.index("# name: (sRGB hex, roughness, metalness)")
end = source.index("def swatch_uv")
scope = {}
exec(source[start:end], scope)
PALETTE, SWATCH_NAMES = scope["PALETTE"], scope["SWATCH_NAMES"]
ACROSS, SIZE = scope["SWATCHES_ACROSS"], scope["TEXTURE_SIZE"]

# (r, g, b) in 0-255. Tail: 3 colors run from the middle feather outward; 5 fill the fan's 5 tail swatches in order.
SKINS = {
    "Cool": {"Body": (55, 105, 185), "Head": (150, 200, 240), "Tail": [(35, 70, 150), (60, 160, 215), (170, 235, 255)]},
    "Pilgrim": {"Body": (72, 66, 66), "Head": (225, 190, 150), "Tail": [(95, 65, 45), (150, 100, 60), (205, 165, 110)]},
    "Lava": {"Body": (62, 34, 30), "Head": (120, 45, 30), "Tail": [(255, 60, 20), (255, 130, 20), (255, 210, 60)], "Accent": (255, 110, 20)},
    "Ghost": {
        "Body": (225, 232, 255),
        "Head": (235, 240, 255),
        "Legs": (215, 225, 245),
        "Beak": (190, 200, 225),
        "Wattle": (160, 180, 225),
        "Tail": [(150, 185, 255), (185, 210, 255), (225, 235, 255)],
    },
    "King": {"Body": (95, 45, 140), "Head": (235, 195, 165), "Tail": [(120, 50, 170), (215, 165, 40), (255, 225, 90)], "Accent": (255, 205, 60)},
    "Chef": {"Body": (240, 240, 240), "Head": (255, 215, 190), "Tail": [(255, 255, 255), (225, 230, 235), (200, 210, 220)], "Accent": (220, 50, 45)},
    "Golden": {"Body": (255, 190, 40), "Head": (255, 215, 90), "Legs": (235, 170, 30), "Beak": (255, 140, 20), "Tail": [(230, 150, 20), (255, 200, 40), (255, 240, 140)]},
    "Rainbow": {
        "Body": (250, 250, 255),
        "Head": (255, 225, 240),
        "Tail": [(255, 60, 60), (255, 160, 40), (255, 230, 60), (70, 210, 90), (70, 140, 255)],
        "Accent": (255, 120, 210),
    },
    "Galaxy": {
        "Body": (58, 32, 125),
        "Head": (95, 55, 175),
        "Legs": (120, 80, 220),
        "Beak": (255, 200, 255),
        "Wattle": (255, 90, 200),
        "Tail": [(150, 60, 255), (255, 80, 220), (80, 200, 255), (255, 80, 220), (150, 60, 255)],
        "Accent": (120, 225, 255),
    },
    "Diamond": {
        "Body": (170, 235, 255),
        "Head": (205, 245, 255),
        "Legs": (150, 220, 245),
        "Beak": (120, 200, 255),
        "Wattle": (90, 170, 255),
        "Tail": [(110, 210, 255), (170, 235, 255), (235, 252, 255)],
    },
    "Cranberry": {"Body": (165, 20, 50), "Head": (235, 150, 160), "Tail": [(120, 10, 35), (200, 30, 60), (245, 95, 115)]},
    "Harvest": {"Body": (205, 110, 40), "Head": (235, 190, 130), "Tail": [(200, 45, 30), (240, 140, 30), (250, 210, 60), (240, 140, 30), (200, 45, 30)]},
    "Pie": {"Body": (225, 150, 70), "Head": (245, 205, 145), "Tail": [(205, 125, 55), (235, 170, 90), (250, 225, 175)]},
    "Pumpkin": {"Body": (255, 135, 25), "Head": (255, 170, 60), "Tail": [(75, 135, 40), (110, 170, 50), (160, 205, 75)]},
    "Feast": {"Body": (205, 120, 45), "Head": (235, 175, 115), "Tail": [(230, 150, 20), (255, 200, 40), (255, 240, 140)], "Accent": (255, 205, 60)},
}


# The Classic turkey has natural colors. Before that it had a bright yellow beak and orange feet, which the other
# skins keep unless they set their own.
CARTOON = {"beak": (255, 187, 34), "beak_dark": (242, 146, 15), "foot": (255, 140, 18), "foot_dark": (229, 110, 6)}


def base_rgb(name):
    h = PALETTE[name][0]
    return tuple(int(h[k : k + 2], 16) for k in (0, 2, 4))


def mix(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def shade(c, k):
    return tuple(v * k for v in c)


def tint(c, k):
    return mix(c, (255, 255, 255), k)


def palette_for(skin):
    pal = {name: base_rgb(name) for name in SWATCH_NAMES}

    def put(name, color):
        pal[name] = tuple(max(0, min(255, v)) for v in color)

    tail = skin.get("Tail")
    if tail:
        if len(tail) >= 5:
            first, second, third, fourth, fifth = tail[:5]
        else:
            first, second, third = tail
            fourth, fifth = mix(second, third, 0.5), shade(first, 0.8)
        put("red", first)
        put("orange", second)
        put("marigold", third)
        put("teal", fourth)
        put("plum", fifth)
        put("gold", skin.get("Accent", third))

    if "Body" in skin:
        body = skin["Body"]
        accent = skin.get("Accent", tail[0] if tail else base_rgb("rust"))
        put("back_dark", shade(body, 0.62))
        put("body_dark", shade(body, 0.74))
        put("chestnut", shade(body, 0.7))
        put("dark", shade(body, 0.36))
        put("body_mid", shade(body, 0.88))
        put("body_warm", body)
        put("breast", tint(body, 0.14))
        put("belly", tint(body, 0.4))
        put("cream", tint(body, 0.76))
        put("rust", mix(body, accent, 0.55))

    if "Head" in skin:
        head = skin["Head"]
        put("head", head)
        put("head_light", tint(head, 0.28))
        put("head_shade", shade(head, 0.76))
        put("blush", mix(head, (245, 142, 155), 0.6))
        wattle = skin.get("Wattle", base_rgb("wattle"))
        put("neck", mix(wattle, head, 0.35))
        put("neck_dark", shade(pal["neck"], 0.8))

    if skin:  # every skin but Classic
        for name, color in CARTOON.items():
            put(name, color)
    if "Wattle" in skin:
        put("wattle", skin["Wattle"])
        put("wattle_dark", shade(skin["Wattle"], 0.76))
    if "Beak" in skin:
        put("beak", skin["Beak"])
        put("beak_dark", shade(skin["Beak"], 0.88))
    if "Legs" in skin:
        put("foot", skin["Legs"])
        put("foot_dark", shade(skin["Legs"], 0.86))

    # The dark side of each feather's rib follows whatever its main color became.
    for name, dark, k in (
        ("red", "red_d", 0.8),
        ("orange", "orange_d", 0.84),
        ("marigold", "marigold_d", 0.88),
        ("teal", "teal_d", 0.8),
        ("plum", "plum_d", 0.8),
        ("rust", "rust_d", 0.8),
        ("chestnut", "chestnut_d", 0.8),
        ("cream", "cream_d", 0.92),
        ("gold", "gold_d", 0.88),
        ("body_warm", "body_warm_d", 0.82),
    ):
        put(dark, shade(pal[name], k))
    return pal


def write_image(name, value_of, colorspace="sRGB"):
    """value_of(swatch name or None) -> (r, g, b) in 0..1"""
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    image = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    image.colorspace_settings.name = colorspace
    cell = SIZE // ACROSS
    rows = []
    for y in range(SIZE):
        for x in range(SIZE):
            i = (y // cell) * ACROSS + x // cell
            r, g, b = value_of(SWATCH_NAMES[i] if i < len(SWATCH_NAMES) else None)
            rows += (r, g, b, 1.0)
    image.pixels = rows
    image.filepath_raw = f"{OUT}/{name}.png"
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    print("wrote", name)


for skin_id, skin in [("Classic", {})] + list(SKINS.items()):
    pal = palette_for(skin)
    write_image(f"T_Turkey_Skin_{skin_id}", lambda n: tuple(v / 255 for v in pal[n]) if n else (0.5, 0.5, 0.5))

# Feathers and skin turn glossy and metallic; the eyes, saddle and so on keep their own values.
FEATHERS = {
    "back_dark", "body_dark", "body_mid", "body_warm", "body_warm_d", "breast", "belly", "cream", "cream_d", "rust", "rust_d", "chestnut", "chestnut_d",
    "dark", "gold", "gold_d", "red", "red_d", "orange", "orange_d", "marigold", "marigold_d", "teal", "teal_d", "plum", "plum_d", "head", "head_light", "head_shade",
    "neck", "neck_dark",
}


def shiny_rough(n):
    v = 0.22 if n in FEATHERS else (PALETTE[n][1] if n else 0.5)
    return (v, v, v)


def shiny_metal(n):
    v = 0.8 if n in FEATHERS else (PALETTE[n][2] if n else 0.0)
    return (v, v, v)


write_image("T_Turkey_Roughness_Shiny", shiny_rough, "Non-Color")
write_image("T_Turkey_Metalness_Shiny", shiny_metal, "Non-Color")

# White where the tail fan's main colors are: those swatches glow on "neon tail" skins.
GLOW = {"red", "red_d", "orange", "orange_d", "marigold", "marigold_d", "teal", "teal_d", "plum", "plum_d"}
write_image("T_Turkey_TailGlow", lambda n: (1.0, 1.0, 1.0) if n in GLOW else (0.0, 0.0, 0.0), "Non-Color")
print("done", len(SKINS), "skins")
