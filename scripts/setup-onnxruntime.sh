#!/bin/sh
set -eu

case "$(uname -m)" in
    x86_64) onnx_arch=x64 ;;
    aarch64) onnx_arch=aarch64 ;;
    *) echo "Unsupported ONNX Runtime architecture: $(uname -m)" >&2; exit 1 ;;
esac

onnx_source=flatpak-onnxruntime
onnx_build="$onnx_source/_build"
onnx_package="onnxruntime-linux-$onnx_arch-1.30.0"
test "$(cat "$onnx_source/VERSION_NUMBER")" = 1.30.0

# Upstream supports keeping diagnostics non-fatal with newer SDK compilers.
cmake --compile-no-warning-as-error -S "$onnx_source/cmake" -B "$onnx_build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -Donnxruntime_BUILD_SHARED_LIB=ON \
    -Donnxruntime_BUILD_UNIT_TESTS=OFF \
    -Donnxruntime_BUILD_BENCHMARKS=OFF \
    -Donnxruntime_ENABLE_PYTHON=OFF \
    -Donnxruntime_USE_TELEMETRY=OFF \
    -Donnxruntime_CMAKE_DEPS_MIRROR_DIR="$PWD/flatpak-onnx-deps"
cmake --build "$onnx_build" --target onnxruntime --parallel "${FLATPAK_BUILDER_N_JOBS:-2}"

# Match the upstream archive layout consumed by patch-zocr-runtime.js.
mkdir -p "temp/$onnx_package/lib" "temp/$onnx_package/include"
cp -a "$onnx_build"/libonnxruntime.so* "temp/$onnx_package/lib/"
cp "$onnx_source"/include/onnxruntime/core/session/*.h "temp/$onnx_package/include/"
cp "$onnx_source/LICENSE" "$onnx_source/ThirdPartyNotices.txt" "$onnx_source/VERSION_NUMBER" "temp/$onnx_package/"
test -f "temp/$onnx_package/lib/libonnxruntime.so"
python3 - "temp/$onnx_package/lib/libonnxruntime.so" <<'PY'
import ctypes
import sys

class OrtApiBase(ctypes.Structure):
    _fields_ = [('GetApi', ctypes.c_void_p),
                ('GetVersionString', ctypes.CFUNCTYPE(ctypes.c_char_p))]

runtime = ctypes.CDLL(sys.argv[1])
runtime.OrtGetApiBase.restype = ctypes.POINTER(OrtApiBase)
assert runtime.OrtGetApiBase().contents.GetVersionString() == b'1.30.0'
PY
tar -czf "temp/$onnx_package.tgz" -C temp "$onnx_package"
