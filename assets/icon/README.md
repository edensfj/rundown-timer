# Icono de la aplicación

Un reloj sobre un cuadrado redondeado índigo, hecho a mano en SVG.

## Archivos

| Archivo | Qué es |
|---|---|
| `rundown-icon.svg` | **La fuente del icono.** Se edita solo este |
| `rundown-icon.png` | Render a 1024×1024 (generado) |
| `rundown-icon.ico` | Multirresolución, lo usa el instalador (generado) |
| `rundown-mark.svg` | **La fuente de la marca de agua.** El icono monocromo |
| `rundown-mark.png` | Render a 1024×1024, con transparencia (generado) |
| `windows/runner/resources/app_icon.ico` | Copia que consume `Runner.rc` en el build de Windows (generada) |

## Regenerar

```bash
bash assets/icon/generar.sh
```

Requiere `rsvg-convert` e ImageMagick. El script renderiza el SVG, construye el
`.ico` con los 7 tamaños que Windows usa de verdad (256/128/64/48/32/24/16) y
copia el resultado a la carpeta del runner. **No hay que tocar nada a mano.**

## Dónde se usa

- **`.exe`**: vía `IDI_APP_ICON` en `windows/runner/Runner.rc`. Es lo que sale en
  la barra de tareas, el explorador y el Alt+Tab.
- **Instalador**: vía `SetupIconFile` en `installer/rundown.iss`.
- **Desinstalador**: vía `UninstallDisplayIcon`, hereda el icono del `.exe`.

## Notas de diseño

Se eligió una esfera blanca sólida con manecillas oscuras, en lugar de un anillo
de progreso o un cronómetro con botones, porque el icono tiene que seguir siendo
reconocible a **16×16 px**, que es el tamaño de la barra de tareas. Los detalles
(un anillo abierto, marcas de minutos) se convierten en ruido a ese tamaño.

El fondo es índigo porque es el color del dashboard.

`rundown-mark.svg` es la **marca de agua del escenario en espera**: el mismo
icono, con la misma geometría, pero monocromo. Sobre el negro del escenario el
índigo no contrasta, así que el cuadrado va a media opacidad y la esfera a
opacidad completa —igual que el original, donde el fondo es oscuro y la esfera
clara— y las manecillas, las marcas y el eje van recortados. Cuando no hay nada en
marcha, el escenario lo pinta al 8-16 % de opacidad, para que un televisor
completamente negro no parezca apagado.
