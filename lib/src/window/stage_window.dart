import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_config.dart';
import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';
import '../state/countdown_provider.dart';
import '../ui/theme.dart';
import '../ui/widgets/stage_view.dart';
import 'window_placement.dart';

/// La ventana del escenario se abre en **su propio motor de Flutter**, así que
/// no comparte memoria con el panel: lo que se proyecta tiene que viajar como
/// datos. Estas son las instrucciones de arranque.
@immutable
class StageWindowArgs {
  const StageWindowArgs({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fullscreen,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  /// `true` cuando hay una pantalla elegida y el escenario debe ocuparla entera.
  final bool fullscreen;

  Rect get frame => Rect.fromLTWH(x, y, width, height);

  /// El panel abre la ventana con este JSON; el hijo decide con él qué correr.
  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'role': 'stage',
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fullscreen': fullscreen,
      };

  /// `null` cuando los argumentos no son de la ventana del escenario, es decir,
  /// cuando estamos en la ventana principal.
  static StageWindowArgs? tryDecode(String raw) {
    if (raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['role'] != 'stage') return null;

      return StageWindowArgs(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        fullscreen: json['fullscreen'] as bool? ?? false,
      );
    } catch (_) {
      // Argumentos ilegibles: se prefiere arrancar el panel antes que no abrir
      // nada, así que se trata como ventana principal.
      return null;
    }
  }
}

/// Última instantánea recibida del panel.
///
/// En la ventana del escenario sustituye a [countdownProvider], de modo que
/// [StageView] se reutiliza tal cual sin saber que los datos vienen de fuera.
class RemoteSnapshotNotifier extends Notifier<CountdownSnapshot> {
  @override
  CountdownSnapshot build() => const CountdownSnapshot.empty();

  void push(CountdownSnapshot snapshot) => state = snapshot;
}

final remoteSnapshotProvider =
    NotifierProvider<RemoteSnapshotNotifier, CountdownSnapshot>(
  RemoteSnapshotNotifier.new,
);

/// Monta la ventana del escenario y no vuelve hasta que se cierra.
///
/// Se llama desde `main` cuando los argumentos del motor indican que esta
/// ventana es el escenario, no el panel.
Future<void> runStageWindow(
  WindowController controller,
  StageWindowArgs args,
) async {
  final container = ProviderContainer(
    overrides: [
      // Todo lo que pinta el escenario lee de [countdownProvider]; con esta
      // sustitución, lo que llega por el canal se ve exactamente igual que si
      // se hubiera calculado aquí.
      countdownProvider.overrideWith((ref) => ref.watch(remoteSnapshotProvider)),
    ],
  );

  await controller.setWindowMethodHandler((call) async {
    switch (call.method) {
      case 'update':
        final data = (call.arguments as Map).cast<dynamic, dynamic>();
        container
            .read(remoteSnapshotProvider.notifier)
            .push(CountdownSnapshot.fromJson(data));
        return null;

      case 'close':
        await windowManager.destroy();
        return null;

      default:
        throw MissingPluginException('Método no soportado: ${call.method}');
    }
  });

  // La ventana se coloca sola con lo que le mandó el panel: así no hace falta
  // que el otro lado espere a que este motor termine de arrancar.
  await windowManager.ensureInitialized();
  await windowManager.setTitle(AppConfig.stageWindowTitle);
  await placeWindow(args.frame, fullscreen: args.fullscreen);
  await windowManager.show();

  // El escenario puede estar horas proyectándose: la pantalla no se apaga.
  await WakelockPlus.enable();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StageWindowApp(),
    ),
  );
}

/// La app que corre dentro de la ventana del escenario: **solo el reloj**.
///
/// Sin controles y sin notificaciones: esto es lo que ve el público. El
/// operador manda desde el panel, que sigue abierto en la otra ventana.
///
/// Nota sobre Linux: el embedder tiene un fallo conocido al crear una segunda
/// vista —`Failed to setup compositor shaders, unable to make OpenGL context
/// current`— que se lleva por delante el **texto** (los colores planos sí se
/// pintan). Está corregido en Flutter con un contexto OpenGL propio para el
/// hilo de plataforma; hasta que llegue a la versión que usemos, en Linux el
/// escenario se verá negro. En Windows el embedder no comparte ese problema.
class StageWindowApp extends ConsumerWidget {
  const StageWindowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConfig.stageWindowTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ColoredBox(
        color: StageColors.black,
        child: StageView(),
      ),
    );
  }
}
