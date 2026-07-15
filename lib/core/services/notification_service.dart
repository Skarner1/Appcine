import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/content_item.dart';

/// Acciones rápidas disponibles en la notificación.
class NotificationActions {
  NotificationActions._();

  static const String watchNow = 'ver_ahora';
  static const String snooze = 'posponer_1h';
  static const String dismiss = 'descartar';
}

/// Servicio de notificaciones locales de CineLog Pro.
///
/// Canal Android: `recordatorios_visionado` (alta prioridad).
/// Acciones rápidas: [Ver ahora] [Posponer 1h] [Descartar].
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Invocado cuando el usuario toca la notificación o una acción.
  /// Recibe el id del contenido y el id de la acción (null si tocó el cuerpo).
  void Function(String contentId, String? actionId)? onNotificationTap;

  static const String _channelId = 'recordatorios_visionado';
  static const String _channelName = 'Recordatorios de visionado';
  static const String _channelDescription =
      'Recordatorios de películas y series programadas, estrenos y sugerencias.';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Si la plataforma no expone la zona horaria, se mantiene la default.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Abrir'),
      windows: WindowsInitializationSettings(
        appName: 'CineLog Pro',
        appUserModelId: 'com.example.cineapp',
        guid: 'a9c43c33-9c9b-4a5c-b8e2-1f4f3c2d7a01',
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleResponse,
    );

    _initialized = true;
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    onNotificationTap?.call(payload, response.actionId);
  }

  /// Pide permisos de notificación (Android 13+/iOS/macOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {
      // Plataforma sin soporte de permisos: se ignora.
    }
    return true;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(''),
        actions: [
          AndroidNotificationAction(
            NotificationActions.watchNow,
            'Ver ahora',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            NotificationActions.snooze,
            'Posponer 1h',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            NotificationActions.dismiss,
            'Descartar',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
  }

  /// Id estable de notificación derivado del UUID del contenido (FNV-1a, 31 bits).
  static int notificationId(String contentId) {
    var hash = 0x811C9DC5;
    for (final unit in contentId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Programa (o reprograma) el recordatorio de visionado de [item].
  /// Devuelve false si la fecha ya pasó o el contenido no tiene notificación.
  Future<bool> scheduleWatchReminder(ContentItem item) async {
    if (!_initialized) return false;
    final date = item.notificationDate;
    if (!item.notifyMe || date == null) return false;
    if (date.isBefore(DateTime.now())) return false;

    final scheduled = tz.TZDateTime.from(date, tz.local);
    final id = notificationId(item.id);

    var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null &&
          (await android.canScheduleExactNotifications() ?? false)) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}

    // Un libro no se ve ni pide palomitas.
    final reading = item.type.isRead;
    final flourish = reading ? '' : ' ¡Prepara las palomitas!';

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: reading
            ? '📖 Hoy toca leer: ${item.title}'
            : '🎬 Hoy toca ver: ${item.title}',
        body: item.type.hasEpisodes && item.currentEpisode != null
            ? 'Continúa desde el ${item.type.unitLabel} ${(item.currentEpisode ?? 0) + 1}.$flourish'
            : 'Lo programaste para este momento.$flourish',
        scheduledDate: scheduled,
        notificationDetails: _details(),
        androidScheduleMode: scheduleMode,
        payload: item.id,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Id fijo del aviso de "lo dejaste a medias". Se deriva de una cadena que no
  /// es un UUID, así que nunca choca con el recordatorio propio de una ficha.
  static int get stalledReminderId => notificationId('__stalled_digest__');

  /// Programa el aviso de títulos a medias para [when], con [message] ya
  /// redactado. Al tocarlo se abre la ficha del más abandonado ([contentId]).
  ///
  /// Es un aviso único aunque haya varios títulos parados: una notificación por
  /// cada uno sería una encerrona, no un recordatorio.
  Future<bool> scheduleStalledReminder({
    required String message,
    required String contentId,
    required DateTime when,
  }) async {
    if (!_initialized) return false;
    if (!when.isAfter(DateTime.now())) return false;

    try {
      await _plugin.zonedSchedule(
        id: stalledReminderId,
        title: '🍿 Lo dejaste a medias',
        body: message,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: contentId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelStalledReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: stalledReminderId);
    } catch (_) {}
  }

  Future<void> cancelForContent(String contentId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: notificationId(contentId));
    } catch (_) {}
  }

  /// Muestra una notificación inmediata (para probar el canal desde ajustes).
  Future<void> showTestNotification() async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: 0,
        title: '🍿 CineLog Pro',
        body: 'Las notificaciones funcionan. ¡A disfrutar del cine!',
        notificationDetails: _details(),
      );
    } catch (_) {}
  }

  /// Respuesta de la notificación que lanzó la app (cold start), si la hubo.
  Future<NotificationResponse?> launchResponse() async {
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details!.notificationResponse;
      }
    } catch (_) {}
    return null;
  }

  Future<List<PendingNotificationRequest>> pending() async {
    if (!_initialized) return const [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }
}
