#!/bin/sh
# Xcode Cloud post-clone hook: regenerate the .xcodeproj from project.yml so
# Xcode Cloud always builds against a fresh, correct project structure instead
# of a possibly-stale committed project.pbxproj.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
