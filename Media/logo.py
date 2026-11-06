# QuestTargetHelper logo: flat 2D shapes, Workbench render, orthographic camera.
# blender -b -P logo.py -- <out.png> <size>
import bpy, sys, math

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
SIZE = int(argv[1]) if len(argv) > 1 else 400

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # object colours are linear in Workbench
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)

z_next = [0.0]
def layer():
    z_next[0] += 0.01
    return z_next[0]

def rect(name, x, y, w, h, color, radius=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, layer()))
    o = bpy.context.object
    o.name = name
    o.scale = (w, h, 1)
    bpy.ops.object.transform_apply(scale=True)
    if radius > 0:
        m = o.modifiers.new("round", "BEVEL")
        m.affect = "VERTICES"
        m.width = radius
        m.segments = 12
    o.color = color
    return o

def circle(name, x, y, r, color, sx=1.0, sy=1.0):
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=r, fill_type="NGON", location=(x, y, layer()))
    o = bpy.context.object
    o.name = name
    o.scale = (sx, sy, 1)
    o.color = color
    return o

def tri(name, pts, color):
    mesh = bpy.data.meshes.new(name)
    z = layer()
    mesh.from_pydata([(px, py, z) for px, py in pts], [], [(0, 1, 2)])
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    o.color = color
    return o

BG = hexc("#17131f")
BAR_BG = hexc("#0b0910")
BONE = hexc("#efe9dc")
RED = hexc("#c8352b")
ZONE_OVER_RED = hexc("#a2307a")   # purple zone over the red health fill
ZONE = hexc("#6f35a0")            # purple zone over empty bar
EDGE = hexc("#ffffff")

# Background tile
rect("bg", 0, 0, 2.0, 2.0, BG, radius=0.28)

def quad(name, pts, color):
    mesh = bpy.data.meshes.new(name)
    z = layer()
    mesh.from_pydata([(px, py, z) for px, py in pts], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    o.color = color
    return o

GOLD = hexc("#ffd21f")
GOLD_HI = hexc("#fff08a")
OUTLINE = hexc("#3a2606")

# Quest "!" (own drawing in the spirit of a quest marker, not Blizzard's art):
# a bar that tapers toward the bottom, and a dot, gold with a dark outline.
QX, QY = 0, 0.27            # centre of the mark
TOP_W, BOT_W = 0.30, 0.17   # bar width at its top and bottom
BAR_TOP, BAR_BOT = QY + 0.47, QY - 0.10
DOT_Y, DOT_R = QY - 0.33, 0.115
O = 0.045                   # outline thickness

def bang(prefix, grow, color):
    tw, bw = TOP_W / 2 + grow, BOT_W / 2 + grow
    quad(prefix + "bar", [(QX - bw, BAR_BOT - grow), (QX + bw, BAR_BOT - grow),
                          (QX + tw, BAR_TOP + grow), (QX - tw, BAR_TOP + grow)], color)
    circle(prefix + "cap", QX, BAR_TOP + grow * 0.2, tw, color, sy=0.35)    # rounded top
    circle(prefix + "foot", QX, BAR_BOT - grow * 0.2, bw, color, sy=0.6)    # rounded bottom
    circle(prefix + "dot", QX, DOT_Y, DOT_R + grow, color)

bang("outline_", O, OUTLINE)
bang("fill_", 0.0, GOLD)
# A soft highlight down the left of the bar.
quad("shine", [(QX - BOT_W / 2 + 0.02, BAR_BOT + 0.06), (QX - BOT_W / 2 + 0.07, BAR_BOT + 0.06),
               (QX - TOP_W / 2 + 0.10, BAR_TOP - 0.03), (QX - TOP_W / 2 + 0.04, BAR_TOP - 0.03)], GOLD_HI)

# Health bar with the kill zone: health ends inside the zone = lethal.
BX, BY, BW, BH = 0, -0.55, 1.56, 0.34
LEFT = BX - BW / 2
HEALTH, KILL = 0.52, 0.74  # fractions of the bar
# Like in game: the purple zone sticks out above and below the bar, and the
# red health sits inside it, ending before the zone's white edge = it dies.
PADZ = 0.07
rect("barframe", BX, BY, BW + 0.08, BH + 0.08, BAR_BG, radius=0.07)
rect("zone", LEFT + BW * KILL / 2, BY, BW * KILL, BH + 2 * PADZ, ZONE, radius=0.03)
rect("health", LEFT + BW * HEALTH / 2 + 0.02, BY, BW * HEALTH - 0.04, BH - 0.08, RED)
rect("edge", LEFT + BW * KILL, BY, 0.05, BH + 2 * PADZ + 0.04, EDGE)

# Camera, render
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.0
cam = bpy.data.objects.new("cam", cam_data)
cam.location = (0, 0, 10)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "OBJECT"
scene.display.render_aa = "32"
scene.view_settings.view_transform = "Standard"
scene.render.film_transparent = True  # rounded corners stay transparent
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
