import Foundation
#if os(iOS)
import UIKit
import SwiftUI

/// A class to manage image caching to improve scrolling performance
class ImageCache {
    /// Singleton instance
    static let shared = ImageCache()
    
    /// NSCache for storing loaded images
    private let cache = NSCache<NSString, UIImage>()
    
    /// Initialize the cache with default settings
    private init() {
        // Increased cache limit to handle larger preloading window
        cache.countLimit = 100
        
        // Increased memory limit to 100MB to accommodate more images
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    /// Get an image from the cache if available
    func getImage(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        return cache.object(forKey: key)
    }
    
    /// Store an image in the cache
    func setImage(_ image: UIImage, for url: URL) {
        let key = url.absoluteString as NSString
        
        // Estimate the cost based on image size
        let bytesPerPixel = 4
        let pixelCount = Int(image.size.width * image.size.height)
        let cost = pixelCount * bytesPerPixel
        
        cache.setObject(image, forKey: key, cost: cost)
    }
    
    /// Clear the entire cache
    func clearCache() {
        print("🗑️ Image cache completely cleared")
        cache.removeAllObjects()
    }
}

/// An actor to handle loading images on background threads
actor ImageLoader {
    private let cache = ImageCache.shared
    
    /// Load an image from a URL
    func loadImage(from url: URL) async -> Image? {
        // First, check if image is already in cache
        if let cachedImage = cache.getImage(for: url) {
            return Image(uiImage: cachedImage)
        }
        
        // If not in cache, load it
        do {
            let imageData = try Data(contentsOf: url)
            
            guard let uiImage = UIImage(data: imageData) else {
                return nil
            }
            
            // Process the image to make it more efficient for display
            let processedImage = await processImage(uiImage)
            
            // Cache the processed image
            cache.setImage(processedImage, for: url)
            
            return Image(uiImage: processedImage)
        } catch {
            print("Error loading image from \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Process an image to optimize memory usage
    private func processImage(_ image: UIImage) async -> UIImage {
        // For very large images, downscale to a reasonable size
        let maxDimension: CGFloat = 2000 // Maximum width or height in points
        
        let imageSize = image.size
        
        if imageSize.width <= maxDimension && imageSize.height <= maxDimension {
            // Image is already within reasonable limits
            return image
        }
        
        // Calculate the scaling factor
        let widthScale = maxDimension / imageSize.width
        let heightScale = maxDimension / imageSize.height
        let scale = min(widthScale, heightScale)
        
        let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        // Resize the image on a background thread
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use points, not pixels
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// A class to manage image preloading for faster scrolling and navigation
actor ImagePreloader {
    // Singleton instance
    static let shared = ImagePreloader()
    
    // The image loader used for loading images
    private let imageLoader = ImageLoader()
    
    // Current preloading task
    private var preloadingTask: Task<Void, Never>?
    
    // Current position in the queue
    private var currentIndex: Int = 0
    
    // Number of images to preload ahead
    private let preloadAheadCount = 20
    
    // Number of images to keep behind
    private let preloadBehindCount = 5
    
    // Status of preloading
    private var isPreloading = false
    
    // The array of image URLs to preload
    private var imageUrls: [URL] = []
    
    // Currently queued image indices
    private var queuedIndices: Set<Int> = []
    
    // Timestamp tracking for rapid scrolling detection
    private var lastIndexChangeTime = Date()
    private var recentIndexChanges: [(index: Int, timestamp: Date)] = []
    private let maxRecentChangesToTrack = 10
    private var consecutiveRapidScrolls = 0
    
    /// Set the array of image URLs to preload
    func setImageUrls(_ urls: [URL]) {
        self.imageUrls = urls
        print("📸 Image preloader initialized with \(urls.count) images")
    }
    
    /// Start preloading images from a specific index
    func preloadImagesAround(index: Int) async {
        // Cancel any ongoing preloading
        preloadingTask?.cancel()
        
        // Check if the new index is significantly far from the current one
        let jumpThreshold = preloadAheadCount + preloadBehindCount
        let isLargeJump = abs(index - currentIndex) > jumpThreshold
        let oldIndex = currentIndex
        
        // Track timing for rapid scrolling detection
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastIndexChangeTime)
        lastIndexChangeTime = now
        
        // Keep track of recent index changes
        recentIndexChanges.append((index: index, timestamp: now))
        if recentIndexChanges.count > maxRecentChangesToTrack {
            recentIndexChanges.removeFirst()
        }
        
        // Calculate scrolling velocity (changes per second)
        let isRapidScrolling = detectRapidScrolling()
        
        // Update current index
        currentIndex = index
        
        if isLargeJump {
            print("🔄 Large jump detected (from \(oldIndex) to \(index), threshold: \(jumpThreshold)) - Queue will be reset")
        }
        
        if isRapidScrolling {
            consecutiveRapidScrolls += 1
            print("⚡️ Rapid scrolling detected! Speed: \(calculateScrollingSpeed()) indices/sec, consecutive: \(consecutiveRapidScrolls)")
            
            if consecutiveRapidScrolls >= 5 {
                print("🔄 Queue reset due to sustained rapid scrolling")
                // Clear cache when rapid scrolling is sustained
                queuedIndices.removeAll()
                ImageCache.shared.clearCache()
                consecutiveRapidScrolls = 0
            }
        } else {
            consecutiveRapidScrolls = max(0, consecutiveRapidScrolls - 1)
        }
        
        // Start a new preloading task
        preloadingTask = Task {
            // Mark that we're preloading
            isPreloading = true
            
            // Log the start of a new preloading cycle
            print("🚀 Starting preload cycle at index \(index) | Ahead: \(preloadAheadCount), Behind: \(preloadBehindCount)")
            
            // If it's a large jump, clear the cache to avoid wasting memory
            if isLargeJump {
                print("🧹 Clearing existing queue due to large jump")
                queuedIndices.removeAll()
                ImageCache.shared.clearCache()
            }
            
            // Calculate the range of indices to preload
            let startIndex = max(0, index - preloadBehindCount)
            let endIndex = min(imageUrls.count - 1, index + preloadAheadCount)
            
            print("📊 Preload range: \(startIndex)...\(endIndex) | Total: \((endIndex - startIndex) + 1) images")
            
            // Load the current image first (high priority)
            if index >= 0 && index < imageUrls.count {
                _ = await imageLoader.loadImage(from: imageUrls[index])
                queuedIndices.insert(index)
                print("📥 Loaded current image at index \(index)")
            }
            
            // If rapid scrolling is happening, prioritize loading visible images only
            if isRapidScrolling && consecutiveRapidScrolls >= 3 {
                print("🏎️ Fast scroll mode: loading only visible images")
                isPreloading = false
                return
            }
            
            // Load images ahead
            for i in index + 1...endIndex {
                // Check if the task was cancelled
                if Task.isCancelled {
                    print("⛔ Preloading ahead cancelled at index \(i)")
                    break
                }
                
                if i < imageUrls.count {
                    _ = await imageLoader.loadImage(from: imageUrls[i])
                    queuedIndices.insert(i)
                    print("📥 Added to queue: image at index \(i) | Direction: ahead | Queue size: \(queuedIndices.count)")
                }
            }
            
            // Load images behind
            for i in stride(from: index - 1, through: startIndex, by: -1) {
                // Check if the task was cancelled
                if Task.isCancelled {
                    print("⛔ Preloading behind cancelled at index \(i)")
                    break
                }
                
                if i >= 0 {
                    _ = await imageLoader.loadImage(from: imageUrls[i])
                    queuedIndices.insert(i)
                    print("📥 Added to queue: image at index \(i) | Direction: behind | Queue size: \(queuedIndices.count)")
                }
            }
            
            isPreloading = false
            print("✅ Preload cycle completed | Final queue size: \(queuedIndices.count)")
        }
    }
    
    /// Detect rapid scrolling based on recent index changes
    private func detectRapidScrolling() -> Bool {
        guard recentIndexChanges.count >= 3 else { return false }
        
        let speed = calculateScrollingSpeed()
        // Consider it rapid scrolling if the speed is more than 10 indices per second
        return speed > 10.0
    }
    
    /// Calculate the scrolling speed in indices per second
    private func calculateScrollingSpeed() -> Double {
        guard recentIndexChanges.count >= 2 else { return 0.0 }
        
        let newest = recentIndexChanges.last!
        let oldest = recentIndexChanges.first!
        
        let timeInterval = newest.timestamp.timeIntervalSince(oldest.timestamp)
        guard timeInterval > 0.001 else { return 0.0 } // Avoid division by very small numbers
        
        let indexDelta = abs(newest.index - oldest.index)
        return Double(indexDelta) / timeInterval
    }
    
    /// Get the current image index
    func getCurrentIndex() -> Int {
        return currentIndex
    }
    
    /// Cancel all preloading
    func cancelPreloading() {
        preloadingTask?.cancel()
        isPreloading = false
        print("🛑 Preloading cancelled | Current queue size: \(queuedIndices.count)")
    }
    
    /// Remove an image from the queue
    func removeFromQueue(index: Int) {
        if queuedIndices.contains(index) {
            queuedIndices.remove(index)
            print("📤 Removed from queue: image at index \(index) | New queue size: \(queuedIndices.count)")
        }
    }
}
#endif 