//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_tts/flutter_tts_plugin.h>
#include <flutter_udid/flutter_udid_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <record_windows/record_windows_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterTtsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTtsPlugin"));
  FlutterUdidPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterUdidPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  RecordWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("RecordWindowsPluginCApi"));
}
