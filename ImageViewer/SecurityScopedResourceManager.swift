import Foundation

/// A class to manage security-scoped resource access across views
class SecurityScopedResourceManager: ObservableObject {
    /// Singleton instance
    static let shared = SecurityScopedResourceManager()
    
    /// Currently accessed folder URL
    private(set) var currentFolderURL: URL?
    
    /// Flag indicating if the folder is currently being accessed
    private var isFolderAccessActive = false
    
    /// Initialize the manager
    private init() {}
    
    /// Set the current folder URL and start accessing it
    func setFolderURL(_ url: URL) -> Bool {
        // Stop accessing the previous folder if any
        stopAccessingCurrentFolder()
        
        // Start accessing the new folder
        if url.startAccessingSecurityScopedResource() {
            currentFolderURL = url
            isFolderAccessActive = true
            return true
        } else {
            print("Failed to access security-scoped resource at: \(url.path)")
            return false
        }
    }
    
    /// Stop accessing the current folder
    func stopAccessingCurrentFolder() {
        if let url = currentFolderURL, isFolderAccessActive {
            url.stopAccessingSecurityScopedResource()
            isFolderAccessActive = false
        }
    }
    
    /// Create a bookmark data for an image URL to maintain access across app sessions
    func createBookmarkData(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            print("Failed to create bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Resolve a bookmark data to get a URL with security-scoped access
    func resolveBookmark(_ bookmarkData: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            print("Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deinitializer to clean up resources
    deinit {
        stopAccessingCurrentFolder()
    }
} 