#!/bin/sh
set -eu

ZADARK_DIR="vendor/zadark"

if [ ! -d "$ZADARK_DIR" ]; then
    echo "Error: Submodule $ZADARK_DIR not found!" >&2
    exit 1
fi

export npm_config_yarn_offline_mirror="$PWD/flatpak-node/yarn-mirror"
node flatpak/yarn.js --cwd "$ZADARK_DIR" --offline --frozen-lockfile --ignore-scripts

"$ZADARK_DIR/node_modules/.bin/gulp" build --cwd "$ZADARK_DIR"

export ZADARK_VERSION="${ZADARK_VERSION:-26.3}"
export NODE_PATH="$PWD/$ZADARK_DIR/node_modules"
node scripts/prepare-zadark.js

ASSETS_DIR="$ZADARK_DIR/build/pc/assets"

if [ -f "$ASSETS_DIR/js/zadark-popup-viewer.min.js" ] && [ ! -f "$ASSETS_DIR/js/zadark-popup.min.js" ]; then
    cp -p "$ASSETS_DIR/js/zadark-popup-viewer.min.js" "$ASSETS_DIR/js/zadark-popup.min.js"
fi
