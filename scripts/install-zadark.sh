#!/bin/sh
set -eu

DEST_DIR="${FLATPAK_DEST:-/app/lib/zadark}"
ASSETS_DIR="vendor/zadark/build/pc/assets"
METADATA_DIR="$DEST_DIR/share/metainfo"
ICON_DIR="$DEST_DIR/share/icons/hicolor/scalable/apps"
ICON_PATH="flatpak/net.vietnamlinuxfamily.zalo_for_linux.svg"

if [ ! -d "$ASSETS_DIR" ]; then
    echo "Error: Built assets directory $ASSETS_DIR not found!" >&2
    exit 1
fi

copy_tree() {
    source_dir=$1
    destination_dir=$2
    install -d "$destination_dir"
    tar -C "$source_dir" -cf - . | tar -C "$destination_dir" -xpf -
}

copy_tree "$ASSETS_DIR" "$DEST_DIR"
install -d "$METADATA_DIR"
install -d "$ICON_DIR"
install -p -m0644 "$ICON_PATH" "$ICON_DIR/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.svg"
install -p -m0644 "flatpak/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml" "$METADATA_DIR/net.vietnamlinuxfamily.zalo_for_linux.ZaDark.metainfo.xml"

