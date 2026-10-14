import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_config.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/embedded_stage_screen.dart';
import 'ui/theme.dart';
import 'window/stage_window_controller.dart';

class RundownApp extends StatelessWidget {
  const RundownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _Root(),
    );
  }
}

/// Lo que se ve en la ventana principal: el panel o el escenario.
///
/// Donde el escenario tiene ventana propia (Windows y macOS) aquí siempre está
/// el panel. Donde no la tiene (Linux) el escenario se proyecta en esta misma
/// ventana, así que hay que elegir. Ver [stageSecondWindowProvider].
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(stageWindowProvider).isEmbedded
        ? const EmbeddedStageScreen()
        : const DashboardScreen();
  }
}
