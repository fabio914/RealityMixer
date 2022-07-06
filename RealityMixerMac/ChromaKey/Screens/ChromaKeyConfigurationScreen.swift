////
////  ChromaKeyConfigurationScreen.swift
////  RealityMixerMac
////
////  Created by Fabio Dela Antonio on 06/07/2022.
////
//
//import SwiftUI
//import SceneKit
//
//protocol ChromaKeyConfigurationViewModelProtocol: ObservableObject {
//    var state: ChromaKeyState { get }
//    func onAppear()
//    func navigateBack()
//}
//
//struct ChromaKeyConfigurationScreen<ViewModel: ChromaKeyConfigurationViewModelProtocol>: View {
//    @StateObject var viewModel: ViewModel
//
//    @ViewBuilder var content: some View {
//        switch viewModel.state {
//        case .notAuthorized:
//            Text("Reality Mixer is no longer authorized to access your camera.")
//        case .error:
//            Text("Reality Mixer was not able to access your camera.")
//        case .ready(let details):
//            SceneView(
//                scene: details.scene,
//                pointOfView: details.pointOfView,
//                options: [],
//                delegate: details.rendererDelegate.delegate
//            )
//        case .loading:
//            ProgressView()
//                .progressViewStyle(CircularProgressViewStyle())
//        }
//    }
//
//    var body: some View {
//        VStack(spacing: 20) {
//            content
//            Button(action: viewModel.navigateBack) {
//                Text("Go back")
//            }
//        }
//        .padding()
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .onAppear(perform: viewModel.onAppear)
//    }
//}
