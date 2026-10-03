import bpy
import math

# Limpiar escena
bpy.ops.wm.read_factory_settings(use_empty=True)

FRAME = (0.55, 0.57, 0.60, 1.0)
CELL = (0.04, 0.10, 0.32, 1.0)
GAP = (0.02, 0.02, 0.03, 1.0)
BACK = (0.08, 0.08, 0.09, 1.0)


def mat(name, color, rough=0.4, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m


m_frame = mat("Marco", FRAME, rough=0.35, metal=0.8)
m_cell = mat("Celda", CELL, rough=0.15, metal=0.3)
m_back = mat("Trasera", BACK, rough=0.6, metal=0.2)

# Raíz del panel (para inclinarlo)
bpy.ops.object.empty_add(location=(0, 0, 0))
raiz = bpy.context.object
raiz.name = "PanelRoot"


def box(name, size, loc, material, parent=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.data.materials.append(material)
    if parent:
        o.parent = parent
    return o


# Dimensiones del panel: ancho X=4, fondo Y=2.6, celdas 6x4
ANCHO = 4.0
FONDO = 2.6
GRUESO = 0.08

# Placa trasera
box("Trasera", (ANCHO, FONDO, GRUESO), (0, 0, 0), m_back, raiz)

# Marco (4 barras)
borde = 0.14
box("MarcoArr", (ANCHO + borde * 2, borde, GRUESO + 0.05), (0, FONDO / 2 + borde / 2, 0), m_frame, raiz)
box("MarcoAba", (ANCHO + borde * 2, borde, GRUESO + 0.05), (0, -FONDO / 2 - borde / 2, 0), m_frame, raiz)
box("MarcoIzq", (borde, FONDO, GRUESO + 0.05), (-ANCHO / 2 - borde / 2, 0, 0), m_frame, raiz)
box("MarcoDer", (borde, FONDO, GRUESO + 0.05), (ANCHO / 2 + borde / 2, 0, 0), m_frame, raiz)

# Celdas 6 columnas x 4 filas con separación
COLS, ROWS = 6, 4
hueco = 0.07
cw = (ANCHO - hueco * (COLS + 1)) / COLS
ch = (FONDO - hueco * (ROWS + 1)) / ROWS
for i in range(COLS):
    for j in range(ROWS):
        x = -ANCHO / 2 + hueco + cw / 2 + i * (cw + hueco)
        y = -FONDO / 2 + hueco + ch / 2 + j * (ch + hueco)
        box(f"Celda_{i}_{j}", (cw, ch, 0.03), (x, y, GRUESO / 2 + 0.015), m_cell, raiz)

# Patas de soporte (detrás, inclinadas)
for x in (-1.5, 1.5):
    box(f"Pata_{x}", (0.09, 0.09, 2.0), (x, -FONDO / 2 - 0.3, -1.0), m_frame, raiz, rot=(math.radians(-20), 0, 0))

# Inclinar el panel completo
raiz.rotation_euler = (math.radians(60), 0, math.radians(8))

# Suelo de apoyo (pequeña base)
box("Base", (4.4, 1.6, 0.12), (0, -1.15, -1.85), m_frame, None)

# Cámara ortográfica 3/4 isométrica
bpy.ops.object.camera_add(location=(6.5, -6.5, 5.5))
cam = bpy.context.object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 6.4
# Apuntar al centro del panel
import mathutils
direction = mathutils.Vector((0, 0, 0.4)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam

# Luces
bpy.ops.object.light_add(type='SUN', location=(4, -3, 8))
sun = bpy.context.object
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(35), math.radians(15), math.radians(30))

bpy.ops.object.light_add(type='AREA', location=(-5, 4, 5))
fill = bpy.context.object
fill.data.energy = 250.0
fill.data.size = 6.0
direction = mathutils.Vector((0, 0, 0)) - fill.location
fill.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

# Mundo con luz suave
world = bpy.data.worlds.new("Mundo")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.9, 0.9, 0.95, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7

# Render: Cycles CPU, fondo transparente, 512x512
escena = bpy.context.scene
escena.render.engine = 'CYCLES'
escena.cycles.device = 'CPU'
escena.cycles.samples = 48
escena.render.resolution_x = 512
escena.render.resolution_y = 512
escena.render.film_transparent = True
escena.render.image_settings.file_format = 'PNG'
escena.render.image_settings.color_mode = 'RGBA'
escena.render.filepath = r"C:\Users\stive\Documents\isla-godot\ui\panel_solar.png"

import os
os.makedirs(r"C:\Users\stive\Documents\isla-godot\ui", exist_ok=True)

bpy.ops.render.render(write_still=True)
print("RENDER OK: ui/panel_solar.png")
