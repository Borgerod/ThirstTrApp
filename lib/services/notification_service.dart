import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/care_task.dart';

/// Action ids exposed on each care reminder.
const kActionDone = 'CARE_DONE';
const kActionPostpone = 'CARE_POSTPONE';
const _channelId = 'care_reminders';

/// Parsed result of a user tapping a notification action.
class NotificationAction {
  NotificationAction(this.taskId, this.actionId);
  final String taskId;
  final String? actionId;
}

/// Wraps flutter_local_notifications (v22 named-parameter API): scheduling
/// care reminders with "Fullført" / "Utsett" actions and surfacing the choice.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// App sets this to react to confirm/postpone choices.
  void Function(NotificationAction action)? onAction;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Darwin categories use non-const factories, so this can't be const.
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _channelId,
          actions: [
            DarwinNotificationAction.plain(kActionDone, 'Fullført'),
            DarwinNotificationAction.plain(kActionPostpone, 'Utsett 1 dag'),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Plantepåminnelser',
      description: 'Vanning, gjødsling og rengjøring',
      importance: Importance.high,
    ));

    _ready = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _onResponse(NotificationResponse r) {
    final taskId = r.payload;
    if (taskId == null) return;
    onAction?.call(NotificationAction(taskId, r.actionId));
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      'Plantepåminnelser',
      channelDescription: 'Vanning, gjødsling og rengjøring',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(kActionDone, 'Fullført',
            showsUserInterface: false),
        AndroidNotificationAction(kActionPostpone, 'Utsett 1 dag',
            showsUserInterface: false),
      ],
    );
    return const NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(categoryIdentifier: _channelId),
    );
  }

  /// Schedule a care reminder at the task's due date (at [hour]).
  Future<void> scheduleTask(CareTask task, String plantName,
      {int hour = 9}) async {
    // Browsers can't schedule future local notifications (needs a push
    // server); the web plugin throws on zonedSchedule. Tasks still appear in
    // the in-app task list — only the OS reminder is skipped.
    if (kIsWeb) return;
    final notifId = task.notificationId;
    if (notifId == null) return;
    final due = task.dueDate;
    var when = tz.TZDateTime.local(due.year, due.month, due.day, hour);
    final nowTz = tz.TZDateTime.now(tz.local);
    if (when.isBefore(nowTz)) {
      when = nowTz.add(const Duration(minutes: 1));
    }

    await _plugin.zonedSchedule(
      id: notifId,
      title: '${task.type.emoji} ${task.type.label}: $plantName',
      body: 'På tide å ${task.type.label.toLowerCase()}. Fullført, eller utsett?',
      scheduledDate: when,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task.id,
    );
  }

  Future<void> cancel(int? notificationId) async {
    if (notificationId != null) await _plugin.cancel(id: notificationId);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Fire an immediate reminder (used for "remind me now" / testing).
  Future<void> showNow(CareTask task, String plantName) => _plugin.show(
        id: task.notificationId ?? task.id.hashCode & 0x7fffffff,
        title: '${task.type.emoji} ${task.type.label}: $plantName',
        body: 'På tide å ${task.type.label.toLowerCase()}.',
        notificationDetails: _details(),
        payload: task.id,
      );
}
