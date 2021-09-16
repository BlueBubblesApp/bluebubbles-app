//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <maps_launcher/maps_launcher_plugin.h>
#include <quick_notify/quick_notify_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>
#include <window_size/window_size_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) maps_launcher_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MapsLauncherPlugin");
  maps_launcher_plugin_register_with_registrar(maps_launcher_registrar);
  g_autoptr(FlPluginRegistrar) quick_notify_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "QuickNotifyPlugin");
  quick_notify_plugin_register_with_registrar(quick_notify_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) window_size_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowSizePlugin");
  window_size_plugin_register_with_registrar(window_size_registrar);
}
