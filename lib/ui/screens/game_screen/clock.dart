// lib/ui/screens/game_screen/clock.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// DayDateClock
/// Displays venue time using a region bucket or a fixed offset.
/// Supports DST for Washington (US Eastern) and Cairo (Egypt).
///
/// Example usage:
///   DayDateClock(region: 'america', tzAbbr: 'ET')
///   DayDateClock(region: 'arabia', tzAbbr: 'UAE')
///   DayDateClock(offsetMinutes: 330, tzAbbr: 'IST')
class DayDateClock extends StatefulWidget {
  /// Region keyword: 'america', 'arabia', 'southeast', 'amazon', 'africa',
  /// 'europe', 'russia', 'australia', 'china'
  final String? region;

  /// Fallback UTC offset (in minutes) if region is null or unrecognized
  final int? offsetMinutes;

  /// Optional label (e.g. "ET", "UAE", "SGT")
  final String? tzAbbr;

  /// Visuals
  final EdgeInsets padding;
  final bool pillStyle;
  final Color? backgroundColor;

  const DayDateClock({
    super.key,
    this.region,
    this.offsetMinutes,
    this.tzAbbr,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.pillStyle = true,
    this.backgroundColor,
  });

  @override
  State<DayDateClock> createState() => _DayDateClockState();
}

class _DayDateClockState extends State<DayDateClock> {
  Timer? _timer;
  DateTime _nowUtc = DateTime.now().toUtc();

  static const _wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Returns current UTC offset (in minutes) for a region.
  int _offsetForRegion(String region, DateTime utcNow) {
    final r = region.trim().toLowerCase();

    switch (r) {
      case 'america':
        // Washington DC (US Eastern Time)
        // DST starts 2nd Sunday in March, ends 1st Sunday in November
        final dstStart = _nthWeekdayOfMonth(utcNow.year, 3, DateTime.sunday, 2);
        final dstEnd = _nthWeekdayOfMonth(utcNow.year, 11, DateTime.sunday, 1);
        final inDst = utcNow.isAfter(dstStart) && utcNow.isBefore(dstEnd);
        return inDst ? -240 : -300; // -4h / -5h
      case 'arabia':
        // UAE (Abu Dhabi/Dubai)
        return 240;
      case 'southeast':
        // Singapore
        return 480;
      case 'amazon':
        // Brasília (UTC-3, no DST)
        return -180;
      case 'africa':
        // Cairo with DST (since 2023): UTC+2 → +3 (last Fri Apr to last Thu Oct)
        final lastFriApr = _lastWeekdayOfMonth(utcNow.year, 4, DateTime.friday);
        final lastThuOct = _lastWeekdayOfMonth(utcNow.year, 10, DateTime.thursday);
        final inDst = utcNow.isAfter(lastFriApr) && utcNow.isBefore(lastThuOct);
        return inDst ? 180 : 120;
      case 'europe':
        // Paris (CET: +1 winter, +2 summer)
        final dstStart = _lastSundayOfMonth(utcNow.year, 3);
        final dstEnd = _lastSundayOfMonth(utcNow.year, 10);
        final inDst = utcNow.isAfter(dstStart) && utcNow.isBefore(dstEnd);
        return inDst ? 120 : 60;
      case 'russia':
        // Moscow (UTC+3 year-round)
        return 180;
      case 'australia':
        // Sydney (AEST +10, DST +11: starts 1st Sun Oct, ends 1st Sun Apr)
        final dstStart = _nthWeekdayOfMonth(utcNow.year, 10, DateTime.sunday, 1);
        final dstEnd = _nthWeekdayOfMonth(utcNow.year, 4, DateTime.sunday, 1);
        final inDst = utcNow.isAfter(dstStart) || utcNow.isBefore(dstEnd);
        return inDst ? 660 : 600;
      case 'china':
        // Hong Kong (UTC+8, no DST)
        return 480;
      default:
        // fallback to local system
        return DateTime.now().timeZoneOffset.inMinutes;
    }
  }

  /// Nth weekday of month (1-based)
  DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    final first = DateTime.utc(year, month, 1);
    int offset = (weekday - first.weekday) % 7;
    return first.add(Duration(days: offset + (n - 1) * 7));
  }

  /// Last weekday of month
  DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
    final nextMonth = (month == 12) ? DateTime.utc(year + 1, 1, 1) : DateTime.utc(year, month + 1, 1);
    DateTime last = nextMonth.subtract(const Duration(days: 1));
    while (last.weekday != weekday) {
      last = last.subtract(const Duration(days: 1));
    }
    return last;
  }

  /// Last Sunday of month (used for EU DST)
  DateTime _lastSundayOfMonth(int year, int month) =>
      _lastWeekdayOfMonth(year, month, DateTime.sunday);

  String _fmt(DateTime t, {String? tzAbbr}) {
    final weekday = _wk[(t.weekday - 1) % 7];
    final m = _mon[t.month - 1];
    final d = t.day.toString().padLeft(2, '0');
    final h24 = t.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = (h24 % 12 == 0) ? 12 : (h24 % 12);
    final mm = t.minute.toString().padLeft(2, '0');
    final base = '$weekday • $m $d • $h12:$mm $ampm';
    return (tzAbbr != null && tzAbbr.isNotEmpty) ? '$base ${tzAbbr.toUpperCase()}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final defaultFamily =
        Theme.of(context).textTheme.bodyLarge?.fontFamily ?? 'BarlowCondensed';
    final Color resolvedColor = labelStyle?.color ?? Colors.white;

    final offset = widget.region != null
        ? _offsetForRegion(widget.region!, _nowUtc)
        : (widget.offsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes);

    final venueTime = _nowUtc.add(Duration(minutes: offset));

    final text = Text(
      _fmt(venueTime, tzAbbr: widget.tzAbbr),
      style: (labelStyle ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: resolvedColor,
        fontFamily: defaultFamily,
      ),
      overflow: TextOverflow.ellipsis,
    );

    if (!widget.pillStyle) return text;

    final Color fill = widget.backgroundColor ?? Colors.transparent;

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: text,
    );
  }
}
