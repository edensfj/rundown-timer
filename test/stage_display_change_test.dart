import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/state/displays_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// La TV conectada a la derecha y el portátil a la izquierda.
const portatil = Display(
  id: '',
  name: 'eDP-1',
  size: Size(1920, 1034),
  visiblePosition: Offset.zero,
  visibleSize: Size(1920, 1034),
);

const tv = Display(
  id: '',
  name: 'HDMI-1',
  size: Size(1920, 1080),
  visiblePosition: Offset(1920, 0),
  visibleSize: Size(1920, 1080),
);

/// La clave con la que se identifica la TV en Linux: sin id, por dónde está.
final claveTv = displayKeyOf(tv);

/// Si la pantalla del escenario desaparece con el escenario ya abierto, su
/// ventana tiene que dejar de ser una pantalla completa: el sistema, al no tener
/// dónde proyectar, la deja a pantalla completa sobre la del operador y el reloj
/// tapa el panel entero.
///
/// Está aparte porque reproducirtelo a mano —desenchufar la TV en mitad de una
/// prueba— no se puede en un equipo de un solo monitor.
void main() {
  group('stageScreenChangeFor: se desconecta la pantalla del escenario', () {
    test('la ventana del escenario vuelve a ser normal', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil],
        stageDisplayKey: claveTv,
        wasFullScreen: true,
        degradedByUs: false,
      );

      expect(cambio, StageScreenChange.toWindow);
    });

    test('si ya estaba en ventana, no se toca', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil],
        stageDisplayKey: claveTv,
        wasFullScreen: false,
        degradedByUs: false,
      );

      expect(cambio, StageScreenChange.none,
          reason: 'no hay nada que bajar: ya era una ventana');
    });
  });

  group('stageScreenChangeFor: la pantalla del escenario sigue ahí', () {
    test('no se toca nada', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil, tv],
        stageDisplayKey: claveTv,
        wasFullScreen: true,
        degradedByUs: false,
      );

      expect(cambio, StageScreenChange.none);
    });

    test('vuelve a pantalla completa si la había bajado la app', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil, tv],
        stageDisplayKey: claveTv,
        wasFullScreen: false,
        degradedByUs: true,
      );

      expect(cambio, StageScreenChange.toScreen,
          reason: 'si la TV vuelve, el reloj vuelve a ella sin reabrir nada');
    });

    test('pero no si el operador la abrió en ventana a propósito', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil, tv],
        stageDisplayKey: claveTv,
        wasFullScreen: false,
        degradedByUs: false,
      );

      expect(cambio, StageScreenChange.none,
          reason: 'esa ventana en ventana la pidió el operador');
    });
  });

  group('stageScreenChangeFor: escenario sin pantalla propia', () {
    test('no hay ninguna pantalla que pueda desaparecer', () {
      final cambio = stageScreenChangeFor(
        displays: const [portatil],
        stageDisplayKey: null,
        wasFullScreen: false,
        degradedByUs: false,
      );

      expect(cambio, StageScreenChange.none);
    });
  });

  group('displayByKey', () {
    test('encuentra la pantalla por su clave', () {
      expect(displayByKey(const [portatil, tv], claveTv)?.name, 'HDMI-1');
    });

    test('devuelve null si ya no está conectada', () {
      expect(displayByKey(const [portatil], claveTv), isNull);
    });

    test('una clave vacía nunca encuentra nada', () {
      expect(displayByKey(const [portatil, tv], ''), isNull);
    });
  });
}