//
//  Generated file. Do not edit.
//

#include "generated_plugin_registrant.h"

#include <connectivity_plus_windows/connectivity_plus_windows_plugin.h>
#include <maps_launcher/maps_launcher_plugin.h>
#include <secure_application/secure_application_plugin.h>
#include <url_launcher_windows/url_launcher_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  ConnectivityPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  MapsLauncherPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MapsLauncherPlugin"));
  SecureApplicationPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SecureApplicationPlugin"));
  UrlLauncherPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherPlugin"));
}
