#!/bin/sh
set -eu

npm ci --offline

node -e '
(async () => {
  await require("./scripts/prepare-app").main();
  process.env.CC = "i686-unknown-linux-gnu-gcc";
  await require("./scripts/setup-zcall-bridge").main();
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
'


case "$(uname -m)" in
    x86_64)
        ELECTRON_ARCH="x64"
        ;;
    aarch64)
        ELECTRON_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

npx electron-builder --linux dir -c.electronDist=$ELECTRON_CACHE/electron-v22.3.27-linux-${ELECTRON_ARCH}.zip --config.extraMetadata.version=26.10.10
rm -f dist/linux-unpacked/resources/default_app.asar
