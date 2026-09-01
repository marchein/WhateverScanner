# WhateverScanner

An iOS app for quickly scanning paper documents with the camera and automatically
saving/uploading the result wherever you need it — Photos, the Files app, a WebDAV
server, and/or an SMB share, all at once if you like.

## Features

- **Document scanning** powered by VisionKit's document camera (`VNDocumentCameraScan`),
  with automatic edge detection, perspective correction, and multi-page capture.
- **On-device OCR** (Vision framework) analyzes the first page of every scan to suggest
  a document name and date (e.g. detecting "Rechnung", "Invoice", "Kassenbon", ...),
  which is used to pre-fill the export filename.
- **PDF generation** — scanned pages are combined into a single PDF, each page scaled
  to a consistent A4 width while preserving its original aspect ratio.
- **Multiple save/upload destinations**, any combination of which can be enabled and run
  automatically after every scan:
  - **Photos** — saves each page as an image to the photo library.
  - **Files** — saves the PDF to a folder in the Files app (either a user-picked folder
    via a security-scoped bookmark, or the app's own Documents folder by default).
  - **WebDAV** — uploads the PDF via HTTP `PUT` to one or more configured WebDAV servers.
  - **SMB** — uploads the PDF to one or more configured SMB (Samba) shares, using the
    [AMSMB2](https://github.com/amosavian/AMSMB2) library.
  - A manual "…" menu on the scan preview also lets you Share, Save to Photos, or
    Save to Files on demand, regardless of the auto-save settings.
- **Multiple servers per protocol** — configure several WebDAV/SMB destinations and
  either upload to all of them or just a chosen default.
- **Secure credential storage** — server metadata (name, URL/host, username, ...) is
  persisted in `UserDefaults` as JSON; passwords are stored separately in the iOS
  Keychain and are never written to disk in plain text or included in JSON exports.
- **Localized** in English and German (`Localizable.xcstrings`, a Swift String Catalog).

## Requirements

- macOS with Xcode 16 or newer (the project targets iOS 18.6+).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` —
  install via Homebrew:
  ```sh
  brew install xcodegen
  ```
- An Apple Developer Team ID if you want to run on a physical device (see
  [Configuration](#configuration) below).

## Project Structure

This project's `.xcodeproj` is **generated from [project.yml](project.yml) using
XcodeGen** — `WhateverScanner.xcodeproj/project.pbxproj` is a build artifact and
should never be hand-edited or committed to manually.

```
project.yml                  XcodeGen project specification (targets, settings, sources)
WhateverScanner/
  WhateverScannerApp.swift   App entry point
  ContentView.swift          Root view (launch screen → onboarding or main view)
  Info.plist
  Localizable.xcstrings      String Catalog (en/de)
  Models/                    AppSettings, WebDAVServer, SMBServer
  Services/                  KeychainService, PDFService, OCRService, FilesService,
                             PhotosService, WebDAVService, SMBService
  Views/
    Main/                    Main scanning screen
    Scanning/                Scanner, scan preview, document export, share sheet
    Settings/                Settings screen, add-server forms, folder picker
    Onboarding/LaunchScreen  First-run and launch UI
WhateverScannerTests/        Unit tests (one file per Model/Service)
```

## Setup

1. Clone the repository:
   ```sh
   git clone https://github.com/marchein/WhateverScanner.git
   cd WhateverScanner
   ```
2. Generate the Xcode project:
   ```sh
   xcodegen generate
   ```
3. Open the generated project:
   ```sh
   open WhateverScanner.xcodeproj
   ```
4. Build and run the `WhateverScanner` scheme on a simulator or device.

> **Important:** whenever you add, remove, or rename Swift files, or change
> `project.yml` (targets, build settings, dependencies, ...), re-run
> `xcodegen generate` before building — the `.xcodeproj` is not kept in sync
> automatically, and files won't be picked up otherwise.

`WhateverScanner.xcodeproj/` is a generated build artifact and is **git-ignored**,
not committed — everyone (and every CI system) regenerates it locally from
`project.yml` rather than relying on a potentially stale, committed copy.

## Configuration

- **Signing** — the project uses automatic code signing
  (`CODE_SIGN_STYLE: Automatic`) with a team ID set in [project.yml](project.yml)
  under `settings.DEVELOPMENT_TEAM`. Replace it with your own team ID to build to
  a physical device, or switch Xcode's signing settings after generating the project.
- **Bundle identifier** — set per-target in `project.yml`
  (`PRODUCT_BUNDLE_IDENTIFIER`), currently `de.marc-hein.whateverscanner`.
- **Dependencies** — Swift Package Manager dependencies are declared under the
  top-level `packages:` key in `project.yml` (currently just AMSMB2 for SMB
  support) and referenced per-target under `dependencies:`.

## Xcode Cloud

Since the `.xcodeproj` isn't committed, Xcode Cloud needs to generate it itself
before every build. This is handled by [ci_scripts/ci_post_clone.sh](ci_scripts/ci_post_clone.sh),
an [Xcode Cloud post-clone script](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
that installs XcodeGen via Homebrew and runs `xcodegen generate` against the
freshly cloned repository before Xcode Cloud resolves/builds the project.

## Building from the Command Line

```sh
xcodebuild -project WhateverScanner.xcodeproj -scheme WhateverScanner \
  -destination 'generic/platform=iOS Simulator' -skipMacroValidation build
```

## Running Tests

Unit tests live in `WhateverScannerTests/`, organized one file per Model/Service
(e.g. `PDFServiceTests.swift`, `AppSettingsTests.swift`, `KeychainServiceTests.swift`, ...).
Run them from Xcode (⌘U) or from the command line:

```sh
xcodebuild test -project WhateverScanner.xcodeproj -scheme WhateverScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Network-dependent services (`WebDAVService`, `SMBService`) and system-permission
flows (`PhotosService`) have no injectable transport/mocking layer, so only their
deterministic, network-free code paths (input validation, error descriptions) are
covered by unit tests — not live uploads or permission prompts.

## Localization

User-facing strings live in `WhateverScanner/Localizable.xcstrings`, a Swift
String Catalog supporting English (source language) and German. Edit it directly
in Xcode's String Catalog editor, which keeps translation state (`new`,
`translated`, ...) in sync.

## License

No license has been specified for this project yet.
