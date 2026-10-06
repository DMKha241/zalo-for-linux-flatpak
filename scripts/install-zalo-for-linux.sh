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
export SNI_ID="net.vietnamlinuxfamily.zalo-for-linux"
exec env DESKTOPINTEGRATION=1 zypak-wrapper.sh /app/lib/zalo/zalo "$@"
EOF

install -Dm0644 flatpak/net.vietnamlinuxfamily.zalo-for-linux.desktop /app/share/applications/net.vietnamlinuxfamily.zalo-for-linux.desktop

ICON_PATH="app/pc-dist/favicon-512x512.png"
install -Dm0644 "$ICON_PATH" /app/share/icons/hicolor/512x512/apps/net.vietnamlinuxfamily.zalo-for-linux.png

install -Dm0644 "flatpak/net.vietnamlinuxfamily.zalo-for-linux.metainfo.xml" "/app/share/metainfo/net.vietnamlinuxfamily.zalo-for-linux.metainfo.xml"
