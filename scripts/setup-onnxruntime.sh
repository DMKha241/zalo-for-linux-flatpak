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

onnx_lib_dir="temp/$onnx_package/lib"
install -d "$onnx_lib_dir" "temp/$onnx_package/include"

for library in "$onnx_build"/libonnxruntime.so*; do
    library_name=${library##*/}
    if [ -L "$library" ]; then
        ln -sfn "$(readlink "$library")" "$onnx_lib_dir/$library_name"
    elif [ -f "$library" ]; then
        install -p -m0755 "$library" "$onnx_lib_dir/$library_name"
    else
        echo "Unexpected ONNX Runtime library entry: $library" >&2
        exit 1
    fi
done

install -p -m0644 "$onnx_source"/include/onnxruntime/core/session/*.h "temp/$onnx_package/include/"
install -p -m0644 "$onnx_source/LICENSE" "$onnx_source/ThirdPartyNotices.txt" "$onnx_source/VERSION_NUMBER" "temp/$onnx_package/"

test -f "$onnx_lib_dir/libonnxruntime.so"
test -L "$onnx_lib_dir/libonnxruntime.so"
test "$(readlink "$onnx_lib_dir/libonnxruntime.so")" = libonnxruntime.so.1
test -L "$onnx_lib_dir/libonnxruntime.so.1"
test "$(readlink "$onnx_lib_dir/libonnxruntime.so.1")" = libonnxruntime.so.1.30.0
python3 verify-onnxruntime.py "$onnx_lib_dir/libonnxruntime.so" "1.30.0"
tar -czf "/app/lib/prebuilt/$onnx_package.tgz" -C temp "$onnx_package"
