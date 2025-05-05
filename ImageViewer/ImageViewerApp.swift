//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Created by Phumrapee Limpianchop on 2025/05/06.
//

import SwiftUI

@main
struct ImageViewerApp: App {
    @StateObject private var resourceManager = SecurityScopedResourceManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    // Clean up resources when app is closing
                    resourceManager.stopAccessingCurrentFolder()
                }
        }
    }
}
