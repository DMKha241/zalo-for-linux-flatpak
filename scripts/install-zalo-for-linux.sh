#!/bin/sh
set -eu

copy_tree() {
    source_dir=$1
    destination_dir=$2
    install -d "$destination_dir"
    tar -C "$source_dir" -cf - . | tar -C "$destination_dir" -xpf -
}

install -d /app/lib/zalo
install -d /app/lib/scripts/patches
install -d /app/lib/scripts/utils
install -d /app/lib/prebuilt

install -d /app/share/applications
install -d /app/share/icons/hicolor/512x512/apps
install -d /app/share/metainfo

find native -type f -name '*.node' -print0 |
    xargs -0 -r install -p -m0755 -t /app/lib/prebuilt --
find native/addons -type f -name '*.js' -print0 |
    xargs -0 -r install -p -m0644 -t /app/lib/prebuilt --
install -p -m0755 native/engines/zocr/target/release/zocr-host /app/lib/prebuilt/

install -p -m0644 -t /app/lib/scripts/patches -- scripts/patches/*
install -p -m0644 -t /app/lib/scripts/utils -- scripts/utils/*
install -p -m0644 scripts/extract* /app/lib/scripts/
install -p -m0644 scripts/download.js /app/lib/scripts/
install -p -m0644 scripts/apply-patches.js /app/lib/scripts/
install -p -m0644 scripts/clean-unused.js /app/lib/scripts/

case "$(uname -m)" in
    x86_64) ELECTRON_OUTPUT_DIR=linux-unpacked ;;
    aarch64) ELECTRON_OUTPUT_DIR=linux-arm64-unpacked ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

copy_tree "dist/$ELECTRON_OUTPUT_DIR" /app/lib/zalo
ln -s /app/extra/app /app/lib/zalo/app
copy_tree node_modules /app/lib/node_modules

install -p -m0755 bin/zalo /app/bin/zalo
install -p -m0755 /usr/lib/sdk/node22/bin/node /app/bin/node
install -p -m0755 flatpak/apply_extra.sh /app/bin/apply_extra

install -p -m0644 flatpak/net.vietnamlinuxfamily.zalo_for_linux.desktop /app/share/applications/net.vietnamlinuxfamily.zalo_for_linux.desktop

ICON_PATH="flatpak/net.vietnamlinuxfamily.zalo_for_linux.png"
install -p -m0644 "$ICON_PATH" /app/share/icons/hicolor/512x512/apps/net.vietnamlinuxfamily.zalo_for_linux.png

install -p -m0644 flatpak/net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml /app/share/metainfo/net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml
