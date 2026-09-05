# Play Store release (Android)

## 1) Pick your package name (Application ID)

Current: `com.tenofakind.poker`.

Decide a permanent package name now (you cannot change it later without publishing a new app), e.g.:

- `com.tenofakind.poker.guest`
- `com.yourstudio.tenofakindpoker`

If you want, tell me what you want it to be and I can rename the Android package + Firebase config safely.

## 2) Create a release upload key (keystore)

From the repo root:

```bash
cd android/app
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then create `android/key.properties` (copy from `android/key.properties.example`) and set real values.

## 3) Build the Play Store artifact (AAB)

From the repo root:

```bash
flutter clean
flutter pub get
tools/build_public_release.sh --build-name=1.2.4 --build-number=45
```

Output: `build/releases/toak-public-release.aab`

## Build variants

- Closed testing build with bot-training tools enabled:

```bash
tools/build_closed_testing.sh --build-name=1.2.4 --build-number=45
```

Output: `build/releases/toak-closed-testing.aab`

- Public release build with bot-training tools disabled:

```bash
tools/build_public_release.sh --build-name=1.2.4 --build-number=45
```

Output: `build/releases/toak-public-release.aab`

Runtime targets:

- `lib/main_testing.dart` -> closed testing / bot training enabled
- `lib/main_public.dart` -> public release / bot training disabled
- `lib/main.dart` -> safe default, same as public release

## 4) Firebase/Google Sign-In (if used)

If you use Google Sign-In / Firebase Auth on Android, add your **release** SHA fingerprints:

```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

Then in Firebase Console → Project settings → Your apps (Android) → add SHA-1 and SHA-256.

If you changed the package name, you must also re-download `google-services.json` for the new package.

## 5) Upload to Play Console

1. Create a Play Console account ($25 one-time).
2. Create a new app → set name “X Poker”.
3. Go to **Testing → Internal testing** → create a release → upload the `.aab`.
4. Fix anything flagged in Pre-launch report.
5. Complete required forms: App access, Content rating, Data safety, Target audience, Privacy policy, Store listing.
6. Promote to Production when ready.

## Versioning

Bump `pubspec.yaml` `version: x.y.z+N` for every Play upload (the `+N` must increase).

## Store listing copy

### Recommended public title

`X Poker`

### Testing track title

`X Poker Beta`

Use `Beta` only on closed/internal testing tracks. Do not keep it in the production title.

### Short description

`Battle of Ten Kings - A Trip Through History in Texas Hold'em`

### Long description

`X Poker is a simulated Texas Hold'em experience built around the theme of the Battle of Ten Kings, blending poker strategy with a journey through history. Play as a guest or sign in to save progress as you move across themed kingdoms, sub-venues, and title battles.`

## Developer name shown below the Play Store title

The developer name is Play Console account metadata; it is not read from the Android app bundle. The account owner must open **Developer account → About you**, change **Developer name** to `tenofakind.com`, and save. Google reviews the change before it becomes visible on Google Play.

`The game is designed as a mental exercise and strategy trainer, with readable tournament play, smart AI opponents, and progression that feels competitive without becoming overwhelming for new players.`

`Key features:`

- `Simulated Texas Hold'em gameplay with AI opponents`
- `Battle of Ten Kings theme with historic kingdoms and venue progression`
- `6-player onboarding tables in guest mode and free-entry events`
- `Track your progress, achievements, and aura points`
- `Optional Google sign-in to sync progress`
- `Guest mode available with no account required`

`Important notes:`

- `This app does NOT offer real-money gambling, wagering, or prizes.`
- `Intended for ages 18+.`
- `No ads and no advertising ID usage in this build.`
- `If you have questions or want your account deleted, see the privacy policy and deletion instructions on our website.`

### What's new

For `version 1.2.4 build 45`:

- `Updated app icons, favicons, Apple touch icons, and Play Store icon asset`
- `Added Android edge-to-edge compatibility for Android 15 and later`
- `Made guest tables and free-entry tables 6-player for smoother onboarding`
- `Improved bot all-in decisions to reduce unrealistic multiway pile-ups`
- `Improved winner celebration visuals and general UI polish`
