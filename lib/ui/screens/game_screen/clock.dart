// lib/ui/screens/game_screen/clock.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/venue_time.dart';

enum DayDateClockDisplayMode {
  full,
  timeOnly,
  dayDateOnly,
}

/// DayDateClock
/// Displays the local civil time for an IANA venue time zone.
///
/// Example usage:
///   DayDateClock(timeZoneId: 'Europe/London')
class DayDateClock extends StatefulWidget {
  /// IANA identifier such as `Asia/Kolkata` or `America/New_York`.
  final String timeZoneId;

  /// Optional label (e.g. "ET", "UAE", "SGT")
  final String? tzAbbr;

  /// Visuals
  final EdgeInsets padding;
  final bool pillStyle;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final DayDateClockDisplayMode displayMode;

  const DayDateClock({
    super.key,
    required this.timeZoneId,
    this.tzAbbr,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.pillStyle = true,
    this.backgroundColor,
    this.textStyle,
    this.displayMode = DayDateClockDisplayMode.full,
  });

  @override
  State<DayDateClock> createState() => _DayDateClockState();
}

class _DayDateClockState extends State<DayDateClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  static const _wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtFull(DateTime t, {String? tzAbbr}) {
    final weekday = _wk[(t.weekday - 1) % 7];
    final m = _mon[t.month - 1];
    final d = t.day.toString().padLeft(2, '0');
    final h24 = t.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = (h24 % 12 == 0) ? 12 : (h24 % 12);
    final mm = t.minute.toString().padLeft(2, '0');
    final base = '$weekday • $m $d • $h12:$mm $ampm';
    return (tzAbbr != null && tzAbbr.isNotEmpty)
        ? '$base ${tzAbbr.toUpperCase()}'
        : base;
  }

  String _fmtTime(DateTime t, {String? tzAbbr}) {
    final h24 = t.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = (h24 % 12 == 0) ? 12 : (h24 % 12);
    final mm = t.minute.toString().padLeft(2, '0');
    final base = '$h12:$mm $ampm';
    return (tzAbbr != null && tzAbbr.isNotEmpty)
        ? '$base ${tzAbbr.toUpperCase()}'
        : base;
  }

  String _fmtDayDate(DateTime t) {
    final weekday = _wk[(t.weekday - 1) % 7];
    final m = _mon[t.month - 1];
    final d = t.day.toString().padLeft(2, '0');
    return '$weekday • $m $d';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final defaultFamily =
        Theme.of(context).textTheme.bodyLarge?.fontFamily ?? 'OpenSans';
    final Color resolvedColor = labelStyle?.color ?? Colors.white;

    final venueTime = VenueTime.at(
      _now,
      timeZoneId: widget.timeZoneId,
    );

    final TextStyle baseStyle = widget.textStyle ??
        (labelStyle ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          color: resolvedColor,
          fontFamily: defaultFamily,
        );
    final String displayText;
    switch (widget.displayMode) {
      case DayDateClockDisplayMode.timeOnly:
        displayText = _fmtTime(venueTime, tzAbbr: widget.tzAbbr);
        break;
      case DayDateClockDisplayMode.dayDateOnly:
        displayText = _fmtDayDate(venueTime);
        break;
      case DayDateClockDisplayMode.full:
        displayText = _fmtFull(venueTime, tzAbbr: widget.tzAbbr);
        break;
    }

    final text = Text(
      displayText,
      style: baseStyle,
      maxLines: 1,
      softWrap: false,
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
