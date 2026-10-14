/// The reCAPTCHA Enterprise site key the web app uses for Firebase App Check.
///
/// Site keys are public by design (they ship in every page that uses them);
/// what protects them is the list of allowed domains on the key itself.
/// Created 2026-10-15 in Google Cloud (project Ten of a Kind) → Security →
/// Fraud Defense → key "X Poker", for tenofakind.com, www.tenofakind.com,
/// ten-of-a-kind-poker.web.app and ten-of-a-kind-poker.firebaseapp.com.
/// Empty would mean the web app sends no App Check token.
const String recaptchaEnterpriseSiteKey =
    '6Ldo6e4tAAAAAPt_GAipcPVtdOwNUUiwFCnawkVE';
