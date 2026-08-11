/// App tier / entitlement flags.
///
/// Use `--dart-define=APP_TIER=premium` for premium builds.
class AppTier {
  static const String name =
      String.fromEnvironment('APP_TIER', defaultValue: 'free');

  static const bool isPremiumBuild = name == 'premium';
}
