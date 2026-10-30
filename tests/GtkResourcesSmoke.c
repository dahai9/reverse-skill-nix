#include <gtk/gtk.h>

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    const char *icons[] = {"image-missing", "dialog-warning-symbolic"};
    for (guint i = 0; i < G_N_ELEMENTS(icons); i++) {
        GError *error = NULL;
        GdkPixbuf *image = gtk_icon_theme_load_icon(
            gtk_icon_theme_get_default(), icons[i], 48,
            GTK_ICON_LOOKUP_FORCE_SIZE, &error);
        if (image == NULL) {
            g_printerr("Cannot load theme icon %s: %s\n", icons[i],
                       error ? error->message : "unknown error");
            g_clear_error(&error);
            return 1;
        }
        g_object_unref(image);
    }
    gchar *type = g_content_type_guess("test.svg", NULL, 0, NULL);
    gchar *mime = g_content_type_get_mime_type(type);
    gboolean valid = g_strcmp0(mime, "image/svg+xml") == 0;
    if (!valid) {
        g_printerr("SVG MIME lookup returned %s\n", mime ? mime : "NULL");
    }
    g_free(mime);
    g_free(type);
    if (!valid) return 1;
    g_print("GTK theme icons and SVG MIME lookup passed\n");
    return 0;
}
