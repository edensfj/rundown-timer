#!/usr/bin/env bash
# Genera el paquete nativo de Arch (.pkg.tar.zst) con icono y lanzador.
#
# Uso:
#   flutter build linux --release   # una vez (o cada vez que cambie el código)
#   bash packaging/arch/build.sh      # monta pkgroot/ y corre makepkg
#   sudo pacman -U dist/rundown-timer-*.pkg.tar.zst
#
# Requiere: base-devel (makepkg), rsvg-convert.
# El .pkg.tar.zst resultante queda en dist/ (misma carpeta que el setup de Windows).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKGDIR="$ROOT/packaging/arch"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
STAGE="$PKGDIR/pkgroot"
DIST="$ROOT/dist"

if [ ! -x "$BUNDLE/rundown" ]; then
  echo "No hay bundle release. Ejecuta primero: flutter build linux --release" >&2
  exit 1
fi

VER="$(grep '^version:' "$ROOT/pubspec.yaml" | sed -E 's/^version: ([^+]+)\+.*/\1/')"
echo "Versión: $VER"

# 1. Bundle de Flutter tal cual sale del build, bajo /opt.
rm -rf "$STAGE"
mkdir -p "$STAGE/opt/rundown-timer"
cp -a "$BUNDLE/." "$STAGE/opt/rundown-timer/"
chmod 755 "$STAGE/opt/rundown-timer/rundown"

# 2. Iconos hicolor desde el SVG fuente (el reloj, no el logo de Flutter).
for s in 16 22 24 32 48 64 128 256 512; do
  d="$STAGE/usr/share/icons/hicolor/${s}x${s}/apps"
  mkdir -p "$d"
  rsvg-convert -w "$s" -h "$s" "$ROOT/assets/icon/rundown-icon.svg" -o "$d/rundown-timer.png"
done
mkdir -p "$STAGE/usr/share/icons/hicolor/scalable/apps"
cp "$ROOT/assets/icon/rundown-icon.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/rundown-timer.svg"

# 3. Lanzador del menú y ficha AppStream (para Discover).
mkdir -p "$STAGE/usr/share/applications" "$STAGE/usr/share/metainfo"
cp "$PKGDIR/rundown-timer.desktop" "$STAGE/usr/share/applications/com.edens.rundown.desktop"
cp "$PKGDIR/com.edens.rundown.metainfo.xml" "$STAGE/usr/share/metainfo/"

# 4. PKGBUILD con la versión de pubspec.yaml y construcción del paquete.
sed "s/@PKGVER@/$VER/" "$PKGDIR/PKGBUILD.in" > "$PKGDIR/PKGBUILD"
mkdir -p "$DIST"
(cd "$PKGDIR" && PKGDEST="$DIST" makepkg -f)
rm -rf "$PKGDIR/pkg" "$PKGDIR/src"

echo "Listo: $(ls "$DIST"/rundown-timer-*.pkg.tar.zst)"
