#!/bin/sh
set -eu

npm ci --offline

node -e '
(async () => {
  await require("./scripts/prepare-app").main();
  await require("./scripts/clean-unused").main();
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
'

case "$(uname -m)" in
    x86_64)
        ELECTRON_ARCH="x64"
        ELECTRON_OUTPUT_DIR="linux-unpacked"
        ;;
    aarch64)
        ELECTRON_ARCH="arm64"
        ELECTRON_OUTPUT_DIR="linux-arm64-unpacked"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

ZALO_VERSION=$(node -p "JSON.parse(require('fs').readFileSync('app/package.json.bak', 'utf8')).version")

npx electron-builder --linux dir \
    -c.electronDist=$ELECTRON_CACHE/electron-v22.3.27-linux-${ELECTRON_ARCH}.zip \
    --config.extraMetadata.version="$ZALO_VERSION"
rm -f "dist/$ELECTRON_OUTPUT_DIR/resources/default_app.asar"
