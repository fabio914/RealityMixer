//
//  AppDelegate.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import AVFoundation

struct Style {
    static let navigationBarBackgroundColor = UIColor(white: 0.1, alpha: 1.0)
    static let navigationBarButtonColor = UIColor.white

    static let segmentedControlSelectedTextColor = UIColor.white
    static let segmentedControlNormalTextColor = UIColor.lightGray
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let titleTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.white
        ]

        let largeTitleTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .regular),
            .foregroundColor: UIColor.white
        ]

        let standard = UINavigationBarAppearance()
        standard.titleTextAttributes = titleTextAttributes
        standard.largeTitleTextAttributes = largeTitleTextAttributes
        standard.shadowColor = Style.navigationBarBackgroundColor
        standard.backgroundColor = Style.navigationBarBackgroundColor

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().tintColor = Style.navigationBarButtonColor
        UINavigationBar.appearance().isTranslucent = true

        UISegmentedControl.appearance().setTitleTextAttributes(
            [ .foregroundColor: Style.segmentedControlSelectedTextColor ],
            for: .selected
        )

        UISegmentedControl.appearance().setTitleTextAttributes(
            [ .foregroundColor: Style.segmentedControlNormalTextColor ],
            for: .normal
        )

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [ .mixWithOthers ])

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.rootViewController = UINavigationController(rootViewController: InitialViewController())
        window.makeKeyAndVisible()
        return true
    }
}
