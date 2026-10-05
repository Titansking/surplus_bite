# SurplusBite — Android build artifacts

Release APKs built from `frontend/` at version 1.0.0+1.

| File | Size | ABI | Install on |
| --- | --- | --- | --- |
| `surplusbite-1.0.0-universal.apk` | 58 MB | arm64-v8a, armeabi-v7a, x86_64 | any device; sideload if sideloading is allowed |
| `surplusbite-1.0.0-arm64-v8a.apk` | 22 MB | arm64-v8a | almost every phone from ~2017 on |
| `surplusbite-1.0.0-armeabi-v7a.apk` | 19 MB | armeabi-v7a | older / budget phones |
| `surplusbite-1.0.0-x86_64.apk` | 23 MB | x86_64 | emulators only |

Prefer the per-ABI files: the universal APK carries three copies of the
Flutter engine for a single device's needs.

Package id `com.surplusbite.surplus_bite`, minSdk 24 (Android 7.0),
targetSdk 36.

## Rebuilding

```bash
cd frontend
flutter build apk --release                  # universal
flutter build apk --release --split-per-abi  # per-ABI
```

Output lands in `frontend/build/app/outputs/flutter-apk/`.

## Before shipping to real users

These APKs are signed with the **debug key** (`CN=Android Debug`), so they are
for internal testing only. For Play Store or direct distribution you need a
release keystore:

1. Generate one, outside the repo:
   ```bash
   keytool -genkey -v -ke ~/surplusbite-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias surplusbite
   ```
2. Create `android/key.properties` (gitignored):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=surplusbite
   storeFile=/absolute/path/to/surplusbite-release.jks
   ```
3. Add a `signingConfigs.release` block to `android/app/build.gradle.kts` and
   point `buildTypes.release.signingConfig` at it.

Note the Firebase config in `lib/firebase_options.dart` and
`android/app/google-services.json` is committed to the repo. That is normal
for Firebase client keys (they are not secrets and access is gated by the
security rules), but confirm the Firestore rules in
`backend/firebase/firestore.rules` are deployed to the live project before
publishing — they are what actually protect the data.