import Foundation
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
        // Limit the number of cached images to prevent memory issues
        cache.countLimit = 50
        
        // Set a reasonable memory limit (50MB)
        cache.totalCostLimit = 50 * 1024 * 1024
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