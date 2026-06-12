class Env {
  /// Base URL for your backend API
  static const String apiBaseUrl = 'https://api.tenofakind.com';

  /// Public website (documents/ID card portal).
  /// Use the live Firebase Hosting URL until the custom domain is configured.
  static const String websiteBaseUrl = 'https://ten-of-a-kind-poker.web.app';
  static const String documentsPortalUrl = '$websiteBaseUrl/documents.html';
  static const String privacyPolicyUrl = '$websiteBaseUrl/privacy.html';
  static const String deleteAccountUrl = '$websiteBaseUrl/delete-account.html';

  /// Enable or disable AI players (for testing)
  static const bool enableAI = true;

  /// Enable sound effects (for user toggle or debug)
  static const bool soundEnabled = true;

  /// App version
  static const String appVersion = '1.0.0';

  /// Feature toggles
  static const bool leaderboardEnabled = true;
  static const bool statsTrackingEnabled = true;
  static const bool allowGuestLogin = true;
  static const bool unlockMainEvents = true;

  /// Placeholder UPI/Payment info (for future membership mode)
  static const String paymentProvider = 'razorpay';

  /// Optional developer debug flag
  static const bool debugMode = true;
}
