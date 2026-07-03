import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var storageChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register background task identifiers
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.torrentflow.download",
      using: nil
    ) { task in
      self.handleBackgroundDownload(task: task as! BGProcessingTask)
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.torrentflow.refresh",
      using: nil
    ) { task in
      self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Setup Storage MethodChannel
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TorrentFlow") else { return }
    storageChannel = FlutterMethodChannel(
      name: "com.torrentflow.app/storage",
      binaryMessenger: registrar.messenger()
    )

    storageChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getStorageInfo":
        result(self?.getStorageInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Storage Info
  private func getStorageInfo() -> [String: Int64] {
    let fileManager = FileManager.default
    guard let path = NSSearchPathForDirectoriesInDomains(
      .documentDirectory, .userDomainMask, true
    ).first else {
      return ["freeSpace": 0, "totalSpace": 0]
    }

    do {
      let attributes = try fileManager.attributesOfFileSystem(forPath: path)
      let freeSpace = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
      let totalSpace = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
      return ["freeSpace": freeSpace, "totalSpace": totalSpace]
    } catch {
      return ["freeSpace": 0, "totalSpace": 0]
    }
  }

  // MARK: - Background Tasks
  private func handleBackgroundDownload(task: BGProcessingTask) {
    scheduleBackgroundDownload()
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }
    // Signal Flutter engine to continue downloads
    task.setTaskCompleted(success: true)
  }

  private func handleAppRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh()
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }
    task.setTaskCompleted(success: true)
  }

  private func scheduleBackgroundDownload() {
    let request = BGProcessingTaskRequest(identifier: "com.torrentflow.download")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  private func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.torrentflow.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }
}
