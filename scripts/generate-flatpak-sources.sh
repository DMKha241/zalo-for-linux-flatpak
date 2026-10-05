#!/bin/sh
# Usage: sh scripts/generate-flatpak-sources.sh SOURCE_DIR OUTPUT_DIR
# Requires flatpak-node-generator, flatpak-cargo-generator(.py), jq.
# Override the Cargo tool location with CARGO_GENERATOR=/path/to/tool.
set -eu

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
    echo 'Usage: sh scripts/generate-flatpak-sources.sh SOURCE_DIR OUTPUT_DIR' >&2
    exit 1
fi
ROOT=$(CDPATH= cd -- "$1" && pwd)
OUT=$2
for tool in flatpak-node-generator jq; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
CARGO_GENERATOR=${CARGO_GENERATOR:-$(command -v flatpak-cargo-generator || command -v flatpak-cargo-generator.py || true)}
[ -n "$CARGO_GENERATOR" ] || { echo 'Missing flatpak-cargo-generator; set CARGO_GENERATOR to its path.' >&2; exit 1; }
case "$CARGO_GENERATOR" in
    *.py) command -v python3 >/dev/null; [ -f "$CARGO_GENERATOR" ] ;;
    *) command -v "$CARGO_GENERATOR" >/dev/null ;;
esac
# Resolve a relative tool path before entering temporary npm directories.
case "$CARGO_GENERATOR" in
    */*) CARGO_GENERATOR=$(CDPATH= cd -- "$(dirname -- "$CARGO_GENERATOR")" && pwd)/$(basename -- "$CARGO_GENERATOR") ;;
esac

mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
WORK=$(mktemp -d "$OUT/.flatpak-sources.XXXXXX")
trap 'rm -rf -- "$WORK"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$WORK/npm" "$WORK/gyp" "$WORK/cargo"

# Isolate lockfiles from installed node_modules without modifying the project.
copy_npm_files() {
    for name in package.json package-lock.json .npmrc; do
        if [ -f "$1/$name" ]; then cp -- "$1/$name" "$2/$name"; fi
    done
}
[ -f "$ROOT/package-lock.json" ] || { echo 'Missing root package-lock.json' >&2; exit 1; }
copy_npm_files "$ROOT" "$WORK/npm"

find "$ROOT/nativelibs" \( -type d \( -name node_modules -o -name target -o -name build -o -name .git \) -prune \) \
    -o -type f -name binding.gyp -print > "$WORK/gyp.list"
printf '%s\n' '{"lockfileVersion":3,"packages":{}}' > "$WORK/gyp/package-lock.json"
printf '%s\n' '{}' > "$WORK/gyp/package.json"
while IFS= read -r binding; do
    addon=$(dirname -- "$binding")
    [ -f "$addon/package-lock.json" ] || { echo "Missing $addon/package-lock.json" >&2; exit 1; }
    dest="$WORK/gyp/${addon#"$ROOT/"}"
    mkdir -p "$dest"
    copy_npm_files "$addon" "$dest"
done < "$WORK/gyp.list"

find "$ROOT" \( -type d \( -name .git -o -name node_modules -o -name target -o -name dist -o -name build -o -name .flatpak-builder -o -path "$WORK" \) -prune \) \
    -o -type f -name Cargo.lock -print > "$WORK/cargo.list"
[ -s "$WORK/cargo.list" ] || { echo 'No Cargo.lock found' >&2; exit 1; }
index=0
while IFS= read -r lock; do
    index=$((index + 1))
    case "$CARGO_GENERATOR" in
        *.py) python3 "$CARGO_GENERATOR" "$lock" -o "$WORK/cargo/$index.json" ;;
        *) "$CARGO_GENERATOR" "$lock" -o "$WORK/cargo/$index.json" ;;
    esac
done < "$WORK/cargo.list"
# Upstream emits Cargo config too; refuse to overwrite differing configs.
jq -s '
    add | unique
    | if ([.[] | select(.type == "inline" and .dest == "cargo"
           and (."dest-filename" == "config" or ."dest-filename" == "config.toml"))] | length) > 1
      then error("Cargo generators emitted differing configs; merge them before building")
      else . end
' "$WORK"/cargo/*.json > "$WORK/cargo-crates.json"

(
    cd "$WORK/npm"
    flatpak-node-generator npm package-lock.json --no-xdg-layout --electron-node-headers \
        --output "$WORK/node_modules.json"
)
if [ -s "$WORK/gyp.list" ]; then
    (
        cd "$WORK/gyp"
        flatpak-node-generator npm package-lock.json --no-xdg-layout --recursive \
            --recursive-pattern 'nativelibs/*/package-lock.json' --output "$WORK/gyp-node_modules.json"
    )
else
    printf '%s\n' '[]' > "$WORK/gyp-node_modules.json"
fi

for name in node_modules.json gyp-node_modules.json cargo-crates.json; do
    jq -e 'type == "array"' "$WORK/$name" >/dev/null
done
for name in node_modules.json gyp-node_modules.json cargo-crates.json; do
    mv -- "$WORK/$name" "$OUT/$name"
    printf 'Wrote %s\n' "$OUT/$name"
done
