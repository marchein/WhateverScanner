#!/bin/sh
# Xcode Cloud post-clone hook: regenerate the .xcodeproj from project.yml so
# Xcode Cloud always builds against a fresh, correct project structure instead
# of a possibly-stale committed project.pbxproj.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

# Xcode Cloud's own "Resolve Package Graph" build step runs with automatic
# package resolution disabled and requires a Package.resolved to already
# exist at project.xcworkspace/xcshareddata/swiftpm/. Since the workspace is
# freshly generated above (with no resolved file yet), resolve it here first
# so that later step finds an up-to-date Package.resolved in place.
xcodebuild -resolvePackageDependencies \
  -project WhateverScanner.xcodeproj \
  -scheme WhateverScanner
