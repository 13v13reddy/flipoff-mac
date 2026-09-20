#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_ROOT="$PROJECT_ROOT/mac"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_ROOT="${BUILD_ROOT:-$PROJECT_ROOT/build}"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

command -v xcodegen >/dev/null 2>&1 || {
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
}

command -v xcodebuild >/dev/null 2>&1 || {
  echo "error: xcodebuild is required (install Xcode)" >&2
  exit 1
}

echo "Generating macOS Xcode project..."
(cd "$MAC_ROOT" && xcodegen generate)

build_target() {
  local scheme="$1"

  echo "Building $scheme ($CONFIGURATION)..."
  xcodebuild \
    -project "$MAC_ROOT/FlipOffMac.xcodeproj" \
    -scheme "$scheme" \
    -sdk macosx \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
    build
}

# Keep these sequential: both schemes use the same generated project and
# parallel xcodebuild invocations can contend for Xcode's build database.
build_target "FlipOffMac"
build_target "FlipOffScreenSaver"

PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"

echo
echo "Build complete:"
echo "  App/widget: $PRODUCTS_PATH/FlipOffMac.app"
echo "  Screen saver: $PRODUCTS_PATH/FlipOff.saver"
