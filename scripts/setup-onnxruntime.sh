#!/bin/sh
set -eu

onnx_source=onnxruntime
onnx_build="$onnx_source/_build"
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

onnx_library=libonnxruntime.so.1.30.0

test -f "$onnx_build/$onnx_library"
test ! -L "$onnx_build/$onnx_library"
install -p -m0755 "$onnx_build/$onnx_library" "/app/lib/prebuilt/$onnx_library"
python3 verify-onnxruntime.py "/app/lib/prebuilt/$onnx_library" "1.30.0"
