#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  bitsdojo_window_linux
  desktop_webview_auth
  dynamic_color
  emoji_picker_flutter
  file_selector_linux
  flutter_acrylic
  gtk
  irondash_engine_context
  local_notifier
  maps_launcher
  media_kit_libs_linux
  media_kit_video
  objectbox_flutter_libs
  pasteboard
  printing
  record_linux
  screen_retriever_linux
  super_native_extensions
  system_tray
  tray_manager
  url_launcher_linux
  window_manager
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  media_kit_native_event_loop
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
