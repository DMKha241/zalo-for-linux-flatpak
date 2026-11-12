#!/bin/sh
set -eu

install -d /app/lib/zalo
install -d /app/lib/scripts/patches
install -d /app/lib/scripts/utils

find native -type f -name '*.node' -exec install -Dm0755 {} /app/lib/prebuilt/ \;
find native/addons -type f -name '*.js' -exec install -Dm0755 {} /app/lib/prebuilt/ \;
install -Dm0755 native/engines/zocr/target/release/zocr-host /app/lib/prebuilt/

cp -a scripts/patches/. /app/lib/scripts/patches/
cp -a scripts/utils/. /app/lib/scripts/utils/
cp -a scripts/extract* /app/lib/scripts/
install -Dm0644 scripts/download.js /app/lib/scripts/
install -Dm0644 scripts/apply-patches.js /app/lib/scripts/
install -Dm0644 scripts/clean-unused.js /app/lib/scripts/

case "$(uname -m)" in
    x86_64) ELECTRON_OUTPUT_DIR=linux-unpacked ;;
    aarch64) ELECTRON_OUTPUT_DIR=linux-arm64-unpacked ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

cp -a "dist/$ELECTRON_OUTPUT_DIR/." /app/lib/zalo/
ln -s /app/extra/app /app/lib/zalo/app
install -d /app/lib/node_modules
cp -a node_modules/. /app/lib/node_modules/

install -Dm0755 bin/zalo /app/bin/zalo
install -Dm0755 /usr/lib/sdk/node22/bin/node /app/bin/node
install -Dm0755 flatpak/apply_extra.sh /app/bin/apply_extra

install -Dm0644 flatpak/net.vietnamlinuxfamily.zalo_for_linux.desktop /app/share/applications/net.vietnamlinuxfamily.zalo_for_linux.desktop

ICON_PATH="flatpak/net.vietnamlinuxfamily.zalo_for_linux.png"
install -Dm0644 "$ICON_PATH" /app/share/icons/hicolor/512x512/apps/net.vietnamlinuxfamily.zalo_for_linux.png

install -Dm0644 "flatpak/net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml" "/app/share/metainfo/net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml"
