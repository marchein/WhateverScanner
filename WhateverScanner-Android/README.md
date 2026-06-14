# WhateverScanner for Android

A modern, native Android document scanner that uploads scans to a WebDAV server
(e.g. **Nextcloud**). This is a Kotlin/Jetpack Compose port of the
[iOS WhateverScanner](https://github.com/marchein/WhateverScanner) app.

> **Note:** This project was generated inside the iOS repository under
> `WhateverScanner-Android/`. To use it as a standalone repository, move the
> contents of this directory into a new `WhateverScanner-Android` repository.

## Features

- 📄 **Native document scanning** via the Google ML Kit Document Scanner
  (auto edge-detection, perspective correction and enhancement).
- 🔎 **On-device OCR** (ML Kit Text Recognition) that suggests a document name
  and detects the document date — German and English vocabulary supported.
- 📤 **WebDAV upload** (HTTP PUT) with Basic authentication, supporting a single
  default server or upload-to-all-servers.
- 🔐 **Secure credential storage** in `EncryptedSharedPreferences` backed by the
  Android Keystore — passwords are never written to DataStore or backups.
- 🎨 **Material You** dynamic theming, edge-to-edge UI and predictive back.
- 🌍 **Localized** in English and German.

## Tech Stack

| Concern | Library |
|---|---|
| UI | Jetpack Compose + Material 3 |
| Navigation | Navigation Compose |
| Settings persistence | Jetpack DataStore (Preferences) |
| Secure storage | AndroidX Security (`EncryptedSharedPreferences`) |
| OCR | ML Kit Text Recognition v2 |
| Scanning | ML Kit Document Scanner (`play-services-mlkit-document-scanner`) |
| Networking | OkHttp |
| DI | Hilt |
| Async | Kotlin Coroutines + Flow |

## Requirements

- Android Studio (Ladybug or newer)
- JDK 17
- Android SDK Platform 36 (Android 16)
- `minSdk` 29, `targetSdk` / `compileSdk` 36

## Project Structure

```
com.marchein.whateverscanner/
├── WhateverScannerApp.kt      // @HiltAndroidApp Application
├── MainActivity.kt            // Single Activity hosting Compose
├── navigation/                // NavHost + routes
├── models/                    // WebDAVServer, AppSettingsData, SettingsRepository
├── services/                  // SecureStorage, OCR, PDF, WebDAV
├── ui/theme/                  // Material 3 theme
├── ui/screens/                // Launch, Onboarding, Main, Preview, Settings, AddServer + ViewModels
├── ui/components/             // DocumentScanner, PDFViewer
├── util/                      // URL/filename helpers
└── di/                        // Hilt module
```

## Building

```bash
./gradlew assembleDebug      # build the debug APK
./gradlew test               # run JVM unit tests
./gradlew lint               # run Android Lint
```

## Architecture

The app uses a single-Activity + Compose Navigation architecture with Hilt for
dependency injection. The `MainViewModel` is scoped to a nested navigation graph
so the in-progress scan (PDF bytes + OCR metadata) is shared between the main
screen and the preview screen. Settings are exposed reactively as a
`StateFlow<AppSettingsData>` from `SettingsRepository`.

Server passwords are stored separately from metadata: only `id`, `name`, `url`
and `username` are serialized to DataStore, while the password lives in
`EncryptedSharedPreferences` keyed by the server id — mirroring the iOS app's
Keychain design.
