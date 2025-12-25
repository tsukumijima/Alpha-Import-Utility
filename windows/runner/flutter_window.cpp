#include "flutter_window.h"

#include <windows.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// UNIX エポック（1970-01-01）と FILETIME エポックの差（100ns 単位）
constexpr int64_t kEpochDiffIn100Ns = 116444736000000000LL;

/// UTF-8 を UTF-16 に変換する
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }

  const int size = MultiByteToWideChar(
      CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }

  std::wstring wide(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), wide.data(),
      size);
  return wide;
}

/// UNIX ミリ秒を FILETIME に変換する
FILETIME UnixMillisToFileTime(int64_t unix_ms) {
  const int64_t time_100ns = (unix_ms * 10000) + kEpochDiffIn100Ns;
  ULARGE_INTEGER value;
  value.QuadPart = static_cast<ULONGLONG>(time_100ns);
  FILETIME file_time;
  file_time.dwLowDateTime = value.LowPart;
  file_time.dwHighDateTime = value.HighPart;
  return file_time;
}

/// FILETIME を UNIX ミリ秒に変換する
int64_t FileTimeToUnixMillis(const FILETIME& file_time) {
  ULARGE_INTEGER value;
  value.LowPart = file_time.dwLowDateTime;
  value.HighPart = file_time.dwHighDateTime;
  const int64_t time_100ns = static_cast<int64_t>(value.QuadPart);
  return (time_100ns - kEpochDiffIn100Ns) / 10000;
}

/// ファイルの作成日時・更新日時を取得する
bool ReadFileTimes(const std::wstring& path,
                   int64_t* creation_ms,
                   int64_t* modified_ms,
                   std::string* error_message) {
  const HANDLE handle = CreateFileW(
      path.c_str(), FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);

  if (handle == INVALID_HANDLE_VALUE) {
    if (error_message != nullptr) {
      *error_message = "CreateFileW failed.";
    }
    return false;
  }

  FILETIME creation_time;
  FILETIME last_write_time;
  if (!GetFileTime(handle, &creation_time, nullptr, &last_write_time)) {
    if (error_message != nullptr) {
      *error_message = "GetFileTime failed.";
    }
    CloseHandle(handle);
    return false;
  }

  CloseHandle(handle);

  *creation_ms = FileTimeToUnixMillis(creation_time);
  *modified_ms = FileTimeToUnixMillis(last_write_time);
  return true;
}

/// ファイルの作成日時・更新日時を設定する
bool WriteFileTimes(const std::wstring& path,
                    int64_t creation_ms,
                    int64_t modified_ms,
                    std::string* error_message) {
  const HANDLE handle = CreateFileW(
      path.c_str(), FILE_WRITE_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);

  if (handle == INVALID_HANDLE_VALUE) {
    if (error_message != nullptr) {
      *error_message = "CreateFileW failed.";
    }
    return false;
  }

  const FILETIME creation_time = UnixMillisToFileTime(creation_ms);
  const FILETIME last_write_time = UnixMillisToFileTime(modified_ms);

  const BOOL success =
      SetFileTime(handle, &creation_time, nullptr, &last_write_time);
  CloseHandle(handle);

  if (!success) {
    if (error_message != nullptr) {
      *error_message = "SetFileTime failed.";
    }
    return false;
  }

  return true;
}

/// ディスクの空き容量を取得する
bool ReadDiskFreeSpace(const std::wstring& path, int64_t* free_bytes) {
  ULARGE_INTEGER free_available;
  ULARGE_INTEGER total_bytes;
  ULARGE_INTEGER total_free;

  if (!GetDiskFreeSpaceExW(path.c_str(), &free_available, &total_bytes,
                           &total_free)) {
    return false;
  }

  *free_bytes = static_cast<int64_t>(free_available.QuadPart);
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // ファイル日時操作の MethodChannel を登録する
  file_time_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "alpha_import_utility/file_time",
          &flutter::StandardMethodCodec::GetInstance());

  file_time_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setFileTimes") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("INVALID_ARGS", "Missing arguments.");
            return;
          }

          const auto path_it = args->find(flutter::EncodableValue("path"));
          const auto creation_it =
              args->find(flutter::EncodableValue("creationTimeUtcMs"));
          const auto modified_it =
              args->find(flutter::EncodableValue("modifiedTimeUtcMs"));

          if (path_it == args->end() || creation_it == args->end() ||
              modified_it == args->end()) {
            result->Error("INVALID_ARGS", "Missing required arguments.");
            return;
          }

          const auto* path_value =
              std::get_if<std::string>(&(path_it->second));
          const auto* creation_value =
              std::get_if<int64_t>(&(creation_it->second));
          const auto* modified_value =
              std::get_if<int64_t>(&(modified_it->second));

          if (path_value == nullptr || creation_value == nullptr ||
              modified_value == nullptr) {
            result->Error("INVALID_ARGS", "Invalid argument types.");
            return;
          }

          const std::wstring path = Utf8ToWide(*path_value);
          std::string error_message;
          if (!WriteFileTimes(path, *creation_value, *modified_value,
                              &error_message)) {
            result->Error("SET_FAILED", "Failed to set file times.",
                          error_message);
            return;
          }

          result->Success();
          return;
        }

        if (call.method_name() == "getFileTimes") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("INVALID_ARGS", "Missing arguments.");
            return;
          }

          const auto path_it = args->find(flutter::EncodableValue("path"));
          if (path_it == args->end()) {
            result->Error("INVALID_ARGS", "Missing path.");
            return;
          }

          const auto* path_value =
              std::get_if<std::string>(&(path_it->second));
          if (path_value == nullptr) {
            result->Error("INVALID_ARGS", "Invalid path.");
            return;
          }

          const std::wstring path = Utf8ToWide(*path_value);
          int64_t creation_ms = 0;
          int64_t modified_ms = 0;
          std::string error_message;
          if (!ReadFileTimes(path, &creation_ms, &modified_ms,
                             &error_message)) {
            result->Error("READ_FAILED", "Failed to read file times.",
                          error_message);
            return;
          }

          flutter::EncodableMap values;
          values[flutter::EncodableValue("creationTimeUtcMs")] =
              flutter::EncodableValue(creation_ms);
          values[flutter::EncodableValue("modifiedTimeUtcMs")] =
              flutter::EncodableValue(modified_ms);
          result->Success(flutter::EncodableValue(values));
          return;
        }

        if (call.method_name() == "getAvailableDiskSpace") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("INVALID_ARGS", "Missing arguments.");
            return;
          }

          const auto path_it = args->find(flutter::EncodableValue("path"));
          if (path_it == args->end()) {
            result->Error("INVALID_ARGS", "Missing path.");
            return;
          }

          const auto* path_value =
              std::get_if<std::string>(&(path_it->second));
          if (path_value == nullptr) {
            result->Error("INVALID_ARGS", "Invalid path.");
            return;
          }

          const std::wstring path = Utf8ToWide(*path_value);
          int64_t free_bytes = 0;
          if (!ReadDiskFreeSpace(path, &free_bytes)) {
            result->Error("READ_FAILED", "Failed to read disk space.");
            return;
          }

          result->Success(flutter::EncodableValue(free_bytes));
          return;
        }

        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
