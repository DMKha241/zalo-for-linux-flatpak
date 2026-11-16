#!/bin/sh
set -eu

DEST_DIR="${FLATPAK_DEST:-/app/lib/zadark}"
ASSETS_DIR="vendor/zadark/build/pc/assets"

echo "Installing ZaDark extension into $DEST_DIR..."

if [ ! -d "$ASSETS_DIR" ]; then
    echo "Error: Built assets directory $ASSETS_DIR not found!" >&2
    exit 1
fi

install -d "$DEST_DIR"
cp -a "$ASSETS_DIR"/* "$DEST_DIR/"

METADATA_DIR="$DEST_DIR/share/metainfo"
install -d "$METADATA_DIR"
if [ -f "flatpak/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml" ]; then
    install -p -m0644 "flatpak/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml" "$METADATA_DIR/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml"
elif [ -f "net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml" ]; then
    install -p -m0644 "net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml" "$METADATA_DIR/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml"
fi

echo "ZaDark extension installation complete."
