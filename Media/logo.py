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

# Skull (own drawing, not Blizzard's icon)
SX, SY = 0, 0.30
circle("head", SX, SY + 0.12, 0.44, BONE, sx=1.0, sy=0.95)
rect("jaw", SX, SY - 0.28, 0.50, 0.30, BONE, radius=0.08)
circle("eyeL", SX - 0.17, SY + 0.10, 0.125, BG, sy=1.1)
circle("eyeR", SX + 0.17, SY + 0.10, 0.125, BG, sy=1.1)
tri("nose", [(SX - 0.06, SY - 0.10), (SX + 0.06, SY - 0.10), (SX, SY + 0.01)], BG)
for i, dx in enumerate((-0.12, 0.0, 0.12)):
    rect("tooth%d" % i, SX + dx, SY - 0.33, 0.035, 0.16, BG)

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
