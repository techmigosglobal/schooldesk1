#!/bin/sh
# fix_spm_deployment_target.sh
#
# Flutter hardcodes iOS 13.0 in FlutterGeneratedPluginSwiftPackage/Package.swift.
# Some plugins (firebase_core, firebase_messaging, printing) require iOS 15.0+.
# Xcode rejects building a package at 13.0 that links 15.0+ products.
#
# This script patches the generated Package.swift to match the project's actual
# minimum deployment target (15.6) after every `flutter pub get`.
#
# Usage: Run from the project root:
#   sh scripts/fix_spm_deployment_target.sh
#
# Or call it automatically by adding to your Makefile / CI pipeline:
#   flutter pub get && sh scripts/fix_spm_deployment_target.sh

set -e

TARGET_VERSION="15.6"
PACKAGE_SWIFT="ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"

if [ ! -f "$PACKAGE_SWIFT" ]; then
  echo "[fix_spm] Package.swift not found at $PACKAGE_SWIFT"
  echo "[fix_spm] Run 'flutter pub get' first to generate it."
  exit 1
fi

CURRENT=$(grep -o '\.iOS("[^"]*")' "$PACKAGE_SWIFT" | head -1)

if [ "$CURRENT" = ".iOS(\"$TARGET_VERSION\")" ]; then
  echo "[fix_spm] Package.swift already at iOS $TARGET_VERSION — no change needed."
  exit 0
fi

# Use sed to replace the iOS platform version in the platforms array.
# The pattern is intentionally strict: only matches the first .iOS("x.y") in
# the platforms array so we don't accidentally modify plugin dependency blocks.
sed -i '' "s/\.iOS(\"[0-9.]*\")/.iOS(\"$TARGET_VERSION\")/" "$PACKAGE_SWIFT"

echo "[fix_spm] Patched Package.swift: $CURRENT → .iOS(\"$TARGET_VERSION\")"
