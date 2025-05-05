//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Created by Phumrapee Limpianchop on 2025/05/06.
//

import SwiftUI

@main
struct ImageViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    // Ensure we clean up any security-scoped resources
                    if let bookmarkedURL = FolderBookmarkManager.loadBookmarkedURL() {
                        bookmarkedURL.stopAccessingSecurityScopedResource()
                    }
                }
        }
    }
}
