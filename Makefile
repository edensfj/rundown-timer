# Rundown Timer — instalador sencillo, sin root ni makepkg.
#
#   make install    compila (release) e instala en ~/.local
#   make uninstall  quita lo instalado de ~/.local
#   make build      solo compila el bundle release
#   make package    genera el paquete nativo de pacman (.pkg.tar.zst en dist/)
#   make clean      limpia restos del empaquetado
#
# Ningún objetivo toca tus datos (~/Documentos/rundown/).

PREFIX ?= $(HOME)/.local
APPDIR := $(PREFIX)/lib/rundown-timer
BUNDLE := build/linux/x64/release/bundle
DESKTOP_SRC := packaging/arch/rundown-timer.desktop
METAINFO_SRC := packaging/arch/com.edens.rundown.metainfo.xml
ICON_SRC := assets/icon/rundown-icon.svg
ICON_SIZES := 16 22 24 32 48 64 128 256 512

.PHONY: help build install uninstall package clean

help:
	@echo "Objetivos:"
	@echo "  install    compila e instala en $(PREFIX) (sin root)"
	@echo "  uninstall  desinstala de $(PREFIX)"
	@echo "  build      solo compila el bundle release"
	@echo "  package    genera el .pkg.tar.zst en dist/"
	@echo "  clean      limpia restos del empaquetado"

build:
	flutter build linux --release

install: build
	mkdir -p "$(APPDIR)" "$(PREFIX)/bin" "$(PREFIX)/share/applications" "$(PREFIX)/share/metainfo"
	cp -a "$(BUNDLE)/." "$(APPDIR)/"
	chmod 755 "$(APPDIR)/rundown"
	ln -sf "$(APPDIR)/rundown" "$(PREFIX)/bin/rundown-timer"
	sed 's|^Exec=.*|Exec=$(APPDIR)/rundown|' "$(DESKTOP_SRC)" > "$(PREFIX)/share/applications/com.edens.rundown.desktop"
	cp "$(METAINFO_SRC)" "$(PREFIX)/share/metainfo/"
	for s in $(ICON_SIZES); do \
		d="$(PREFIX)/share/icons/hicolor/$${s}x$${s}/apps"; \
		mkdir -p "$$d"; \
		rsvg-convert -w "$$s" -h "$$s" "$(ICON_SRC)" -o "$$d/rundown-timer.png"; \
	done
	mkdir -p "$(PREFIX)/share/icons/hicolor/scalable/apps"
	cp "$(ICON_SRC)" "$(PREFIX)/share/icons/hicolor/scalable/apps/rundown-timer.svg"
	-update-desktop-database "$(PREFIX)/share/applications"
	@echo "Instalado. Búscalo como «Rundown Timer» en el menú."

uninstall:
	@echo "Cerrando Rundown Timer si está en ejecución..."
	pkill -x rundown-timer 2>/dev/null || true
	pkill -x rundown 2>/dev/null || true
	rm -rf "$(APPDIR)"
	rm -f "$(PREFIX)/bin/rundown-timer"
	rm -f "$(PREFIX)/share/applications/com.edens.rundown.desktop"
	rm -f "$(PREFIX)/share/metainfo/com.edens.rundown.metainfo.xml"
	for s in $(ICON_SIZES); do \
		rm -f "$(PREFIX)/share/icons/hicolor/$${s}x$${s}/apps/rundown-timer.png"; \
	done
	rm -f "$(PREFIX)/share/icons/hicolor/scalable/apps/rundown-timer.svg"
	-update-desktop-database "$(PREFIX)/share/applications"
	@echo "Desinstalado (los datos de ~/Documentos/rundown/ se conservan)."

package:
	bash packaging/arch/build.sh

clean:
	rm -rf packaging/arch/pkgroot packaging/arch/pkg packaging/arch/src packaging/arch/PKGBUILD
