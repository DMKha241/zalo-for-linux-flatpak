#!/bin/sh
set -eu

install -d /app/lib/zalo
case "$(uname -m)" in
    x86_64) ELECTRON_OUTPUT_DIR=linux-unpacked ;;
    aarch64) ELECTRON_OUTPUT_DIR=linux-arm64-unpacked ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
cp -a "dist/$ELECTRON_OUTPUT_DIR/." /app/lib/zalo/

install -Dm0755 /dev/stdin /app/bin/zalo <<'EOF'
#!/bin/sh
exec env DESKTOPINTEGRATION=1 zypak-wrapper.sh /app/lib/zalo/zalo "$@"
EOF

install -Dm0644 flatpak/com.zalo.linux.desktop /app/share/applications/com.zalo.linux.desktop

ICON_PATH="app/pc-dist/favicon-512x512.png"
install -Dm0644 "$ICON_PATH" /app/share/icons/hicolor/512x512/apps/com.zalo.linux.png

install -Dm0644 "flatpak/com.zalo.linux.metainfo.xml" "/app/share/metainfo/com.zalo.linux.metainfo.xml"
