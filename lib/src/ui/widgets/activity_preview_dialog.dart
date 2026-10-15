import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/countdown_snapshot.dart';
import '../../state/countdown_provider.dart';
import 'stage_view.dart';

/// Muestra cómo se vería una actividad en el escenario, en un diálogo.
///
/// Pinta el [StageView] de verdad con la instantánea recibida, así que lo que
/// se ve aquí es exactamente lo que saldría proyectado. No toca el estado de
/// la ejecución: lo que está al aire sigue intacto al cerrar.
Future<void> showActivityPreview(
  BuildContext context,
  CountdownSnapshot snapshot,
) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: ProviderScope(
                  overrides: [
                    countdownProvider.overrideWith((ref) => snapshot),
                  ],
                  child: const StageView(),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  tooltip: 'Cerrar vista previa',
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
