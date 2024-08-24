//
//  iboopersApp.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/4/24.
//

import SwiftUI

@main
struct iboopersApp: App {
    @State private var modelData = ModelData()
    var body: some Scene {
        WindowGroup {
            ContentView().environment(modelData)
        }
    }
}
