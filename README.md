# X Poker

X Poker is a simulated Texas Hold'em strategy game from **Ten of a Kind**.
It is played on Android and on the web at <https://tenofakind.com/web/>;
the iOS release is in preparation.
There is no real-money gambling, wagering, or prizes.

## Names

| Name | What it is | Where it appears |
| --- | --- | --- |
| **Ten of a Kind** | The umbrella brand: the studio, and the show (ten players at one table) | tenofakind.com, publisher on the stores |
| **X Poker** | The game | Play Store listing (App Store once released), home-screen label, page titles |
| `com.tenofakind.poker` | Permanent store ID (Android and iOS) | Build files only; cannot change after publishing |
| `ten_of_a_kind_poker` | Dart package name | Code only; never shown to players |
| `toak` | Short name for the repo, backend service and build artifacts | Infrastructure only |

All of these, plus the Firebase project, the hosting site and the production
backend address, are defined in [`project.yaml`](project.yaml). Change a value
there first. `tools/verify_identity.sh` runs before every release and fails if
any shipped surface (app names, store IDs, the backend URL compiled into the
app, Firebase targets) disagrees with it.

## Layout

| Path | Contents |
| --- | --- |
| `lib/` | Flutter app (entry points: `main.dart`, `main_public.dart`, `main_testing.dart`) |
| `test/` | Flutter tests |
| `assets/` | Images, sounds, fonts and ML models bundled into the app |
| `backend/` | Express API on Cloud Run (`toak-backend`); see [`backend/readme.md`](backend/readme.md) |
| `hosting/` | The tenofakind.com website; `hosting/web/` is the Flutter web build, generated on deploy |
| `web/` | Flutter web shell (index.html, manifest) used to build `hosting/web/` |
| `tools/` | Release, deploy and verification scripts, plus generators and ML tooling |
| `docs/` | Specs and guides; `docs/archive/` holds superseded reviews |
| `fastlane/metadata/android/` | Google Play listing text, checked by `tools/verify_store_listing.sh` (fastlane layout, so it can be uploaded automatically later) |
| `design_sources/` | Source artwork that is not bundled directly (brand, store, flags) |
| `android/`, `ios/` | Native shells (Android shipped, iOS in preparation) |
| `macos/`, `linux/`, `windows/` | Flutter desktop shells; not shipped |

## Release

Backend first, then the clients. The scripts set release mode and resolve the
backend URL themselves (from `project.yaml`, checked against Cloud Run), so
none of them take an address by hand.

```bash
bash tools/deploy_backend.sh          # Cloud Run: tests, no-traffic candidate, smoke, cutover
bash tools/deploy_web.sh              # tenofakind.com/web/ and Firestore rules
bash tools/build_public_release.sh    # Play Store bundle
bash tools/preview_web_release.sh     # local preview of exactly what deploy_web.sh ships
```

The version and build number live in `pubspec.yaml` (`version: <name>+<build>`).

The production economy and gameplay trust boundary is documented in
[`docs/GAMEPLAY_TRUST_MODEL.md`](docs/GAMEPLAY_TRUST_MODEL.md). AUP and
leaderboard positions are cosmetic and have no monetary, prize, or eligibility
value.

## Requirements

Flutter, Node.js, the Firebase CLI, the Google Cloud CLI (`gcloud`), Java 21
(for the Firestore emulator) and ripgrep (`rg`).
