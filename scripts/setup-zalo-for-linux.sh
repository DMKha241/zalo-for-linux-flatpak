#!/bin/sh
set -eu

npm ci --offline

node -e '
(async () => {
  await require("./scripts/build-native").main();
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

node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
if (!pkg.build) pkg.build = {};
if (!pkg.build.files) pkg.build.files = [];
if (!pkg.build.files.includes("node_modules/**/*")) {
  pkg.build.files.push("node_modules/**/*");
}
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
'

ZALO_VERSION=$(sed -n 's/.*<release [^>]*version="\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' flatpak/net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml | head -n 1)

npx electron-builder --linux dir \
    -c.electronDist=$ELECTRON_CACHE/electron-v22.3.27-linux-${ELECTRON_ARCH}.zip \
    --config.extraMetadata.version="$ZALO_VERSION"

rm -f "dist/$ELECTRON_OUTPUT_DIR/resources/default_app.asar"
