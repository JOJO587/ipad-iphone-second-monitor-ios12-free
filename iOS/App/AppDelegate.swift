// AppDelegate.swift
//
// Classic (pre-UIScene) app lifecycle on purpose: UIScene / SceneDelegate is
// iOS 13+, and there's no `UIApplicationSceneManifest` key in Info.plist, so
// UIKit falls back to this path automatically -- which also happens to keep
// working fine on modern iOS.

import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ReceiverViewController()
        window.backgroundColor = .black
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
