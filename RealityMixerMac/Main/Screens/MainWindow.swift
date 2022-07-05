//
//  MainWindow.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 05/07/2022.
//

import SwiftUI
import AVFoundation

struct MainWindow: View {

    @State var cameraSelection: AVCaptureDevice?

    @ViewBuilder var content: some View {
        if case .none = cameraSelection {
            CameraSelectionScreen(
                viewModel: CameraSelectionViewModel(
                    cameraSelection: $cameraSelection
                )
            )
        } else {
            MainNavigation(cameraSelection: $cameraSelection)
        }
    }

    var body: some View {
        content
            .frame(minWidth: 600, minHeight: 400)
    }
}

struct MainNavigation: View {
    @Binding var cameraSelection: AVCaptureDevice?

    @ViewBuilder var content: some View {
        VStack(spacing: 20) {
            Text("Camera: \(cameraSelection?.localizedName ?? "")")

            Button(action: { }) {
                Text("Start Calibration")
            }

            Button(action: { }) {
                Text("Start Mixed Reality")
            }

            Button(action: { }) {
                Text("About")
            }

            Button(action: {  }) {
                Text("Test Camera")
            }

            Button(action: { cameraSelection = nil }) {
                Text("Change Camera")
            }
        }
    }

    var body: some View {
        content
    }
}
