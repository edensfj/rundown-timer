import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/on_air_provider.dart';
import '../../state/rundown_provider.dart';
import '../../state/schedule_provider.dart';
import '../../state/selected_day_provider.dart';

/// Aviso de que el escenario está proyectando **un día distinto** al que se está
/// viendo en la lista.
///
/// Tiene que existir porque el comportamiento es lo correcto —mirar el guion de
/// mañana no puede parar el directo de hoy— pero a primera vista parece un fallo:
/// se pincha un día y la pantalla no cambia. El aviso lo dice, y da las dos
/// salidas:irse a ese día, o devolver la pantalla al que se está viendo.
class OnAirBanner extends ConsumerWidget {
  const OnAirBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final onAirId = ref.watch(onAirDayIdProvider);
    final activeId = ref.watch(activeDayIdProvider);
    // Sin nada en el aire —o ya se está viendo ese mismo día— no hay nada que
    // avisar.
    if (onAirId == null || onAirId == activeId) return const SizedBox.shrink();

    final nombre =
        ref
            .watch(rundownProvider)
            .value
            ?.where((d) => d.id == onAirId)
            .firstOrNull
            ?.name ??
        'otro día';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_filled,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'En el escenario: $nombre',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(selectedDayProvider.notifier).select(onAirId),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Ir a ese día'),
          ),
          TextButton(
            // Devuelve el escenario al día que se está viendo, sin tocar el
            // programa que sigue corriendo: solo deja de estar anclado.
            onPressed: () =>
                ref.read(onAirDayIdProvider.notifier).releaseDay(onAirId),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Ver este'),
          ),
        ],
      ),
    );
  }
}
