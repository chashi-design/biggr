//
//  TrainLogAppApp.swift
//  TrainLogApp
//
//  Created by Takanori Hirohashi on 2025/11/02.
//
import SwiftData
import SwiftUI

@main
struct TrainLogApp: App {
    @StateObject private var containerProvider = ModelContainerProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(containerProvider)
        }
        .modelContainer(containerProvider.container)
    }
}
