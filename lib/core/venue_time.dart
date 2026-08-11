import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

/// Converts a device-provided instant into a venue's civil time.
///
/// IANA rules are used so daylight-saving and historical offset changes come
/// from the bundled time-zone database rather than hand-written calculations.
abstract final class VenueTime {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    time_zone_data.initializeTimeZones();
    _initialized = true;
  }

  static time_zone.TZDateTime at(
    DateTime instant, {
    required String timeZoneId,
  }) {
    initialize();
    final location = time_zone.getLocation(timeZoneId);
    return time_zone.TZDateTime.from(instant.toUtc(), location);
  }
}
