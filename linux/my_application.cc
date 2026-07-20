#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <cstring>

#include "flutter/generated_plugin_registrant.h"
#include "splash_screen.h"

#include <bitsdojo_window_linux/bitsdojo_window_plugin.h>

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // Channel the Flutter side uses to push status to / dismiss the native splash
  // (mirrors splash_channel_ in windows/runner/flutter_window.cpp).
  FlMethodChannel* splash_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Handles status pushes and dismissal from the Flutter side over the
// `bluebubbles/splash` channel. Runs on the GTK main thread, so it can touch
// the splash widgets directly.
static void splash_method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                                  gpointer user_data) {
  (void)channel;
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "setStatus") == 0) {
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      set_splash_status(fl_value_get_string(args));
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "closeSplash") == 0) {
    close_splash_screen();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to splash channel call: %s", error->message);
  }
}

// True when "minimized" was passed on the command line — the app starts hidden
// in the tray, so we skip the splash (mirrors the Windows runner).
static gboolean started_minimized(char** arguments) {
  for (char** arg = arguments; arg != nullptr && *arg != nullptr; arg++) {
    if (g_strcmp0(*arg, "minimized") == 0) return TRUE;
  }
  return FALSE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "bluebubbles_app");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    auto bdw = bitsdojo_window_from(window);
    bdw->setCustomFrame(true);
    gtk_window_set_title(window, "bluebubbles_app");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_realize(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);

  // Fallback for the brief moment before Flutter's first frame: clear the
  // FlView to the splash background color instead of the default black, so any
  // sliver visible around the splash overlay matches rather than flashing.
  GdkRGBA view_bg;
  view_bg.alpha = 1.0;
  if (splash_is_dark_mode()) {
    view_bg.red = 28.0 / 255.0;
    view_bg.green = 28.0 / 255.0;
    view_bg.blue = 30.0 / 255.0;
  } else {
    view_bg.red = 1.0;
    view_bg.green = 1.0;
    view_bg.blue = 1.0;
  }
  fl_view_set_background_color(view, &view_bg);

  gtk_widget_show(GTK_WIDGET(view));

  // Put the FlView under a GtkOverlay so the native splash can sit on top of it
  // inside the same window. The splash overlay is opaque and fills the window,
  // hiding the still-blank FlView; Flutter rasterizes its first frame
  // underneath while init runs, and the overlay is removed (closeSplash) once
  // that content is ready.
  GtkWidget* overlay = gtk_overlay_new();
  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), overlay);
  gtk_widget_show(overlay);

  if (!started_minimized(self->dart_entrypoint_arguments)) {
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), create_splash_widget());
    // Show the window now, at its normal/default size, so the FlView starts
    // rendering during startup behind the splash overlay. We deliberately don't
    // resize or position it — leaving placement to the OS/compositor lets it
    // remember where the user last put the window.
    gtk_widget_show(GTK_WIDGET(window));
  }

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Channel the Flutter side uses to drive the native splash (see
  // splash_screen.cc and pushStatus in lib/main.dart).
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->splash_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "bluebubbles/splash", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->splash_channel, splash_method_call_cb,
                                            self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->splash_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
