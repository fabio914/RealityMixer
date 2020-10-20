//
//  AppDelegate.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        window.rootViewController = ConnectionViewController()
        window.makeKeyAndVisible()
        return true
    }
}

