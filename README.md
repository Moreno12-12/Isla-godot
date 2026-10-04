# Isla Godot

Isla 3D procedural en **Godot 4.7.2** con ciudad, energía renovable, puentes hacia islas menores y clima dinámico.

Repo: https://github.com/Moreno12-12/Isla-godot

## Características

### Terreno e islas
- Malla **341×341** (±170) generada con ruido (FBM + ridged + ruido de costa): montañas, colinas y costa irregular
- Isla principal con pico de **h=28.5**, 3 lagunas y meseta para la ciudad
- **3 islas pequeñas** (radio hasta 50, bordes irregulares con ruido ±18%) separadas por mar de ~27 unidades
- Zonas por altitud: pasto verde, roca en pendientes, nieve en picos, mar azul a −9.2

### Cascada
- Ruta **Dijkstra** global desde la cima hasta el borde del mapa
- Caída con labio saliente, cortina abombada y **poza** con espuma al pie
- **Partículas**: salpicadura blanca y niebla ascendente en cada caída
- **Shader animado**: flujo con oleaje, espuma en caídas, fresnel, destellos y transparencia en bordes

### Estructuras y vegetación
- **Ciudad 3D** sobre la meseta, **fábrica de carbón** y **3 puentes de madera** hacia las islas
- 36 palmeras + 12 en las islas, 22 rocas y vegetación masiva

### Colocación de edificios (HUD → mundo)
- Tarjetas **PANEL SOLAR / MOLINO / TURBINA / BATERÍA**: clic para entrar en modo colocación (marcador verde = válido, rojo = no válido)
- Tarjeta **ELIMINAR (🚫)**: clic sobre un edificio colocado para borrarlo
- Distancia mínima 12 entre edificios, orientación hacia cámara, animaciones del GLB

### Lógica de clima y energía (`scripts/logica.gd`)
- Clima aleatorio **cada 3 minutos** (SOL / NUBLADO / LLUVIOSO, nunca repite el anterior)
- Reglas:

| Clima | Panel solar | Molino eólico | Turbina hidráulica |
|---|---|---|---|
| SOL | ✅ funciona | ❌ | solo si está ≤18u de la cascada |
| NUBLADO | ❌ | ❌ | solo si está ≤18u de la cascada |
| LLUVIOSO | ❌ | ✅ (el viento de la tormenta) | solo si está ≤18u de la cascada |

- **Mundo con clima**: luz solar, color de cielo y densidad de niebla cambian; al llover caen **partículas de lluvia** sobre la isla

### HUD
- Recuadro superior izquierdo: campos de energía (generada, consumo, CO2, almacenamiento)
- Recuadro superior derecho de clima: **"TIEMPO SOLEADO / NUBLADO / LLUVIOSO"** con icono grande y 3 celdas (SOL, NUBES, LLUVIA) que se encienden según el clima
- Recuadro inferior: 5 tarjetas colocables con iconos PNG
- Esquina inferior derecha: estado ambiental y necesidades de la ciudad (pendiente)

### Técnico
- Cámara en órbita con ratón, zoom de 30 a 420
- Colisión `HeightMapShape3D` sobre la rejilla del terreno
- Iconos del HUD generados con **Blender** (`tools/render_iconos.py`)

## Cómo abrirlo

1. Descargar e instalar [Godot 4.7.2](https://godotengine.org/download)
2. Abrir Godot → **Importar** → seleccionar `project.godot`
3. Pulsa **F5** para ejecutar

## Tests

Verificación sin ventana (headless):

```
Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/check_logica.gd
Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/check_timer.gd
```

- `check_logica.gd`: reglas de clima (panel/molino/turbina) y cambio aleatorio
- `check_timer.gd`: comprueba que el clima cambia solo a los 180 s

## Estructura

```
project.godot        # configuración del proyecto
scenes/isla.tscn     # escena principal
scripts/             # terreno, cascada, puentes, ciudad, lógica, HUD, colocación
shaders/             # terreno y cascada
ui/                  # iconos PNG del HUD
models/              # GLB (panel, molino, turbina, batería, ciudad)
tools/               # tests y generación de iconos con Blender
```
