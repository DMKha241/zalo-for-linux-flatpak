
#!/usr/bin/env python3

import ctypes
import sys


class OrtApiBase(ctypes.Structure):
    _fields_ = [
        ("GetApi", ctypes.c_void_p),
        ("GetVersionString", ctypes.CFUNCTYPE(ctypes.c_char_p)),
    ]


def verify_runtime(library: str, expected_version: str) -> None:
    try:
        runtime = ctypes.CDLL(library)

        get_api_base = runtime.OrtGetApiBase
        get_api_base.restype = ctypes.POINTER(OrtApiBase)

        api_base = get_api_base()
        if not api_base:
            raise RuntimeError("OrtGetApiBase returned NULL")

        version = api_base.contents.GetVersionString()
        if not version:
            raise RuntimeError("GetVersionString returned NULL")

        actual_version = version.decode("ascii")

        if actual_version != expected_version:
            raise RuntimeError(
                f"Version mismatch: expected {expected_version}, "
                f"got {actual_version}"
            )

        print(f"Verified ONNX Runtime {actual_version}")

    except (OSError, AttributeError, ValueError, RuntimeError) as error:
        raise RuntimeError(
            f"ONNX Runtime verification failed: {error}"
        ) from error


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <library> <expected_version>",
            file=sys.stderr,
        )
        return 2

    try:
        verify_runtime(sys.argv[1], sys.argv[2])
        return 0
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
