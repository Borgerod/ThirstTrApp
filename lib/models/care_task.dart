import '../core/enums.dart';
import '../core/json.dart';

/// A scheduled care action for a plant (water/fertilize/clean/mist).
///
/// The scheduler computes [dueDate] from the plant's interval adjusted by
/// climate + placement. When the user confirms or postpones via a
/// notification, [status] and [dueDate] are updated.
class CareTask {
  CareTask({
    required this.id,
    required this.plantId,
    required this.type,
    required this.dueDate,
    this.status = TaskStatus.due,
    this.completedAt,
    this.postponedDays = 0,
    this.notificationId,
  });

  final String id;
  final String plantId;
  final CareType type;
  DateTime dueDate;
  TaskStatus status;
  DateTime? completedAt;
  int postponedDays;

  /// Stable 31-bit id for flutter_local_notifications.
  int? notificationId;

  bool get isOverdue =>
      status == TaskStatus.due && dueDate.isBefore(DateTime.now());

  bool isDueWithin(Duration window) =>
      status == TaskStatus.due &&
      dueDate.isBefore(DateTime.now().add(window));

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'type': type.id,
        'dueDate': dueDate.toIso8601String(),
        'status': status.id,
        'completedAt': completedAt?.toIso8601String(),
        'postponedDays': postponedDays,
        'notificationId': notificationId,
      };

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        type: CareType.fromId(asString(j['type'])),
        dueDate: asDate(j['dueDate']) ?? DateTime.now(),
        status: TaskStatus.fromId(asString(j['status'])),
        completedAt: asDate(j['completedAt']),
        postponedDays: asInt(j['postponedDays']) ?? 0,
        notificationId: asInt(j['notificationId']),
      );
}
