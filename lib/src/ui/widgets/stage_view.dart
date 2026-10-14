import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';
import '../../state/countdown_provider.dart';
import 'countdown_display.dart';
import 'next_activity_banner.dart';

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
        // Barra de progreso del día, bajo el destello para no competir con él.
        Positioned.fill(child: _DayProgressBar(snapshot: snapshot)),
        SafeArea(
          child: Padding(
            // Márgenes laterales mínimos: el countdown es lo primero y debe
            // llegar prácticamente a los bordes. El inferior reserva el hueco
            // de la barra de controles.
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
            child: Column(
              children: [
                _StageHeader(snapshot: snapshot),
                const SizedBox(height: 16),
                Expanded(
                  child: CountdownDisplay(
                    snapshot: snapshot,
                    alertPulse: _alertPulse,
                  ),
                ),
                const SizedBox(height: 16),
                NextActivityBanner(snapshot: snapshot),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cabecera compacta: informa, pero sin robarle sitio al countdown.
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.snapshot});

  final CountdownSnapshot snapshot;

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

/// Barra de progreso de la actividad actual sobre el ancho de la ventana.
class _DayProgressBar extends StatelessWidget {
  const _DayProgressBar({required this.snapshot});

  final CountdownSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final slot = snapshot.current!;
    final total = slot.plannedDuration.inMilliseconds;
    final remaining = snapshot.remaining.inMilliseconds;
    final elapsed = (total - remaining).clamp(0, total);
    final value = total <= 0 ? 1.0 : elapsed / total;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(snapshot.phase.accent),
          ),
        ),
      ),
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
