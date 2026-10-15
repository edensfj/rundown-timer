import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/state/displays_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Portátil a la izquierda y proyector a la derecha, el caso de dos pantallas.
const portatil = Display(
  id: 'MONITOR\\INT3480\\0001',
  name: r'\\.\DISPLAY1',
  size: Size(1920, 1080),
  visiblePosition: Offset.zero,
  visibleSize: Size(1920, 1040),
);

const proyector = Display(
  id: 'MONITOR\\PROJ123\\0002',
  name: r'\\.\DISPLAY2',
  size: Size(1920, 1080),
  visiblePosition: Offset(1920, 0),
  visibleSize: Size(1920, 1080),
);

/// El panel está centrado en la pantalla del portátil.
const panelEnPortatil = Rect.fromLTWH(300, 100, 1300, 900);

/// Las mismas dos pantallas como las ve Linux: sin identificador, solo con el
/// nombre del conector y dónde están.
const portatilLinux = Display(
  id: '',
  name: 'eDP-1',
  size: Size(1920, 1034),
  visiblePosition: Offset.zero,
  visibleSize: Size(1920, 1034),
);

const tvLinux = Display(
  id: '',
  name: 'HDMI-1',
  size: Size(1920, 1080),
  visiblePosition: Offset(1920, 0),
  visibleSize: Size(1920, 1080),
);

void main() {
  group('chooseStageDisplay: con dos pantallas', () {
    test('sin elegir ninguna, proyecta en la OTRA pantalla', () {
      final elegida = chooseStageDisplay(
        displays: const [portatil, proyector],
        selectedKey: null,
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.id, proyector.id,
          reason: 'el panel está en el portátil: el escenario va al proyector');
    });

    test('funciona aunque el orden de la lista venga al revés', () {
      final elegida = chooseStageDisplay(
        displays: const [proyector, portatil],
        selectedKey: null,
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.id, proyector.id);
    });

    test('si el panel está en el proyector, el escenario va al portátil', () {
      final elegida = chooseStageDisplay(
        displays: const [portatil, proyector],
        selectedKey: null,
        panelBounds: const Rect.fromLTWH(2000, 100, 1300, 900),
      );

      expect(elegida?.id, portatil.id);
    });

    test('una elección a mano manda sobre la automática', () {
      final elegida = chooseStageDisplay(
        displays: const [portatil, proyector],
        selectedKey: portatil.id,
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.id, portatil.id,
          reason: 'aunque sea la del panel, si el operador la eligió se respeta');
    });

    test('si la elegida ya no está conectada, se cae a la otra', () {
      final elegida = chooseStageDisplay(
        displays: const [portatil, proyector],
        selectedKey: 'MONITOR\\VIEJO\\0009',
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.id, proyector.id);
    });
  });

  group('chooseStageDisplay: una sola pantalla', () {
    test('devuelve null para que el escenario se abra en ventana', () {
      expect(
        chooseStageDisplay(
          displays: const [portatil],
          selectedKey: null,
          panelBounds: panelEnPortatil,
        ),
        isNull,
      );
    });

    test('ni siquiera con una pantalla elegida se fuerza el fullscreen', () {
      // Con un solo monitor, proyectar sería quedarse sin poder programar; el
      // escenario en ventana es justo lo que se quiere.
      expect(
        chooseStageDisplay(
          displays: const [portatil],
          selectedKey: portatil.id,
          panelBounds: panelEnPortatil,
        ),
        isNull,
      );
    });

    test('sin pantallas detectadas no se rompe', () {
      expect(
        chooseStageDisplay(
          displays: const [],
          selectedKey: null,
          panelBounds: panelEnPortatil,
        ),
        isNull,
      );
    });
  });

  group('chooseStageDisplay: casos raros', () {
    test('sin saber dónde está el panel, se evita la principal', () {
      final elegida = chooseStageDisplay(
        displays: const [portatil, proyector],
        selectedKey: null,
        panelBounds: null,
      );

      expect(elegida?.id, proyector.id);
    });

    test('si el panel no cae en ninguna pantalla, no se queda sin elegir', () {
      const otra = Display(
        id: 'b',
        size: Size(800, 600),
        visiblePosition: Offset(800, 0),
        visibleSize: Size(800, 600),
      );

      // Una posición de panel imposible: fuera de todas las pantallas.
      final elegida = chooseStageDisplay(
        displays: const [proyector, otra],
        selectedKey: null,
        panelBounds: const Rect.fromLTWH(-5000, -5000, 100, 100),
      );

      expect(elegida, isNotNull,
          reason: 'con dos pantallas siempre hay que elegir una');
      expect(elegida?.id, proyector.id);
    });
  });

  group('pantallas sin identificador (Linux)', () {
    test('la clave distingue una pantalla de otra por posición y tamaño', () {
      expect(displayKeyOf(portatilLinux), isNot(displayKeyOf(tvLinux)),
          reason: 'sin id, la posición es lo único que las separa');
    });

    test('la clave es estable entre lecturas de la misma pantalla', () {
      expect(displayKeyOf(portatilLinux), displayKeyOf(portatilLinux));
    });

    test('cuando hay id, la clave es el id', () {
      // En Windows sigue mandando el identificador del sistema.
      expect(displayKeyOf(portatil), portatil.id);
      expect(displayKeyOf(proyector), proyector.id);
    });

    test('la pantalla elegida se respeta aunque no haya id', () {
      // Lo que fallaba: con el id vacío, toda elección se descartaba y el
      // escenario no iba a la pantalla elegida.
      final elegida = chooseStageDisplay(
        displays: const [portatilLinux, tvLinux],
        selectedKey: displayKeyOf(tvLinux),
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.name, tvLinux.name);
    });

    test('y al revés: elegir el portátil manda sobre la automática', () {
      final elegida = chooseStageDisplay(
        displays: const [portatilLinux, tvLinux],
        selectedKey: displayKeyOf(portatilLinux),
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.name, portatilLinux.name);
    });

    test('sin elegir nada, sigue yendo a la otra pantalla', () {
      final elegida = chooseStageDisplay(
        displays: const [portatilLinux, tvLinux],
        selectedKey: null,
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.name, tvLinux.name);
    });

    test('una clave de una pantalla desconectada no rompe nada', () {
      final elegida = chooseStageDisplay(
        displays: const [portatilLinux, tvLinux],
        selectedKey: '@0,0 1280x720',
        panelBounds: panelEnPortatil,
      );

      expect(elegida?.name, tvLinux.name);
    });
  });
}
