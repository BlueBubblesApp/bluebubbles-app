#include "d3d11_multithread.h"

#include <windows.h>
#include <d3d11_4.h>

#include <cstring>

namespace {

// ANGLE loads d3d11.dll at runtime and looks up D3D11CreateDevice with GetProcAddress, so the engine's import of
// GetProcAddress is where its device creation can be wrapped
decltype(&::GetProcAddress) real_get_proc_address = nullptr;
PFN_D3D11_CREATE_DEVICE real_create_device = nullptr;

HRESULT WINAPI CreateDeviceProtected(IDXGIAdapter* adapter, D3D_DRIVER_TYPE driver_type, HMODULE software,
                                     UINT flags, const D3D_FEATURE_LEVEL* feature_levels, UINT num_feature_levels,
                                     UINT sdk_version, ID3D11Device** device, D3D_FEATURE_LEVEL* feature_level,
                                     ID3D11DeviceContext** immediate_context) {
  const HRESULT result = real_create_device(adapter, driver_type, software, flags, feature_levels, num_feature_levels,
                                            sdk_version, device, feature_level, immediate_context);
  if (FAILED(result) || device == nullptr || *device == nullptr) return result;

  ID3D11DeviceContext* context = nullptr;
  (*device)->GetImmediateContext(&context);
  if (context == nullptr) return result;
  ID3D11Multithread* multithread = nullptr;
  if (SUCCEEDED(context->QueryInterface(__uuidof(ID3D11Multithread), reinterpret_cast<void**>(&multithread)))) {
    multithread->SetMultithreadProtected(TRUE);
    multithread->Release();
  }
  context->Release();
  return result;
}

FARPROC WINAPI GetProcAddressHook(HMODULE module, LPCSTR name) {
  const FARPROC proc = real_get_proc_address(module, name);
  // A name below 64K is an ordinal, not a string
  if (proc != nullptr && reinterpret_cast<ULONG_PTR>(name) > 0xFFFF && std::strcmp(name, "D3D11CreateDevice") == 0) {
    real_create_device = reinterpret_cast<PFN_D3D11_CREATE_DEVICE>(proc);
    return reinterpret_cast<FARPROC>(&CreateDeviceProtected);
  }
  return proc;
}

// Points [module]'s import of [function] (by name, from any DLL) at [replacement]. Returns the address it pointed to.
void* PatchImport(HMODULE module, const char* function, void* replacement) {
  auto* base = reinterpret_cast<BYTE*>(module);
  auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
  auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
  const IMAGE_DATA_DIRECTORY& dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (dir.VirtualAddress == 0) return nullptr;

  for (auto* desc = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(base + dir.VirtualAddress); desc->Name != 0; desc++) {
    if (desc->OriginalFirstThunk == 0) continue;
    auto* names = reinterpret_cast<IMAGE_THUNK_DATA*>(base + desc->OriginalFirstThunk);
    auto* addresses = reinterpret_cast<IMAGE_THUNK_DATA*>(base + desc->FirstThunk);
    for (; names->u1.AddressOfData != 0; names++, addresses++) {
      if (IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal)) continue;
      auto* import = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(base + names->u1.AddressOfData);
      if (std::strcmp(reinterpret_cast<const char*>(import->Name), function) != 0) continue;

      DWORD old_protect;
      if (!VirtualProtect(&addresses->u1.Function, sizeof(addresses->u1.Function), PAGE_READWRITE, &old_protect)) {
        return nullptr;
      }
      void* original = reinterpret_cast<void*>(addresses->u1.Function);
      addresses->u1.Function = reinterpret_cast<ULONG_PTR>(replacement);
      VirtualProtect(&addresses->u1.Function, sizeof(addresses->u1.Function), old_protect, &old_protect);
      return original;
    }
  }
  return nullptr;
}

}  // namespace

void EnableEngineD3D11MultithreadProtection() {
  const HMODULE engine = GetModuleHandleW(L"flutter_windows.dll");
  if (engine == nullptr || real_get_proc_address != nullptr) return;
  real_get_proc_address = reinterpret_cast<decltype(&::GetProcAddress)>(
      PatchImport(engine, "GetProcAddress", reinterpret_cast<void*>(&GetProcAddressHook)));
}
