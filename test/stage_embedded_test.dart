import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/state/countdown_provider.dart';
import 'package:rundown/src/state/displays_provider.dart';
import 'package:rundown/src/window/stage_window_controller.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// El escenario tiene dos modos: su propia ventana (Windows y macOS) o la
/// ventana del panel (Linux, porque allí el embedder no aguanta una segunda
/// vista de Flutter). Aquí se prueba el segundo, que es el que no puede
/// comprobarse a ojo en un Windows, y el camino de error del primero.
void main() {
  // Los canales de plataforma de las ventanas (el de eventos, sobre todo) no
  // existen en una prueba, así que hay que tener el binding listo para que el
  // fallo sea el esperado y no un desastre de arranque.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer montar({required bool segundaVentana}) {
    final container = ProviderContainer(
      overrides: [
        stageSecondWindowProvider.overrideWithValue(segundaVentana),
        // Sin Hive ni reloj corriendo: lo que se prueba es dónde se proyecta.
        countdownProvider.overrideWith((ref) => const CountdownSnapshot.empty()),
        displaysProvider.overrideWith((ref) async => const <Display>[]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('donde no hay segunda ventana, el escenario se proyecta en el panel',
      () async {
    final container = montar(segundaVentana: false);
    final notifier = container.read(stageWindowProvider.notifier);

    expect(container.read(stageWindowProvider).isOpen, isFalse);

    await notifier.open();

    final abierto = container.read(stageWindowProvider);
    expect(abierto.isOpen, isTrue, reason: 'el reloj tiene que verse');
    expect(abierto.isEmbedded, isTrue,
        reason: 'sin ventana propia, se proyecta en la del panel');
    expect(abierto.hasError, isFalse,
        reason: 'no crear ventana no puede contar como fallo');

    await notifier.close();

    final cerrado = container.read(stageWindowProvider);
    expect(cerrado.isOpen, isFalse);
    expect(cerrado.isEmbedded, isFalse,
        reason: 'cerrado no puede quedar como si siguiera dentro del panel');
  });

  test('abrir y volver a abrir en el panel no se queda a medias', () async {
    final container = montar(segundaVentana: false);
    final notifier = container.read(stageWindowProvider.notifier);

    await notifier.open();
    await notifier.open(); // sin cerrar: no debe cambiar nada

    expect(container.read(stageWindowProvider).isOpen, isTrue);

    await notifier.close();
    await notifier.open();

    final abierto = container.read(stageWindowProvider);
    expect(abierto.isOpen, isTrue);
    expect(abierto.isEmbedded, isTrue);
    expect(abierto.hasError, isFalse);
  });

  test('si la ventana propia no se puede crear, se dice y no se finge abierto',
      () async {
    // En la máquina de pruebas no hay canal de ventanas, así que crear una
    // falla: es justo el caso en el que el operador tiene que enterarse.
    final container = montar(segundaVentana: true);

    await container.read(stageWindowProvider.notifier).open();

    final estado = container.read(stageWindowProvider);
    expect(estado.isOpen, isFalse);
    expect(estado.hasError, isTrue,
        reason: 'un fallo al abrir tiene que llegar a la pantalla');
  });

  test('cerrar sin haber abierto no revienta', () async {
    final container = montar(segundaVentana: false);

    await container.read(stageWindowProvider.notifier).close();
    await container.read(stageWindowProvider.notifier).toggle();

    expect(container.read(stageWindowProvider).isOpen, isTrue);
  });
}
