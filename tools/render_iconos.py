import bpy
import math
import os
import sys
import tempfile
import mathutils

OUT_DIR = r"C:\Users\stive\Documents\isla-godot\ui"
RES_ALTA = 512
RES_BAJA = 256
RELLENO = 0.86

MODELOS = [
    {
        "nombre": "molino",
        "glb": r"C:\Users\stive\Documents\isla-godot\models\molino_eolico.glb",
        "out": os.path.join(OUT_DIR, "molino_eolico.png"),
        "rots": [0.0, 45.0, 90.0, 135.0],
    },
    {
        "nombre": "turbina",
        "glb": r"C:\Users\stive\Documents\isla-godot\models\turbina_pelton.glb",
        "out": os.path.join(OUT_DIR, "turbina_hidraulica.png"),
        "rots": [-30.0, 15.0, 60.0],
    },
    {
        "nombre": "bateria",
        "glb": r"C:\Users\stive\Documents\isla-godot\models\bateria.glb",
        "out": os.path.join(OUT_DIR, "bateria.png"),
        "rots": [0.0, 45.0, 90.0, 135.0],
    },
    {
        "nombre": "prohibido",
        "primitivas": True,
        "out": os.path.join(OUT_DIR, "prohibido.png"),
        "rots": [0.0],
    },
]


def construir_prohibido():
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.22,
                                     major_segments=48, minor_segments=16)
    anillo = bpy.context.object
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=2.6, vertices=32)
    barra = bpy.context.object
    dir_barra = mathutils.Vector((math.cos(math.radians(45)),
                                  math.sin(math.radians(45)), 0.0))
    barra.rotation_euler = dir_barra.to_track_quat('Z', 'Y').to_euler()

    mat = bpy.data.materials.new("RojoProhibido")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.82, 0.07, 0.07, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.4
    anillo.data.materials.append(mat)
    barra.data.materials.append(mat)

    bpy.ops.object.empty_add()
    raiz = bpy.context.object
    dir_vista = mathutils.Vector((6.5, -6.5, 5.5)).normalized()
    raiz.rotation_euler = dir_vista.to_track_quat('Z', 'Y').to_euler()
    anillo.parent = raiz
    barra.parent = raiz


def preparar_escena(res, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    escena = bpy.context.scene

    world = bpy.data.worlds.new("Mundo")
    escena.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.9, 0.9, 0.95, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7

    bpy.ops.object.camera_add(location=(6.5, -6.5, 5.5))
    cam = bpy.context.object
    cam.data.type = 'ORTHO'

    bpy.ops.object.light_add(type='SUN', location=(4, -3, 8))
    sun = bpy.context.object
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(35), math.radians(15), math.radians(30))

    bpy.ops.object.light_add(type='AREA', location=(-5, 4, 5))
    fill = bpy.context.object
    fill.data.energy = 250.0
    fill.data.size = 6.0
    fill.rotation_euler = (mathutils.Vector((0, 0, 0)) - fill.location).to_track_quat('-Z', 'Y').to_euler()

    escena.camera = cam
    escena.render.engine = 'CYCLES'
    escena.cycles.device = 'CPU'
    escena.cycles.samples = samples
    escena.render.resolution_x = res
    escena.render.resolution_y = res
    escena.render.film_transparent = True
    escena.render.image_settings.file_format = 'PNG'
    escena.render.image_settings.color_mode = 'RGBA'
    return cam, sun, fill


def objetos_modelo(nombres_ignorar):
    return [o for o in bpy.context.scene.objects if o.name not in nombres_ignorar]


def bbox_mundo(meshes):
    bpy.context.view_layer.update()
    mins = mathutils.Vector((1e9, 1e9, 1e9))
    maxs = mathutils.Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
    return mins, maxs


def rotar_alrededor(raices, centro, rot_z):
    R = mathutils.Matrix.Rotation(math.radians(rot_z), 4, 'Z')
    T = mathutils.Matrix.Translation(centro)
    Ti = mathutils.Matrix.Translation(-centro)
    for o in raices:
        o.matrix_world = T @ R @ Ti @ o.matrix_world
    bpy.context.view_layer.update()


def encuadrar(cam, objetivo, dir_vista, res):
    """Coloca la camara ortografica apuntando a 'objetivo'."""
    cam.location = objetivo + dir_vista * 60.0
    cam.rotation_euler = (objetivo - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 1.0  # se calcula fuera


def medir_alfa(path):
    img = bpy.data.images.load(path)
    px = list(img.pixels)
    w, h = img.size
    minx, miny, maxx, maxy = w, h, -1, -1
    n = 0
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[(row + x) * 4 + 3] > 0.1:
                n += 1
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                ty = h - 1 - y
                if ty < miny:
                    miny = ty
                if ty > maxy:
                    maxy = ty
    bpy.data.images.remove(img)
    if maxx < 0:
        return None
    return (minx, miny, maxx, maxy, n)


def render(escena, path, res, samples):
    escena.render.resolution_x = res
    escena.render.resolution_y = res
    escena.cycles.samples = samples
    escena.render.filepath = path
    bpy.ops.render.render(write_still=True)


def procesar(cfg):
    tmp = os.path.join(tempfile.gettempdir(), "icono_tmp.png")
    dir_vista = mathutils.Vector((6.5, -6.5, 5.5)).normalized()

    # ---- 1) elegir rotacion: la silueta mas ancha (aspas/aspas de cara)
    mejor = None
    for rot in cfg["rots"]:
        cam, sun, fill = preparar_escena(RES_BAJA, 12)
        if cfg.get("primitivas"):
            construir_prohibido()
        else:
            bpy.ops.import_scene.gltf(filepath=cfg["glb"])
        ignorar = {cam.name, sun.name, fill.name}
        meshes = [o for o in objetos_modelo(ignorar) if o.type == 'MESH']
        raices = [o for o in objetos_modelo(ignorar) if o.parent is None]
        mins, maxs = bbox_mundo(meshes)
        centro = (mins + maxs) * 0.5
        rotar_alrededor(raices, centro, rot)
        mins, maxs = bbox_mundo(meshes)
        centro = (mins + maxs) * 0.5
        tam = maxs - mins
        encuadrar(cam, centro, dir_vista, RES_BAJA)
        cam.data.ortho_scale = max(tam.x, tam.y, tam.z) * 1.6
        render(bpy.context.scene, tmp, RES_BAJA, 12)
        caja = medir_alfa(tmp)
        if not caja:
            print("  rot=%s VACIO" % rot)
            continue
        ancho = caja[2] - caja[0]
        alto = caja[3] - caja[1]
        ratio = ancho / max(1, alto)
        print("  rot=%.0f ratio=%.2f ancho=%d alto=%d" % (rot, ratio, ancho, alto))
        if mejor is None or ratio > mejor[0]:
            mejor = (ratio, rot)
    if mejor is None:
        print("ERROR: sin silueta para", cfg["glb"])
        return
    rot = mejor[1]
    print("  -> rot elegida:", rot)

    # ---- 2) escena final con auto-ajuste de camara
    cam, sun, fill = preparar_escena(RES_ALTA, 48)
    if cfg.get("primitivas"):
        construir_prohibido()
    else:
        bpy.ops.import_scene.gltf(filepath=cfg["glb"])
    ignorar = {cam.name, sun.name, fill.name}
    meshes = [o for o in objetos_modelo(ignorar) if o.type == 'MESH']
    raices = [o for o in objetos_modelo(ignorar) if o.parent is None]
    mins, maxs = bbox_mundo(meshes)
    rotar_alrededor(raices, (mins + maxs) * 0.5, rot)
    mins, maxs = bbox_mundo(meshes)
    centro = (mins + maxs) * 0.5
    tam = maxs - mins
    print("  bbox final: centro=", tuple(round(v, 2) for v in centro),
          "tam=", tuple(round(v, 2) for v in tam))

    encuadrar(cam, centro, dir_vista, RES_BAJA)
    cam.data.ortho_scale = max(tam.x, tam.y, tam.z) * 1.6

    for intento in range(5):
        render(bpy.context.scene, tmp, RES_BAJA, 12)
        caja = medir_alfa(tmp)
        if not caja:
            print("ERROR: render vacio")
            return
        minx, miny, maxx, maxy, _ = caja
        ancho = maxx - minx + 1
        alto = maxy - miny + 1
        recortado = (minx <= 1 or miny <= 1 or maxx >= RES_BAJA - 2 or maxy >= RES_BAJA - 2)
        print("  intento %d caja=%s recortado=%s ortho=%.2f" % (intento, caja[:4], recortado, cam.data.ortho_scale))
        # zoom: la silueta larga ocupa RELLENO del cuadro
        mayor = max(ancho, alto)
        cam.data.ortho_scale = cam.data.ortho_scale * (mayor / (RELLENO * RES_BAJA))
        if recortado:
            continue
        # centrar (signo: la camara se desplaza hacia donde esta el contenido)
        cx = (minx + maxx) * 0.5
        cy = (miny + maxy) * 0.5
        por_u = RES_BAJA / cam.data.ortho_scale
        dx = (cx - RES_BAJA * 0.5) / por_u
        dy = (cy - RES_BAJA * 0.5) / por_u
        der = cam.matrix_world.to_quaternion() @ mathutils.Vector((1, 0, 0))
        arr = cam.matrix_world.to_quaternion() @ mathutils.Vector((0, 1, 0))
        # x: contenido a la derecha -> camara a la derecha (+der)
        # y: contenido abajo (cy crece hacia abajo) -> camara hacia abajo (-arr)
        cam.location = cam.location + der * dx - arr * dy
        objetivo = centro + der * dx - arr * dy
        cam.rotation_euler = (objetivo - cam.location).to_track_quat('-Z', 'Y').to_euler()
        if abs(dx) * por_u < 2 and abs(dy) * por_u < 2:
            break

    # ---- 3) render final
    render(bpy.context.scene, cfg["out"], RES_ALTA, 48)
    if os.path.exists(tmp):
        os.remove(tmp)
    caja = medir_alfa(cfg["out"])
    print("RENDER OK:", cfg["out"], "caja_final=", caja[:4] if caja else None)


os.makedirs(OUT_DIR, exist_ok=True)
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
seleccion = [c for c in MODELOS if not args or c["nombre"] in args]
for cfg in seleccion:
    print("MODELO:", cfg["nombre"])
    procesar(cfg)
print("ICONOS TERMINADOS")
