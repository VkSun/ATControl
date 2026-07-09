#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Имя мьютекса, используемого только для того, чтобы определить, что
// другой экземпляр ATControl уже запущен в этом сеансе пользователя.
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\ATControl_SingleInstanceMutex_8F1E6D2A9B4C4F1E";

// Класс и заголовок совпадают с тем, что передаётся в window.Create() ниже
// (см. win32_window.cpp: CreateWindow получает ровно этот title).
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"atcontrol";

// Разворачивает и выводит на передний план уже запущенный экземпляр.
void ActivateExistingInstance() {
  HWND existing = ::FindWindowW(kWindowClassName, kWindowTitle);
  if (existing == nullptr) {
    return;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  } else {
    ::ShowWindow(existing, SW_SHOW);
  }
  ::SetForegroundWindow(existing);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Один экземпляр приложения: если мьютекс уже существует — ATControl
  // уже запущен. Разворачиваем его окно и завершаемся, не создавая новое —
  // так второй запуск не плодит дублирующиеся окна/трей-иконки и не рискует
  // гонкой при записи офлайн-очереди на диск.
  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingInstance();
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
  if (!window.Create(L"atcontrol", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
