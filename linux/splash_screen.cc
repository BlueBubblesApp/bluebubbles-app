#include "splash_screen.h"

#include <gtk/gtk.h>
#include <pango/pangocairo.h>

#include <climits>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

namespace {

// Logical (unscaled) layout, mirroring windows/runner/splash_screen.cpp. A
// fixed box centered within whatever size the window happens to be; GTK applies
// the monitor scale factor to the Cairo context for us.
constexpr int kWindowH = 300;
constexpr int kIcon = 72;
constexpr int kIconTop = 40;
constexpr int kVersionTop = 124;
constexpr int kVersionHeight = 18;
constexpr int kStatusTop = 168;
constexpr int kStatusHeight = 40;
constexpr int kVersionFont = 12;
constexpr int kStatusFont = 12;

// Safety: if closeSplash never arrives, tear the splash down anyway.
constexpr int kAutoCloseSeconds = 20;

GtkWidget* g_area = nullptr;
GdkPixbuf* g_icon = nullptr;
guint g_autoclose_id = 0;
bool g_dark = true;

// Fixed buffers keep the pre-engine splash independent of the C++ runtime and
// avoid heap work while the allocator and Flutter engine are starting up.
char g_status[256] = "Starting...";
char g_version_line[128] = "";

// Reads the app's persisted theme choice from shared_preferences.json (next to
// the DB, under the same XDG data dir path_provider uses). Returns 1 dark,
// 0 light, -1 system/unknown (caller falls back to GTK detection).
int ReadPrefsDark() {
  char path[PATH_MAX];
  g_snprintf(path, sizeof(path), "%s/bluebubbles/shared_preferences.json",
             g_get_user_data_dir());
  gchar* contents = nullptr;
  if (!g_file_get_contents(path, &contents, nullptr, nullptr)) return -1;
  int result = -1;
  // adaptive_theme stores {"theme_mode":N,...}: 0 light, 1 dark, 2 system.
  char* pref = strstr(contents, "adaptive_theme_preferences");
  if (pref != nullptr) {
    char* mode = strstr(pref, "theme_mode");
    char* colon = mode != nullptr ? strchr(mode, ':') : nullptr;
    if (colon != nullptr) {
      int value = atoi(colon + 1);
      if (value == 0 || value == 1) result = value;
    }
  }
  g_free(contents);
  return result;
}

// Matches the app's light/dark choice: prefers the persisted theme_mode, and
// for system mode (or before first launch) honors prefer-dark / sniffs the
// GTK theme name.
bool IsDarkMode() {
  int prefs = ReadPrefsDark();
  if (prefs >= 0) return prefs == 1;
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) return true;
  gboolean prefer_dark = FALSE;
  gchar* theme = nullptr;
  g_object_get(settings, "gtk-application-prefer-dark-theme", &prefer_dark,
               "gtk-theme-name", &theme, nullptr);
  bool dark = prefer_dark;
  if (!dark && theme != nullptr) {
    gchar* lower = g_ascii_strdown(theme, -1);
    dark = strstr(lower, "dark") != nullptr;
    g_free(lower);
  }
  g_free(theme);
  return dark;
}

// Fills `out` with the directory of the running binary. Returns false if it
// can't be determined.
bool ExeDir(char* out, size_t n) {
  char exe[PATH_MAX];
  ssize_t len = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
  if (len <= 0) return false;
  exe[len] = '\0';
  char* slash = strrchr(exe, '/');
  if (slash == nullptr) return false;
  size_t dir_len = static_cast<size_t>(slash - exe);
  if (dir_len >= n) return false;
  memcpy(out, exe, dir_len);
  out[dir_len] = '\0';
  return true;
}

// Reads the app version from the bundle's version.json (patched to the release
// version by linux/build.sh). Fills `out`, returns false if unavailable.
bool ReadBundleVersion(char* out, size_t n) {
  char dir[PATH_MAX];
  if (!ExeDir(dir, sizeof(dir))) return false;
  char path[PATH_MAX];
  g_snprintf(path, sizeof(path), "%s/data/flutter_assets/version.json", dir);
  gchar* contents = nullptr;
  if (!g_file_get_contents(path, &contents, nullptr, nullptr)) return false;
  // Minimal extraction of the version JSON field — no parser needed. Flutter
  // writes this file pretty-printed, so tolerate whitespace around the colon.
  bool ok = false;
  const char* key = "\"version\"";
  char* start = strstr(contents, key);
  if (start != nullptr) {
    start += strlen(key);
    while (g_ascii_isspace(*start)) ++start;
    if (*start == ':') {
      ++start;
      while (g_ascii_isspace(*start)) ++start;
      if (*start == '"') {
        ++start;
        char* end = strchr(start, '"');
        if (end != nullptr && static_cast<size_t>(end - start) < n) {
          memcpy(out, start, end - start);
          out[end - start] = '\0';
          ok = true;
        }
      }
    }
  }
  g_free(contents);
  return ok;
}

void BuildVersionLine(char* out, size_t n) {
  char version[64];
  if (!ReadBundleVersion(version, sizeof(version))) {
    g_strlcpy(version, "?", sizeof(version));
  }
  const char* tag = "";
  if (g_getenv("FLATPAK_ID") != nullptr) {
    tag = " (Flatpak)";
  } else if (g_getenv("SNAP") != nullptr) {
    tag = " (Snap)";
  }
  g_snprintf(out, n, "v%s%s", version, tag);
}

// Loads the bundled app icon, or nullptr if not found (splash renders without).
GdkPixbuf* LoadIcon() {
  char dir[PATH_MAX];
  if (!ExeDir(dir, sizeof(dir))) return nullptr;
  char path[PATH_MAX];
  g_snprintf(path, sizeof(path), "%s/data/flutter_assets/assets/icon/icon.png", dir);
  GError* error = nullptr;
  GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(path, &error);
  if (error != nullptr) {
    g_error_free(error);
    return nullptr;
  }
  return pixbuf;
}

void DrawCenteredText(cairo_t* cr, const char* text, int top, int height,
                      int font_size, double alpha, int width) {
  PangoLayout* layout = pango_cairo_create_layout(cr);
  PangoFontDescription* desc = pango_font_description_from_string("Sans");
  pango_font_description_set_absolute_size(desc, font_size * PANGO_SCALE);
  pango_layout_set_font_description(layout, desc);
  pango_font_description_free(desc);

  pango_layout_set_text(layout, text, -1);
  pango_layout_set_width(layout, width * PANGO_SCALE);
  pango_layout_set_alignment(layout, PANGO_ALIGN_CENTER);
  pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);

  int text_h = 0;
  pango_layout_get_pixel_size(layout, nullptr, &text_h);

  double channel = g_dark ? 1.0 : 0.0;
  cairo_set_source_rgba(cr, channel, channel, channel, alpha);
  cairo_move_to(cr, 0, top + (height - text_h) / 2.0);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
}

gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer user_data) {
  (void)user_data;
  int w = gtk_widget_get_allocated_width(widget);
  int h = gtk_widget_get_allocated_height(widget);

  // Opaque background hides the FlView underneath until the splash is removed.
  if (g_dark) {
    cairo_set_source_rgb(cr, 28 / 255.0, 28 / 255.0, 30 / 255.0);
  } else {
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
  }
  cairo_paint(cr);

  // Vertically center the fixed-height layout within the real widget height.
  double oy = (h - kWindowH) / 2.0;
  if (oy < 0) oy = 0;
  cairo_save(cr);
  cairo_translate(cr, 0, oy);

  if (g_icon != nullptr) {
    int iw = gdk_pixbuf_get_width(g_icon);
    int ih = gdk_pixbuf_get_height(g_icon);
    int longest = iw > ih ? iw : ih;
    if (longest > 0) {
      double scale = static_cast<double>(kIcon) / longest;
      cairo_save(cr);
      cairo_translate(cr, (w - iw * scale) / 2.0, kIconTop);
      cairo_scale(cr, scale, scale);
      gdk_cairo_set_source_pixbuf(cr, g_icon, 0, 0);
      cairo_paint(cr);
      cairo_restore(cr);
    }
  }

  DrawCenteredText(cr, g_version_line, kVersionTop, kVersionHeight, kVersionFont, 0.47, w);
  DrawCenteredText(cr, g_status, kStatusTop, kStatusHeight, kStatusFont, 0.65, w);

  cairo_restore(cr);
  return FALSE;
}

gboolean OnAutoClose(gpointer user_data) {
  (void)user_data;
  g_autoclose_id = 0;
  close_splash_screen();
  return G_SOURCE_REMOVE;
}

}  // namespace

GtkWidget* create_splash_widget() {
  g_dark = IsDarkMode();
  BuildVersionLine(g_version_line, sizeof(g_version_line));
  g_icon = LoadIcon();

  g_area = gtk_drawing_area_new();
  gtk_widget_set_halign(g_area, GTK_ALIGN_FILL);
  gtk_widget_set_valign(g_area, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(g_area, TRUE);
  gtk_widget_set_vexpand(g_area, TRUE);
  g_signal_connect(G_OBJECT(g_area), "draw", G_CALLBACK(OnDraw), nullptr);
  gtk_widget_show(g_area);

  g_autoclose_id = g_timeout_add_seconds(kAutoCloseSeconds, OnAutoClose, nullptr);
  return g_area;
}

void set_splash_status(const char* status) {
  if (status != nullptr) g_strlcpy(g_status, status, sizeof(g_status));
  if (g_area != nullptr) gtk_widget_queue_draw(g_area);
}

void close_splash_screen() {
  if (g_autoclose_id != 0) {
    g_source_remove(g_autoclose_id);
    g_autoclose_id = 0;
  }
  if (g_area != nullptr) {
    gtk_widget_destroy(g_area);
    g_area = nullptr;
  }
  if (g_icon != nullptr) {
    g_object_unref(g_icon);
    g_icon = nullptr;
  }
}

bool splash_is_dark_mode() {
  return g_area != nullptr ? g_dark : IsDarkMode();
}
