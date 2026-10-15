import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// «Acerca de»: qué es esto, para qué se hizo y quién lo hizo.
///
/// El diálogo de toda la vida, pero escrito para esta app: no hay una lista de
/// licencias ni un logo de empresa, sino la explicación corta de lo que el
/// operador va a tener delante de la sala.
class AppAboutDialog extends StatefulWidget {
  const AppAboutDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const AppAboutDialog(),
  );

  @override
  State<AppAboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<AppAboutDialog> {
  /// Lo dice el propio paquete instalado, así que no puede desincronizarse del
  /// `pubspec.yaml` como sí se desincroniza una versión escrita a mano.
  String _version = '…';

  @override
  void initState() {
    super.initState();
    _cargarVersion();
  }

  Future<void> _cargarVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      if (!mounted) return;
      setState(() {
        _version = build.isEmpty || build == version
            ? version
            : '$version ($build)';
      });
    } catch (_) {
      // Sin canal de plataforma se queda el número del pubspec: tampoco es
      // información vital.
      if (mounted) setState(() => _version = '1.3.3');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer_outlined,
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rundown Timer', style: theme.textTheme.titleLarge),
                Text(
                  'Versión $_version',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El reloj de un evento en directo. Se programa la escaleta en el '
                'panel y la sala ve, en la pantalla que elijas, el tiempo que '
                'queda de cada actividad.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _Punto(
                icon: Icons.slideshow_rounded,
                texto:
                    'El escenario va en su propia ventana, a pantalla completa '
                    'en la pantalla elegida, y vuelve a su sitio si esa pantalla '
                    'se desconecta.',
              ),
              const _Punto(
                icon: Icons.timer_outlined,
                texto:
                    'El programa no avanza solo: la pantalla se queda en la '
                    'actividad que está en curso aunque se retrase, y quien '
                    'opera decide cuándo se pasa a la siguiente.',
              ),
              const _Punto(
                icon: Icons.flash_on_rounded,
                texto:
                    'Verde al cambiar de actividad, naranja antes de acabar y '
                    'rojo cuando se pasa de tiempo. Todo ajustable.',
              ),
              const _Punto(
                icon: Icons.campaign_rounded,
                texto:
                    'Marquesina para mandar texto a la pantalla sin dejar de '
                    'mirar el reloj.',
              ),
              const _Punto(
                icon: Icons.lock_outline_rounded,
                texto:
                    'Todo se guarda en este equipo: sin cuenta, sin nube y sin '
                    'internet. Se puede exportar e importar en un archivo.',
              ),
              const SizedBox(height: 16),
              Text(
                'Hecha por edensfj, para uso propio y de quien lo use.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'github.com/edensfj/rundown-timer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Una línea de la lista de lo que hace, con su icono delante.
class _Punto extends StatelessWidget {
  const _Punto({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
