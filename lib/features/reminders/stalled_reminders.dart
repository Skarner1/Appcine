import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';

/// Un título que empezaste y llevas tiempo sin tocar.
class StalledItem {
  final ContentItem item;

  /// Última señal de vida: el último visionado del diario, o la fecha en que lo
  /// añadiste si nunca llegaste a ver nada.
  final DateTime lastActivity;

  final int daysStalled;

  const StalledItem({
    required this.item,
    required this.lastActivity,
    required this.daysStalled,
  });
}

/// Última vez que se tocó [item]: el diario manda; si no hay diario se cae a
/// `watchDate` (pasada) y, en último caso, a cuándo se añadió.
DateTime lastActivityOf(ContentItem item, {DateTime? now}) {
  final today = now ?? DateTime.now();

  if (item.watchLog.isNotEmpty) {
    final past = item.watchLog
        .where((e) => !e.date.isAfter(today))
        .map((e) => e.date)
        .toList();
    if (past.isNotEmpty) {
      past.sort();
      return past.last;
    }
  }

  final watched = item.watchDate;
  if (watched != null && !watched.isAfter(today)) return watched;

  return item.addedAt;
}

/// Lo que dejaste a medias hace más de [after], del más abandonado al menos.
///
/// Solo mira lo que está *viéndose*: "Pausada" y "Abandonada" son decisiones
/// tuyas y dar la lata con ellas sería impertinente. Tampoco entra lo que tiene
/// un recordatorio propio puesto: ya te va a avisar.
List<StalledItem> findStalled(
  List<ContentItem> items, {
  required Duration after,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final stalled = <StalledItem>[];

  for (final item in items) {
    if (item.status != WatchStatus.watching) continue;
    if (item.notifyMe && item.notificationDate != null) continue;

    final last = lastActivityOf(item, now: today);
    final idle = today.difference(last);
    if (idle < after) continue;

    stalled.add(StalledItem(
      item: item,
      lastActivity: last,
      daysStalled: idle.inDays,
    ));
  }

  stalled.sort((a, b) => b.daysStalled.compareTo(a.daysStalled));
  return stalled;
}

/// "3 semanas", "2 meses"... en el idioma en que hablaría una persona.
String humanizeStalled(int days) {
  if (days >= 365) {
    final years = days ~/ 365;
    return years == 1 ? 'un año' : '$years años';
  }
  if (days >= 60) return '${days ~/ 30} meses';
  if (days >= 30) return 'un mes';
  if (days >= 14) return '${days ~/ 7} semanas';
  if (days >= 7) return 'una semana';
  return '$days días';
}

/// Cuerpo del aviso: se centra en el más abandonado y solo menciona el resto de
/// pasada. Una notificación con seis títulos no la lee nadie.
String stalledMessage(List<StalledItem> stalled) {
  final first = stalled.first;
  final tiempo = humanizeStalled(first.daysStalled);
  final rest = stalled.length - 1;

  final base = 'Llevas $tiempo sin ver "${first.item.title}"';
  if (rest == 0) return '$base. ¿Lo retomas?';
  if (rest == 1) return '$base, y tienes otro título a medias.';
  return '$base, y tienes $rest títulos más a medias.';
}

final stalledItemsProvider = Provider<List<StalledItem>>((ref) {
  final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
  final days = ref.watch(stalledReminderDaysProvider);
  return findStalled(items, after: Duration(days: days));
});

/// A qué hora avisar: la siguiente [hour] que esté al menos a 12 h vista.
///
/// El colchón evita el aviso a bocajarro nada más abrir la app, que quedaría
/// como un regaño: si acabas de estar aquí, ya lo has visto en la pantalla.
DateTime nextReminderSlot(DateTime now, {int hour = 20}) {
  var slot = DateTime(now.year, now.month, now.day, hour);
  while (slot.difference(now) < const Duration(hours: 12)) {
    slot = slot.add(const Duration(days: 1));
  }
  return slot;
}

/// Recalcula el aviso de títulos a medias: lo programa, o lo quita si ya no hay
/// nada parado o el usuario lo apagó. Se llama al arrancar y al tocar el ajuste.
Future<void> syncStalledReminder(WidgetRef ref, {DateTime? now}) async {
  final service = NotificationService.instance;

  if (!ref.read(stalledReminderEnabledProvider)) {
    await service.cancelStalledReminder();
    return;
  }

  final items = ref.read(contentRepositoryProvider).getAll();
  final days = ref.read(stalledReminderDaysProvider);
  final stalled = findStalled(items, after: Duration(days: days), now: now);

  if (stalled.isEmpty) {
    await service.cancelStalledReminder();
    return;
  }

  await service.scheduleStalledReminder(
    message: stalledMessage(stalled),
    contentId: stalled.first.item.id,
    when: nextReminderSlot(now ?? DateTime.now()),
  );
}
