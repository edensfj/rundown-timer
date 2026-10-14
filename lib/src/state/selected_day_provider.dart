import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rundown_repository.dart';

/// Id del día que el usuario está editando. Se persiste para reabrir la app
/// donde la dejó.
class SelectedDayNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(repositoryProvider).loadSelectedDayId();

  void select(String? dayId) {
    if (dayId == state) return;
    state = dayId;
    // La escritura es best-effort: no bloquea la navegación.
    ref.read(repositoryProvider).saveSelectedDayId(dayId);
  }
}

final selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, String?>(SelectedDayNotifier.new);
