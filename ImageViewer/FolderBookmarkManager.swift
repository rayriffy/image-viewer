import Foundation

/// A utility class to handle bookmarking folder URLs for persistent access
class FolderBookmarkManager {
    /// UserDefaults key for the bookmark data
    private static let bookmarkKey = "com.imageviewer.folderBookmark"
    
    /// Save a security-scoped bookmark for a folder URL
    static func saveBookmark(for url: URL) -> Bool {
        do {
            // Create a security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Save the bookmark data in UserDefaults
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            return true
        } catch {
            print("Failed to create bookmark: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Load a folder URL from a saved bookmark
    static func loadBookmarkedURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }
        
        do {
            var isStale = false
            // Use .withoutUI instead of .withSecurityScope for iOS compatibility
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // If the bookmark is stale, try to save a new one
                _ = saveBookmark(for: url)
            }
            
            return url
        } catch {
            print("Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear saved bookmark
    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
} 