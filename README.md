# Isla Godot

Isla 3D en **Godot 4.7.2** con terreno procedural.

## Contenido

- **Terreno**: malla de 161×161 generada con ruido (FBM + ridged) — montañas, colinas y costa
- **Zonas**: islas en pasto verde, mar azul fuera del borde de las islas, roca en pendientes pronunciadas y nieve en los picos
- **Lagunas**: 3 depresiones en el terreno (preparadas para agua)
- **Objetos**: 36 palmeras, 22 rocas y una casa con tejado a dos aguas y panel solar
- **HUD**: tarjetas fijas (Panel Solar, Molino Eólico, Turbina Hidráulica, Batería)
- **Cámara**: órbita con ratón (arrastrar) y zoom con la rueda
- **Colisión**: `HeightMapShape3D` sobre la misma rejilla del terreno

## Cómo abrirlo

1. Descargar e instalar [Godot 4.7.2](https://godotengine.org/download)
2. Abrir Godot → **Importar** → seleccionar `project.godot`
3. Pulsa **F5** para ejecutar

## Estructura

```
project.godot      # configuración del proyecto
scenes/isla.tscn   # escena principal
scripts/           # generador de terreno, objetos, casa, cámara, HUD
shaders/           # shader de color del terreno
```
