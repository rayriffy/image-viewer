import SwiftUI

struct ImageGalleryView: View {
    let folderURL: URL
    @State private var imageUrls: [URL] = []
    @State private var isLoadingFileList = true
    @StateObject private var resourceManager = SecurityScopedResourceManager.shared
    
    var body: some View {
        Group {
            if isLoadingFileList {
                ProgressView("Finding images...")
            } else if imageUrls.isEmpty {
                ContentUnavailableView(
                    "No Images Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("No supported image files (.png, .jpg, .jpeg, .webp) were found in this folder.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(imageUrls, id: \.self) { imageUrl in
                            NavigationLink(destination: ImageDetailView(imageUrl: imageUrl)) {
                                OptimizedImageView(imageUrl: imageUrl)
                            }
                            .buttonStyle(PlainButtonStyle()) // Removes default navigation styling
                        }
                    }
                    // Disable scroll animations to prevent jumping
                    .scrollDisableAnimation()
                }
            }
        }
        .navigationTitle("Images")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadImageUrls()
        }
    }
    
    private func loadImageUrls() async {
        isLoadingFileList = true
        defer { isLoadingFileList = false }
        
        // We're using the shared resource manager now, so we don't need to start/stop access here
        
        do {
            // List all files in the directory
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter only image files and sort them alphabetically
            let supportedImageExtensions = ["png", "jpg", "jpeg", "webp"]
            let imageFiles = fileURLs.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return supportedImageExtensions.contains(fileExtension)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            await MainActor.run {
                self.imageUrls = imageFiles
            }
        } catch {
            print("Error loading image list: \(error.localizedDescription)")
        }
    }
}

/// An optimized image view that efficiently loads and displays images
struct OptimizedImageView: View {
    let imageUrl: URL
    @State private var image: Image?
    @State private var isLoading = true
    // Default aspect ratio for placeholders (3:2 is a common photograph ratio)
    @State private var aspectRatio: CGFloat = 1.5
    private let imageLoader = ImageLoader()
    
    var body: some View {
        VStack(spacing: 2) {
            Text(imageUrl.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            // Use a container with fixed dimensions based on screen width
            GeometryReader { geometry in
                ZStack {
                    if let loadedImage = image {
                        loadedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.width / aspectRatio
                )
            }
            .frame(height: UIScreen.main.bounds.width / aspectRatio)
            // This fixes the GeometryReader expanding issue
        }
        .task {
            await loadImageOptimized()
        }
    }
    
    private func loadImageOptimized() async {
        isLoading = true
        
        // Use our actor to load the image on a background thread
        if let loadedImage = await imageLoader.loadImage(from: imageUrl) {
            // Also get the aspect ratio from the cache if possible
            if let cachedImage = ImageCache.shared.getImage(for: imageUrl) {
                let imageAspect = cachedImage.size.width / cachedImage.size.height
                
                // Update the UI on the main thread
                await MainActor.run {
                    self.aspectRatio = imageAspect
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// ViewModifier to disable scroll animation
struct DisableScrollAnimation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollDisabled(false)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

// Extension to add the modifier as a convenient method
extension View {
    func scrollDisableAnimation() -> some View {
        self.modifier(DisableScrollAnimation())
    }
}

#Preview {
    NavigationStack {
        // Mock preview with empty URL
        ImageGalleryView(folderURL: URL(fileURLWithPath: "/tmp"))
    }
} 
