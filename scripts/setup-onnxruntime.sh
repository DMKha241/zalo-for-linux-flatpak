#!/bin/sh
set -eu

case "$(uname -m)" in
    x86_64) onnx_arch=x64 ;;
    aarch64) onnx_arch=aarch64 ;;
    *) echo "Unsupported ONNX Runtime architecture: $(uname -m)" >&2; exit 1 ;;
esac

onnx_source=onnxruntime
onnx_build="$onnx_source/_build"
onnx_package="onnxruntime-linux-$onnx_arch-1.30.0"
logger=./build-logger.sh

install -d /app/lib/prebuilt

test "$(cat "$onnx_source/VERSION_NUMBER")" = 1.30.0

# Upstream supports keeping diagnostics non-fatal with newer SDK compilers.
"$logger" onnxruntime-configure.log cmake --compile-no-warning-as-error --trace-expand -S "$onnx_source/cmake" -B "$onnx_build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -Donnxruntime_BUILD_SHARED_LIB=ON \
    -Donnxruntime_BUILD_UNIT_TESTS=OFF \
    -Donnxruntime_BUILD_BENCHMARKS=OFF \
    -Donnxruntime_ENABLE_PYTHON=OFF \
    -Donnxruntime_USE_TELEMETRY=OFF \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -Donnxruntime_CMAKE_DEPS_MIRROR_DIR="$PWD/flatpak-onnx-deps"
"$logger" onnxruntime-build.log cmake --build "$onnx_build" --target onnxruntime --parallel "${FLATPAK_BUILDER_N_JOBS:-2}"

install -d "temp/$onnx_package/lib" "temp/$onnx_package/include"
install -Dm0755 "$onnx_build"/libonnxruntime.so* "temp/$onnx_package/lib/"
install -Dm0644 "$onnx_source"/include/onnxruntime/core/session/*.h "temp/$onnx_package/include/"
install -Dm0644 "$onnx_source/LICENSE" "$onnx_source/ThirdPartyNotices.txt" "$onnx_source/VERSION_NUMBER" "temp/$onnx_package/"
# Test
test -f "temp/$onnx_package/lib/libonnxruntime.so"
python3 verify-onnxruntime.py "temp/$onnx_package/lib/libonnxruntime.so" "1.30.0"
tar -czf "/app/lib/prebuilt/$onnx_package.tgz" -C temp "$onnx_package"
