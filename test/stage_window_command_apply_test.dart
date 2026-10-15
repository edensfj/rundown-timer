
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/window/stage_window.dart';

/// Al perder su pantalla, la ventana del escenario tiene que volver a ser una
/// **ventana normal**: ni maximizada ni a pantalla completa.
///
/// El orden de las llamadas al sistema es lo único que hace que salga bien, y no
/// es un detalle: al salir de una pantalla completa, el sistema devuelve la
/// ventana al estado que tenía antes —normalmente maximizada—, y **una ventana
/// maximizada ignora el tamaño** que se le pida después. Preguntando si estaba
/// maximizada *antes* de salir de la pantalla completa, la respuesta era «no»,
/// se omitía el `unmaximize`, y el reloj se quedaba ocupando la pantalla entera
/// del operador: justo lo que se quería evitar.
///
/// Por eso el canal va simulado: el mock recuerda el estado de la ventana como
/// lo haría el sistema de verdad.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('window_manager');

  late List<MethodCall> llamadas;
  late bool aPantallaCompleta;

  /// Estado «de verdad» de la ventana: lo que tenía antes de ponerse a pantalla
  /// completa y en lo que vuelve cuando se sale. Es lo que hace el sistema, y
  /// es el motivo de toda esta historia: al salir de pantalla completa el
  /// escenario vuelve a estar maximizado.
  late bool maximizadaDeVerdad;

  late Rect? ventana;

  setUp(() {
    llamadas = [];
    aPantallaCompleta = true;
    maximizadaDeVerdad = false;
    ventana = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      llamadas.add(call);
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};

      switch (call.method) {
        case 'isFullScreen':
          return aPantallaCompleta;

        case 'setFullScreen':
          aPantallaCompleta = args['isFullScreen'] as bool? ?? false;
          // Al salir de pantalla completa el sistema devuelve la ventana al
          // estado que tenía antes: maximizada.
          maximizadaDeVerdad = true;
          return null;

        // El sistema **no dice la verdad** sobre la maximización: pregunta y
        // contesta que no, aunque la ventana siga maximizada de verdad. Es lo
        // que se vio en la máquina de trabajo al desenchufar la TV: la ventana
        // volvió a ocupar la pantalla entera del operador, y al preguntarle
        // antes de salir de la pantalla completa respondió que no estaba
        // maximizada, así que el `unmaximize` se saltó y la ventana se quedó
        // ocupando la pantalla. Por eso hay que quitarlo sin preguntar.
        case 'isMaximized':
          return false;

        case 'unmaximize':
          maximizadaDeVerdad = false;
          return null;

        case 'setBounds':
          // Una ventana maximizada se niega a tomar medidas nuevas: es el detalle
          // que hacía que el reloj se quedara ocupando la pantalla entera.
          if (!aPantallaCompleta && maximizadaDeVerdad) return null;
          ventana = Rect.fromLTWH(
            (args['x'] as num?)?.toDouble() ?? ventana?.left ?? 0,
            (args['y'] as num?)?.toDouble() ?? ventana?.top ?? 0,
            (args['width'] as num?)?.toDouble() ?? ventana?.width ?? 0,
            (args['height'] as num?)?.toDouble() ?? ventana?.height ?? 0,
          );
          return null;

        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('al perder su pantalla queda en una ventana normal', () async {
    await applyStageWindowCommand(
      const StageWindowCommand.windowed(Rect.fromLTWH(164, 124, 1600, 900)),
    );

    expect(aPantallaCompleta, isFalse);
    expect(maximizadaDeVerdad, isFalse);
    expect(ventana, const Rect.fromLTWH(164, 124, 1600, 900));
  });

  test('quitar la maximización va antes de darle la medida', () async {
    await applyStageWindowCommand(
      const StageWindowCommand.windowed(Rect.fromLTWH(164, 124, 1600, 900)),
    );

    expect(
      llamadas.where((c) => c.method == 'unmaximize'),
      isNotEmpty,
      reason: 'preguntar si está maximizada no sirve: el sistema contesta que '
          'no cuando sí lo está',
    );
    expect(
      llamadas.indexWhere((c) => c.method == 'unmaximize') <
          llamadas.indexWhere((c) => c.method == 'setBounds'),
      isTrue,
      reason: 'mientras siga maximizada, el tamaño que se le pida se ignora',
    );
  });

  test('primero se mueve y después se mide, como al abrir el escenario',
      () async {
    await applyStageWindowCommand(
      const StageWindowCommand.windowed(Rect.fromLTWH(164, 124, 1600, 900)),
    );

    final ambas = llamadas
        .where((call) => call.method == 'setBounds')
        .map((call) => call.arguments.cast<String, dynamic>())
        .toList();

    expect(ambas, hasLength(2));
    expect(ambas.first, containsPair('x', 164.0));
    expect(ambas.first, containsPair('y', 124.0));
    expect(ambas.last, containsPair('width', 1600.0));
    expect(ambas.last, containsPair('height', 900.0));
  });

  test('no vuelve a pedir pantalla completa si el comando no lo pide', () async {
    await applyStageWindowCommand(
      const StageWindowCommand.windowed(Rect.fromLTWH(0, 0, 800, 600)),
    );

    final pedidos = llamadas
        .where((c) => c.method == 'setFullScreen')
        .map((c) => (c.arguments as Map)['isFullScreen'])
        .toList();

    expect(pedidos, [false], reason: 'solo la de salida, nunca una de entrada');
  });

  test('devolver el escenario a su pantalla sí la pide', () async {
    await applyStageWindowCommand(
      const StageWindowCommand(
        frame: Rect.fromLTWH(1920, 0, 1920, 1080),
        fullscreen: true,
      ),
    );

    final pedidos = llamadas
        .where((c) => c.method == 'setFullScreen')
        .map((c) => (c.arguments as Map)['isFullScreen'])
        .toList();

    expect(pedidos, [false, true],
        reason: 'primero sale de pantalla completa y luego vuelve a ella');
    expect(aPantallaCompleta, isTrue);
  });
}