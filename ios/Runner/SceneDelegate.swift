import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private weak var protectedScene: UIWindowScene?
  private weak var observedCaptureWindow: UIWindow?
  private var privacyWindow: UIWindow?
  private var sceneIsActive = false

  override init() {
    super.init()

    let notifications = NotificationCenter.default
    for name in [
      UIScene.willConnectNotification,
      UIScene.didActivateNotification,
      UIScene.willDeactivateNotification,
      UIScene.willEnterForegroundNotification,
      UIScene.didEnterBackgroundNotification,
      UIScene.didDisconnectNotification,
    ] {
      notifications.addObserver(
        self,
        selector: #selector(sceneLifecycleDidChange(_:)),
        name: name,
        object: nil
      )
    }
    notifications.addObserver(
      self,
      selector: #selector(screenCaptureDidChange(_:)),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func sceneLifecycleDidChange(_ notification: Notification) {
    guard let scene = notification.object as? UIWindowScene,
      scene.delegate === self
    else {
      return
    }

    if notification.name == UIScene.didDisconnectNotification {
      privacyWindow?.isHidden = true
      privacyWindow = nil
      protectedScene = nil
      sceneIsActive = false
      return
    }

    protectedScene = scene
    sceneIsActive = notification.name == UIScene.didActivateNotification
    installCaptureProtection(for: scene)
    updateCaptureProtection()
  }

  @objc private func screenCaptureDidChange(_ notification: Notification) {
    updateCaptureProtection()
  }

  private func installCaptureProtection(for scene: UIWindowScene) {
    if privacyWindow == nil {
      let cover = UIWindow(windowScene: scene)
      cover.frame = scene.coordinateSpace.bounds
      cover.windowLevel = UIWindow.Level.alert + 1

      let controller = UIViewController()
      controller.view.backgroundColor = .black
      controller.view.isOpaque = true
      controller.view.accessibilityViewIsModal = true
      cover.rootViewController = controller
      privacyWindow = cover
    }

    if #available(iOS 17.0, *), let appWindow = window,
      observedCaptureWindow !== appWindow
    {
      observedCaptureWindow = appWindow
      appWindow.registerForTraitChanges([UITraitSceneCaptureState.self]) {
        [weak self] (_: UIWindow, _: UITraitCollection) in
        self?.updateCaptureProtection()
      }
    }
  }

  private func updateCaptureProtection() {
    guard let scene = protectedScene else { return }

    var isCaptured = scene.screen.isCaptured
    if #available(iOS 17.0, *),
      window?.traitCollection.sceneCaptureState == .active
    {
      isCaptured = true
    }

    // Keep Flutter's window/key-window ownership and lifecycle forwarding intact.
    // The opaque cover also hides content from inactive-scene snapshots.
    privacyWindow?.isHidden = sceneIsActive && !isCaptured
  }
}
