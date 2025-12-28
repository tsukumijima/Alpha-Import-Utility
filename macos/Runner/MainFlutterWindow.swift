import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupFileTimeChannel(flutterViewController)

    super.awakeFromNib()
  }

  /// 起動時の一瞬表示を抑止し、Dart 側の show まで非表示に保つ
  override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  /// ファイル日時操作の MethodChannel を初期化する
  private func setupFileTimeChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "alpha_import_utility/file_time",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "Window not available.", details: nil))
        return
      }

      switch call.method {
      case "setFileTimes":
        self.handleSetFileTimes(call: call, result: result)
      case "getFileTimes":
        self.handleGetFileTimes(call: call, result: result)
      case "getAvailableDiskSpace":
        self.handleGetAvailableDiskSpace(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// ファイルの作成日時・更新日時を設定する
  private func handleSetFileTimes(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let creationMs = args["creationTimeUtcMs"] as? Int64,
          let modifiedMs = args["modifiedTimeUtcMs"] as? Int64 else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments.", details: nil))
      return
    }

    var url = URL(fileURLWithPath: path)
    let creationDate = Date(timeIntervalSince1970: TimeInterval(creationMs) / 1000)
    let modifiedDate = Date(timeIntervalSince1970: TimeInterval(modifiedMs) / 1000)

    do {
      var values = URLResourceValues()
      values.creationDate = creationDate
      values.contentModificationDate = modifiedDate
      try url.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "SET_FAILED", message: "Failed to set file times.", details: "\(error)"))
    }
  }

  /// ファイルの作成日時・更新日時を取得する
  private func handleGetFileTimes(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments.", details: nil))
      return
    }

    let url = URL(fileURLWithPath: path)
    do {
      let values = try url.resourceValues(forKeys: [
        .creationDateKey,
        .contentModificationDateKey,
      ])

      guard let creationDate = values.creationDate,
            let modifiedDate = values.contentModificationDate else {
        result(FlutterError(code: "READ_FAILED", message: "Failed to read file times.", details: nil))
        return
      }

      let creationMs = Int64(creationDate.timeIntervalSince1970 * 1000)
      let modifiedMs = Int64(modifiedDate.timeIntervalSince1970 * 1000)

      result([
        "creationTimeUtcMs": creationMs,
        "modifiedTimeUtcMs": modifiedMs,
      ])
    } catch {
      result(FlutterError(code: "READ_FAILED", message: "Failed to read file times.", details: "\(error)"))
    }
  }

  /// ディスクの空き容量を取得する
  private func handleGetAvailableDiskSpace(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments.", details: nil))
      return
    }

    do {
      let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
      if let freeSize = attributes[.systemFreeSize] as? NSNumber {
        result(freeSize.int64Value)
      } else {
        result(nil)
      }
    } catch {
      result(FlutterError(code: "READ_FAILED", message: "Failed to read disk space.", details: "\(error)"))
    }
  }
}
