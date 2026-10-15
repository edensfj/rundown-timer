import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';
import '../../state/clock_provider.dart';
import '../../state/countdown_provider.dart';
import 'countdown_display.dart';
import 'next_activity_banner.dart';

/// Por debajo de este alto, el escenario se pinta en modo compacto: cabecera
/// reducida y sin pie, para que el reloj conserve todo el espacio posible.
///
/// El umbral está por encima del alto de la vista previa del panel —el caso
/// pequeño habitual— y muy por debajo del de cualquier ventana real en un
/// proyector.
const double _compactHeight = 420;

/// Composición visual completa del modo escenario: fondo, destello rojo de
/// alerta, cabecera, countdown y banner de siguiente actividad.
///
/// Se extrajo a un widget propio para poder reutilizarla tal cual en la **vista
/// previa del programador**: así lo que ve el operador en su pantalla es
/// exactamente lo que se está proyectando, sin duplicar el diseño.
///
/// Gestiona internamente el parpadeo rojo, de modo que el destello se comporta
/// igual en la vista completa y en la miniatura.
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

    // En modo reloj no hay cuenta que echar: solo la hora, a lo grande, sin
    // cabecera ni parpadeos. Va antes del estado vacío porque el reloj no
    // necesita actividades.
    if (snapshot.showClock) {
      return _StageClock(use24Hour: snapshot.clockUse24Hour);
    }

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
        SafeArea(
          child: Padding(
            // Márgenes laterales mínimos: el countdown es lo primero y debe
            // llegar prácticamente a los bordes. El inferior reserva el hueco
            // de la barra de controles.
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cuando el hueco es pequeño —la vista previa del panel, o una
                // ventana bajita— la cabecera completa no cabe. Antes se comía
                // todo el alto, el reloj se quedaba con cero y los dos huecos
                // de 16 px desbordaban: eso es la banda amarilla que dibuja
                // Flutter al desbordar. En sitio justo se recorta la cabecera y
                // se retira el pie.
                final apretado = constraints.maxHeight < _compactHeight;

                return Column(
                  children: [
                    _StageHeader(snapshot: snapshot, compact: apretado),
                    const SizedBox(height: 16),
                    Expanded(
                      child: CountdownDisplay(
                        snapshot: snapshot,
                        alertPulse: _alertPulse,
                      ),
                    ),
                    if (!apretado) ...[
                      const SizedBox(height: 16),
                      NextActivityBanner(snapshot: snapshot),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// La hora actual, a lo grande, para el modo reloj del escenario.
///
/// Sin cabecera, sin parpadeos y sin subtítulos: solo dígitos blancos sobre
/// negro, con la misma tipografía condensada de la cuenta atrás. Late al ritmo
/// de [clockProvider], que en la ventana del escenario corre con su propio
/// temporizador —el modo viaja en la instantánea, los segundos no—.
class _StageClock extends ConsumerWidget {
  const _StageClock({required this.use24Hour});

  /// Formato 12 h o 24 h, según lo elegido en el panel.
  final bool use24Hour;

  /// Igual que en [CountdownDisplay]: base enorme y `scaleDown` hasta encajar.
  static const double _baseFontSize = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    final text = use24Hour
        ? TimeFormatters.stageClock(now)
        : TimeFormatters.stageClock12(now);

    return ColoredBox(
      color: StageColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppConfig.countdownFontFamily,
                  fontSize: _baseFontSize,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: StageColors.white,
                  // Los segundos cambian cada tick: sin cifras tabulares el
                  // ancho bailaría y el reloj respiraría.
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera compacta: informa, pero sin robarle sitio al countdown.
///
/// Con [compact] se queda en lo esencial (etiqueta y título) para que quepa en
/// huecos pequeños, como la vista previa del panel.
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.snapshot, this.compact = false});

  final CountdownSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = snapshot.current!;
    final item = slot.item;
    const muted = Color(0x8CFFFFFF);

    return Column(
      children: [
        Text(
          snapshot.isQuickTimer
              ? 'CONTADOR RÁPIDO'
              : snapshot.phase == CountdownPhase.preShow
              ? 'PRÓXIMA ACTIVIDAD'
              : 'ACTIVIDAD ${snapshot.index + 1} DE ${snapshot.total}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0x66FFFFFF),
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: StageColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        // En sitio justo esta línea se cae: es informativa para el operador,
        // y el reloj tiene prioridad absoluta sobre ella.
        if (!compact)
          Wrap(
            spacing: 20,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${TimeFormatters.time(slot.startTime)}  ·  '
                '${TimeFormatters.time(slot.endTime)}  ·  '
                '${TimeFormatters.humanDuration(slot.plannedDuration)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              if (item.responsible != null)
                _InlineMeta(
                  icon: Icons.person_outline_rounded,
                  text: item.responsible!,
                ),
              if (item.location != null)
                _InlineMeta(icon: Icons.place_outlined, text: item.location!),
            ],
          ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0x8CFFFFFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: muted, fontSize: 15)),
      ],
    );
  }
}

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
