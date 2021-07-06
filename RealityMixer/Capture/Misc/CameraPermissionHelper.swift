//
//  CameraPermissionHelper.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 06/07/2021.
//

import UIKit
import AVFoundation

struct CameraPermissionHelper {

    // We could handle error `ARErrorCodeCameraUnauthorized` from the ARKit session instead.

    static func ensurePermission(
        from viewController: UIViewController,
        completion: @escaping () -> Void
    ) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak viewController] granted in
                DispatchQueue.main.async { [weak viewController] in
                    if granted {
                        completion()
                    } else if let viewController = viewController {
                        presentUnauthorizedAlert(from: viewController)
                    }
                }
            })
        default:
            presentUnauthorizedAlert(from: viewController)
        }
    }

    private static func presentUnauthorizedAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Error",
            message: "Reality Mixer is not authorized to use the camera.",
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "Open Settings", style: .default, handler: { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }))

        alert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
}
