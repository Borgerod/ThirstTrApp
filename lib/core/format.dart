import 'package:intl/intl.dart';

/// Norwegian-friendly date + relative-time formatting.
class Fmt {
  static final _date = DateFormat('d. MMM', 'nb_NO');
  static final _dateFull = DateFormat('d. MMMM y', 'nb_NO');

  static String date(DateTime? d) => d == null ? '–' : _date.format(d);
  static String dateFull(DateTime? d) => d == null ? '–' : _dateFull.format(d);

  /// "i dag", "i morgen", "om 3 dager", "3 dager forsinket".
  static String relativeDue(DateTime due) {
    final now = DateTime.now();
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'i dag';
    if (days == 1) return 'i morgen';
    if (days == -1) return '1 dag forsinket';
    if (days < 0) return '${-days} dager forsinket';
    return 'om $days dager';
  }

  static String age(Duration? d) {
    if (d == null) return '–';
    final days = d.inDays;
    if (days < 31) return '$days dager';
    if (days < 365) return '${(days / 30).round()} mnd';
    final years = days ~/ 365;
    final months = ((days % 365) / 30).round();
    return months == 0 ? '$years år' : '$years år $months mnd';
  }
}
