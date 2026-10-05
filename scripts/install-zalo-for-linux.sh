#!/bin/sh
set -eu

install -d /app/lib/zalo
cp -a dist/linux-unpacked/. /app/lib/zalo/

install -Dm0755 /dev/stdin /app/bin/zalo <<'EOF'
#!/bin/sh
exec env DESKTOPINTEGRATION=1 zypak-wrapper.sh /app/lib/zalo/zalo "$@"
EOF

install -Dm0644 flatpak/com.zalo.linux.desktop /app/share/applications/com.zalo.linux.desktop

ICON_PATH="app/pc-dist/favicon-512x512.png"
install -Dm0644 "$ICON_PATH" /app/share/icons/hicolor/512x512/apps/com.zalo.linux.png

install -Dm0644 "flatpak/com.zalo.linux.metainfo.xml" "/app/share/metainfo/com.zalo.linux.metainfo.xml"