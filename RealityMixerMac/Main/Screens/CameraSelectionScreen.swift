//
//  CameraSelectionScreen.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 05/07/2022.
//

import SwiftUI

protocol CameraSelectionViewModelProtocol: ObservableObject {
    var state: CameraSelectionState { get }
    func onAppear()
    func select(_ camera: CameraOption)
    func openPrivacySettings()
}

struct CameraSelectionScreen<ViewModel: CameraSelectionViewModelProtocol>: View {
    @StateObject var viewModel: ViewModel

    @ViewBuilder var content: some View {
        switch viewModel.state {
        case .notAuthorized:
            VStack(spacing: 20) {
                Text("Reality Mixer is not authorized to access your camera.\nPlease update your privacy preferences.")
                    .multilineTextAlignment(.leading)
                Button(action: viewModel.openPrivacySettings) {
                    Text("Privacy Settings")
                }
            }
        case .options(let cameras):
            CameraPicker(cameras: cameras, onCameraSelection: viewModel.select)
        case .loading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: viewModel.onAppear)
    }
}

struct CameraPicker: View {
    let cameras: [CameraOption]
    let onCameraSelection: (CameraOption) -> Void
    @State var selectedCamera: CameraOption?

    var body: some View {
        VStack(spacing: 20) {
            Text("Please choose the camera you want to use:")
            Menu {
                ForEach(cameras) { camera in
                    Button(action: { selectedCamera = camera }) {
                        Text("\(camera.localizedName)")
                    }
                }
            } label: {
                if let selectedCamera = selectedCamera {
                    Text(selectedCamera.localizedName)
                } else if cameras.isEmpty {
                    Text("No cameras found...")
                } else {
                    Text("Cameras")
                }
            }
            Button(action: {
                guard let selection = selectedCamera else { return }
                onCameraSelection(selection)
            }) {
                Text("OK")
            }
            .disabled(selectedCamera == nil)
        }
    }
}

struct CameraSelectionScreen_Previews: PreviewProvider {
    final class FakeViewModel: CameraSelectionViewModelProtocol {
        let state: CameraSelectionState
        func onAppear() { }
        func select(_ camera: CameraOption) { }
        func openPrivacySettings() { }

        init(_ state: CameraSelectionState) {
            self.state = state
        }
    }

    static var previews: some View {
        CameraSelectionScreen(viewModel:
            FakeViewModel(.loading)
        )

        CameraSelectionScreen(viewModel:
            FakeViewModel(.notAuthorized)
        )

        CameraSelectionScreen(viewModel:
            FakeViewModel(
                .options([CameraOption(id: "1", localizedName: "Camera 1")])
            )
        )
    }
}
