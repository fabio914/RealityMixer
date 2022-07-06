//
//  CameraTestScreen.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 05/07/2022.
//

import SwiftUI

protocol CameraTestViewModelProtocol: ObservableObject {
    var state: CameraTestState { get }
    func onAppear()
    func navigateBack()
}

struct CameraTestScreen<ViewModel: CameraTestViewModelProtocol>: View {
    @StateObject var viewModel: ViewModel

    @ViewBuilder var content: some View {
        switch viewModel.state {
        case .notAuthorized:
            Text("Reality Mixer is no longer authorized to access your camera.")
        case .error:
            Text("Reality Mixer was not able to access your camera.")
        case .ready(let image):
            if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height,
                            alignment: .center
                        )
                        .clipped()
                }
            } else {
                Color.black
            }
        case .loading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            content
            Button(action: viewModel.navigateBack) {
                Text("Go back")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: viewModel.onAppear)
    }
}
