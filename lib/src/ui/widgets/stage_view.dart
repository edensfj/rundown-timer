import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../models/countdown_phase.dart';
import '../../state/countdown_provider.dart';
import 'countdown_display.dart';

/// Composición del modo escenario: **solo el reloj**.
///
/// Sin cabecera, sin barra de progreso y sin pie. En una proyección lo único
/// que importa son los dígitos, y todo lo demás competía con ellos: la barra
/// además cambiaba de color según la fase y se leía como una raya suelta.
///
/// Lo que sí se mantiene es el **destello rojo a pantalla completa** cuando el
/// tiempo se agota: es la única señal que hay que entender de un vistazo desde
/// el público.
///
/// Se extrajo a un widget propio para poder reutilizarlo tal cual en la **vista
/// previa del programador**: así lo que ve el operador en su pantalla es
/// exactamente lo que se está proyectando, sin duplicar el diseño.
class StageView extends ConsumerStatefulWidget {
  const StageView({super.key});

  @override
  ConsumerState<StageView> createState() => _StageViewState();
}

class _StageViewState extends ConsumerState<StageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _alertController;

  /// 0.0 = fondo negro, 1.0 = fondo rojo.
  late final Animation<double> _alertPulse;

  /// Margen mínimo para que los dígitos no toquen el borde de la pantalla.
  static const EdgeInsets _margins = EdgeInsets.all(16);

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      vsync: this,
      duration: AppConfig.blinkPeriod,
    );
    _alertPulse = _alertController.drive(Tween<double>(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _alertController.dispose();
    super.dispose();
  }

  /// Sincroniza el parpadeo con la fase. Es idempotente, así que puede
  /// ejecutarse en cada `build` sin efectos duplicados.
  void _syncAlert(CountdownPhase phase) {
    if (phase.isAlert && !_alertController.isAnimating) {
      _alertController.value = 1.0;
      _alertController.repeat(reverse: true);
    } else if (!phase.isAlert && _alertController.isAnimating) {
      _alertController.stop();
      _alertController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(countdownProvider);
    _syncAlert(snapshot.phase);

    if (!snapshot.hasActivities) return const _NoActivities();

    return Stack(
      children: [
        // Fondo negro + destello rojo a pantalla completa.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _alertPulse,
            builder: (context, _) => ColoredBox(
              color: Color.lerp(
                StageColors.black,
                StageColors.alert,
                _alertPulse.value,
              )!,
            ),
          ),
        ),
        // El reloj se lleva TODO el espacio: no hay nada más que mostrar.
        Positioned.fill(
          child: Padding(
            padding: _margins,
            child: CountdownDisplay(snapshot: snapshot, alertPulse: _alertPulse),
          ),
        ),
      ],
    );
  }
}

/// Sin actividades no hay reloj: se avisa en el mismo negro de siempre.
class _NoActivities extends StatelessWidget {
  const _NoActivities();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: StageColors.black,
      child: Center(
        child: Text(
          'Este día no tiene actividades',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
