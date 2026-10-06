"""Add Camera portal connections and virtual /dev/video stat support to PipeWire."""
from pathlib import Path
import sys

source = Path(sys.argv[1]) / 'pipewire-v4l2/src'
core = source / 'pipewire-v4l2.c'
text = core.read_text()
needle = '\tfile->core = pw_context_connect(file->context,\n\t\t\tpw_properties_copy(file->props), 0);'
assert text.count(needle) == 1, 'PipeWire connection implementation changed'
replacement = '''\tint remote_fd = -1;
\tif (access("/.flatpak-info", F_OK) == 0) {
\t\tremote_fd = camera_remote_fd();
\t\tif (remote_fd < 0) goto error_unlock;
\t}
\tfile->core = remote_fd < 0
\t\t? pw_context_connect(file->context, pw_properties_copy(file->props), 0)
\t\t: pw_context_connect_fd(file->context, remote_fd, pw_properties_copy(file->props), 0);'''
text = text.replace('#include <pipewire/pipewire.h>', '#include <pipewire/pipewire.h>\n#include "camera-remote.h"')
core.write_text(text.replace(needle, replacement))
frontend = source / 'v4l2-func.c'
frontend.write_text(frontend.read_text() + '\n#include "camera-stat.h"\n')
