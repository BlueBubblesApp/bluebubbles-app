#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  bitsdojo_window_windows
  connectivity_plus
  desktop_webview_auth
  dynamic_color
  emoji_picker_flutter
  file_selector_windows
  flutter_acrylic
  flutter_timezone
  geolocator_windows
  irondash_engine_context
  local_auth_windows
  local_notifier
  maps_launcher
  media_kit_libs_windows_video
  media_kit_video
  objectbox_flutter_libs
  pasteboard
  permission_handler_windows
  printing
  record_windows
  screen_brightness_windows
  screen_retriever_windows
  secure_application
  share_plus
  super_native_extensions
  system_tray
  tray_manager
  url_launcher_windows
  window_manager
  windows_taskbar
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  media_kit_native_event_loop
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
