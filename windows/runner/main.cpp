#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwctype>
#include <filesystem>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
std::wstring GetExecutableBaseName() {
  wchar_t path_buffer[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, path_buffer, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L"app";
  }

  const std::filesystem::path executable_path(path_buffer);
  const std::wstring stem = executable_path.stem().wstring();
  return stem.empty() ? L"app" : stem;
}

std::wstring BuildSingleInstanceMutexName(const std::wstring& app_name) {
  std::wstring safe_name;
  safe_name.reserve(app_name.size());
  for (wchar_t ch : app_name) {
    safe_name.push_back(std::iswalnum(ch) ? ch : L'_');
  }

  if (safe_name.empty()) {
    safe_name = L"app";
  }

  return L"Local\\" + safe_name + L"_single_instance_guard";
}

std::wstring ResolveDisplayName(const std::wstring& executable_name) {
  if (executable_name == L"claix") {
    return L"Claix";
  }
  if (executable_name == L"ai_mclassing") {
    return L"AI MClassing";
  }
  return executable_name;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const std::wstring app_name = GetExecutableBaseName();
  const std::wstring display_name = ResolveDisplayName(app_name);
  const std::wstring single_instance_mutex_name =
      BuildSingleInstanceMutexName(app_name);
  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, single_instance_mutex_name.c_str());
  if (single_instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::MessageBoxW(nullptr, L"\uC571\uC774 \uC774\uBBF8 \uC2E4\uD589\uC911\uC785\uB2C8\uB2E4.",
                  display_name.c_str(), MB_OK | MB_ICONINFORMATION);
    ::CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(display_name, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(single_instance_mutex);
  ::CloseHandle(single_instance_mutex);
  return EXIT_SUCCESS;
}
