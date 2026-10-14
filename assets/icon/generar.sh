#!/usr/bin/env bash
#
# Genera el icono de la aplicación a partir del SVG fuente.
#
#   assets/icon/rundown-icon.svg   ← única fuente de verdad (se edita a mano)
#   assets/icon/rundown-icon.png   ← render a 1024, para previsualizar/otros usos
#   assets/icon/rundown-icon.ico   ← multirresolución, lo usa el instalador
#   windows/runner/resources/app_icon.ico  ← copia que consume Runner.rc
#
# Uso:  bash assets/icon/generar.sh
#
# Requiere: rsvg-convert e ImageMagick.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$DIR/../.." && pwd)"

SVG="$DIR/rundown-icon.svg"
PNG="$DIR/rundown-icon.png"
ICO="$DIR/rundown-icon.ico"
ICO_WINDOWS="$RAIZ/windows/runner/resources/app_icon.ico"

# Tamaños que Windows usa de verdad: 16 (barra de tareas), 24/32 (explorador),
# 48 (escritorio), 256 (vista grande). Se incluyen todos para que el sistema no
# tenga que reescalar y el icono se vea nítido en cada contexto.
TAMANOS="256,128,64,48,32,24,16"

echo "→ Renderizando el SVG a 1024 px"
rsvg-convert -w 1024 -h 1024 "$SVG" -o "$PNG"

echo "→ Generando el .ico multirresolución ($TAMANOS)"
magick "$PNG" -define icon:auto-resize="$TAMANOS" "$ICO"

echo "→ Copiando a windows/runner/resources/app_icon.ico"
cp "$ICO" "$ICO_WINDOWS"

echo
magick identify "$ICO" | sed 's/^/  /'
echo
echo "✓ Listo. Recuerda que el .exe solo toma el icono nuevo al recompilar."
