#!/bin/sh
set -e

export ZALO_TEMP_DIR="/app/extra"
export ZALO_APP_DIR="/app/extra/app"
export ZALO_PREBUILT_DIR=/app/lib/prebuilt

cp /app/lib/prebuilt/*.tgz "$ZALO_TEMP_DIR/"

export LD_LIBRARY_PATH="/app/lib/zalo${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd /app/lib/zalo

ELECTRON_RUN_AS_NODE=1 /app/lib/zalo/zalo -e '
(async () => {
  await require("/app/lib/scripts/extract").main();
  await require("/app/lib/scripts/apply-patches").main();
  await require("/app/lib/scripts/clean-unused").main();
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
'

rm -f /app/extra/*.dmg /app/extra/*.exe /app/extra/*.tgz /app/extra/*.7z
rm -rf /app/extra/onnxruntime* /app/extra/Zalo*