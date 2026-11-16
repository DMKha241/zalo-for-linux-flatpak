#!/bin/sh
set -eu

echo "Preparing and building ZaDark using upstream submodule and fixes..."

ZADARK_DIR="vendor/zadark"

if [ ! -d "$ZADARK_DIR" ]; then
    echo "Error: Submodule $ZADARK_DIR not found!" >&2
    exit 1
fi

HOME=$PWD node flatpak/yarn.js --cwd "$ZADARK_DIR" config --offline set yarn-offline-mirror "$PWD/flatpak-node/yarn-mirror"

HOME=$PWD node flatpak/yarn.js --cwd "$ZADARK_DIR" --offline --frozen-lockfile --ignore-scripts

echo "Building ZaDark PC assets with gulp..."
(cd "$ZADARK_DIR" && ./node_modules/.bin/gulp build)

export ZADARK_VERSION="${ZADARK_VERSION:-26.3}"
export NODE_PATH="$PWD/$ZADARK_DIR/node_modules"
node scripts/prepare-zadark.js

ASSETS_DIR="$ZADARK_DIR/build/pc/assets"

if [ -f "$ASSETS_DIR/js/zadark-popup-viewer.min.js" ] && [ ! -f "$ASSETS_DIR/js/zadark-popup.min.js" ]; then
    cp -p "$ASSETS_DIR/js/zadark-popup-viewer.min.js" "$ASSETS_DIR/js/zadark-popup.min.js"
fi

echo "ZaDark upstream build complete."
