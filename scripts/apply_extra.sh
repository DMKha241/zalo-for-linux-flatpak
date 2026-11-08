#!/bin/sh
set -e

export ZALO_TEMP_DIR="/app/extra"
export ZALO_APP_DIR="/app/extra/zalo/app"
export ZALO_PREBUILT_DIR=/app/lib/prebuilt

mkdir -p "$ZALO_TEMP_DIR/zalo"

cp /app/lib/prebuilt/*.tgz "$ZALO_TEMP_DIR/"
cp -a /app/lib/zalo/. "$ZALO_TEMP_DIR/zalo/"

cd /app/lib/scripts

export LD_LIBRARY_PATH="/app/extra/zalo${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

ELECTRON_RUN_AS_NODE=1 /app/extra/zalo/zalo -e '
(async () => {
  await require("./extract").main();
  await require("./apply-patches").main();
  await require("./clean-unused").main();
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
'

rm -f /app/extra/*.dmg /app/extra/*.exe /app/extra/*.tgz
