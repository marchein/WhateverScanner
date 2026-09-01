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
# exist at project.xcworkspace/xcshareddata/swiftpm/ — and that restriction
# also applies to `xcodebuild -resolvePackageDependencies` run here, so it
# can't be used to generate the file live. Instead, restore the committed
# template (kept in sync with project.yml's `packages:` section; its
# originHash is stable across regenerations as long as those don't change).
SWIFTPM_DIR="WhateverScanner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$SWIFTPM_DIR"
cp ci_scripts/Package.resolved "$SWIFTPM_DIR/Package.resolved"
