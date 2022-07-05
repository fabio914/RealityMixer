//
//  ContentView.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 05/07/2022.
//

import SwiftUI
import RealityMixerKit

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button(action: { Test().test() }, label: { Text("Hello") })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
