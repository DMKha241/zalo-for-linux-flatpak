#include <poll.h>
#include <sys/wait.h>
#include <unistd.h>
#include <spawn.h>

extern char **environ;

/* Use the native portal helper even from a 32-bit Wine client. */
static int camera_remote_fd(void)
{
    int sockets[2], fd = -1;
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, sockets) < 0)
        return -1;
    posix_spawn_file_actions_t actions;
    int error = posix_spawn_file_actions_init(&actions);
    if (error) { close(sockets[0]); close(sockets[1]); errno = error; return -1; }
    error = posix_spawn_file_actions_adddup2(&actions, sockets[1], STDOUT_FILENO);
    if (!error && sockets[0] != STDOUT_FILENO)
        error = posix_spawn_file_actions_addclose(&actions, sockets[0]);
    if (!error && sockets[1] != STDOUT_FILENO)
        error = posix_spawn_file_actions_addclose(&actions, sockets[1]);
    pid_t child;
    char *args[] = { "zalo-camera-portal", NULL };
    if (!error) error = posix_spawn(&child, "/app/bin/zalo-camera-portal", &actions, NULL, args, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(sockets[1]);
    if (error) { close(sockets[0]); errno = error; return -1; }
    struct pollfd pfd = { .fd = sockets[0], .events = POLLIN };
    int ready;
    do { ready = poll(&pfd, 1, 200000); } while (ready < 0 && errno == EINTR);
    if (ready > 0) {
        char byte, control[CMSG_SPACE(sizeof(int))] = {0};
        struct iovec iov = { &byte, 1 };
        struct msghdr message = { .msg_iov = &iov, .msg_iovlen = 1,
            .msg_control = control, .msg_controllen = sizeof(control) };
        if (recvmsg(sockets[0], &message, MSG_CMSG_CLOEXEC) == 1) {
            struct cmsghdr *cmsg = CMSG_FIRSTHDR(&message);
            if (!(message.msg_flags & MSG_CTRUNC) && cmsg &&
                cmsg->cmsg_level == SOL_SOCKET && cmsg->cmsg_type == SCM_RIGHTS &&
                cmsg->cmsg_len == CMSG_LEN(sizeof(int)))
                memcpy(&fd, CMSG_DATA(cmsg), sizeof(fd));
        }
    }
    close(sockets[0]);
    if (ready <= 0) kill(child, SIGTERM);
    while (waitpid(child, NULL, 0) < 0 && errno == EINTR) {}
    if (fd < 0) errno = EACCES;
    return fd;
}
