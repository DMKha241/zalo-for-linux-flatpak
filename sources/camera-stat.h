#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <sys/sysmacros.h>
#include <unistd.h>

static int camera_index(const char *path)
{
    if (strncmp(path, "/dev/video", 10) || path[10] < '0' || path[10] > '9')
        return -1;
    char *end;
    int saved_errno = errno;
    unsigned long index = strtoul(path + 10, &end, 10);
    errno = saved_errno;
    return !*end && index < 32 ? (int)index : -1;
}

/* Wine avicap checks S_ISCHR before the existing PipeWire open/ioctl shim. */
#define CAMERA_STAT(name, type, signature, args) \
SPA_EXPORT int name signature \
{ \
    int (*original) signature = dlsym(RTLD_NEXT, #name); \
    int result = original args; \
    int index; \
    if (result == 0 || errno != ENOENT || (index = camera_index(path)) < 0) \
        return result; \
    int fd = get_fops()->openat(AT_FDCWD, path, O_RDWR | O_NONBLOCK, 0); \
    if (fd < 0) return -1; \
    get_fops()->close(fd); \
    memset(buf, 0, sizeof(*buf)); \
    buf->st_mode = S_IFCHR | 0600; \
    buf->st_rdev = makedev(81, index); \
    buf->st_nlink = 1; \
    buf->st_uid = geteuid(); \
    buf->st_gid = getegid(); \
    return 0; \
}

CAMERA_STAT(stat, struct stat, (const char *path, struct stat *buf), (path, buf))
CAMERA_STAT(stat64, struct stat64, (const char *path, struct stat64 *buf), (path, buf))
CAMERA_STAT(__xstat, struct stat, (int version, const char *path, struct stat *buf), (version, path, buf))
CAMERA_STAT(__xstat64, struct stat64, (int version, const char *path, struct stat64 *buf), (version, path, buf))
