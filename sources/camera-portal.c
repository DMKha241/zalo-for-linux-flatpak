#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

static GMainLoop *loop;
static guint response = 2;

static void camera_response(GDBusConnection *bus, const char *sender,
    const char *path, const char *interface, const char *signal,
    GVariant *parameters, void *data)
{
    if (!g_variant_is_of_type(parameters, G_VARIANT_TYPE("(ua{sv})"))) {
        g_main_loop_quit(loop);
        return;
    }
    GVariant *results;
    g_variant_get(parameters, "(u@a{sv})", &response, &results);
    g_variant_unref(results);
    g_main_loop_quit(loop);
}

static gboolean timeout(void *data)
{
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

int main(void)
{
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!bus) goto fail;
    const char *unique = g_dbus_connection_get_unique_name(bus);
    char *sender = g_strdup(unique + 1);
    for (char *p = sender; *p; ++p) if (*p == '.') *p = '_';
    char *token = g_strdup_printf("zalo_camera_%ld", (long)getpid());
    char *path = g_strdup_printf("/org/freedesktop/portal/desktop/request/%s/%s", sender, token);
    loop = g_main_loop_new(NULL, FALSE);
    guint subscription = g_dbus_connection_signal_subscribe(bus,
        "org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
        path, NULL, G_DBUS_SIGNAL_FLAGS_NONE, camera_response, NULL, NULL);
    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add(&options, "{sv}", "handle_token", g_variant_new_string(token));
    GVariant *reply = g_dbus_connection_call_sync(bus,
        "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.Camera", "AccessCamera",
        g_variant_new("(a{sv})", &options), G_VARIANT_TYPE("(o)"),
        G_DBUS_CALL_FLAGS_NONE, 30000, NULL, &error);
    if (!reply) goto fail;
    g_variant_unref(reply);
    guint timer = g_timeout_add_seconds(120, timeout, NULL);
    g_main_loop_run(loop);
    if (response != 0) {
        /* Close a pending request on cancellation or timeout. */
        reply = g_dbus_connection_call_sync(bus, "org.freedesktop.portal.Desktop",
            path, "org.freedesktop.portal.Request", "Close", NULL, NULL,
            G_DBUS_CALL_FLAGS_NONE, 1000, NULL, NULL);
        if (reply) g_variant_unref(reply);
        goto fail;
    }
    g_source_remove(timer);
    g_dbus_connection_signal_unsubscribe(bus, subscription);
    GUnixFDList *fds = NULL;
    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    reply = g_dbus_connection_call_with_unix_fd_list_sync(bus,
        "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.Camera", "OpenPipeWireRemote",
        g_variant_new("(a{sv})", &options), G_VARIANT_TYPE("(h)"),
        G_DBUS_CALL_FLAGS_NONE, 30000, NULL, &fds, NULL, &error);
    if (!reply) goto fail;
    int handle;
    g_variant_get(reply, "(h)", &handle);
    int fd = g_unix_fd_list_get(fds, handle, &error);
    if (fd < 0) goto fail;
    char byte = 0, control[CMSG_SPACE(sizeof(int))] = {0};
    struct iovec iov = { &byte, 1 };
    struct msghdr message = { .msg_iov = &iov, .msg_iovlen = 1,
        .msg_control = control, .msg_controllen = sizeof(control) };
    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&message);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(cmsg), &fd, sizeof(fd));
    int sent = sendmsg(STDOUT_FILENO, &message, MSG_NOSIGNAL);
    close(fd);
    return sent == 1 ? 0 : 1;
fail:
    if (error) fprintf(stderr, "Camera portal: %s\n", error->message);
    return 1;
}
