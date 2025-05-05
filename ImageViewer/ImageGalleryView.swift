import SwiftUI

struct ImageGalleryView: View {
    let folderURL: URL
    @State private var images: [ImageItem] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading images...")
            } else if images.isEmpty {
                ContentUnavailableView(
                    "No Images Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("No supported image files (.png, .jpg, .jpeg, .webp) were found in this folder.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(images) { image in
                            VerticalImageItemView(image: image)
                        }
                    }
                }
            }
        }
        .navigationTitle("Images")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        isLoading = true
        defer { isLoading = false }
        
        // Make sure we can access the security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Failed to access the folder")
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        do {
            // List all files in the directory
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter only image files and sort them alphabetically
            let supportedImageExtensions = ["png", "jpg", "jpeg", "webp"]
            let imageFiles = fileURLs.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return supportedImageExtensions.contains(fileExtension)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            // Create image items from file URLs
            var loadedImages: [ImageItem] = []
            for (index, fileURL) in imageFiles.enumerated() {
                guard let imageData = try? Data(contentsOf: fileURL),
                      let uiImage = UIImage(data: imageData) else {
                    continue
                }
                
                loadedImages.append(ImageItem(
                    id: index,
                    url: fileURL,
                    image: Image(uiImage: uiImage)
                ))
            }
            
            await MainActor.run {
                self.images = loadedImages
            }
            
        } catch {
            print("Error loading images: \(error.localizedDescription)")
        }
    }
}

struct ImageItem: Identifiable {
    let id: Int
    let url: URL
    let image: Image
}

// New vertical full-width image view
struct VerticalImageItemView: View {
    let image: ImageItem
    
    var body: some View {
        VStack(spacing: 2) {
            Text(image.url.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            image.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        // Mock preview with empty URL
        ImageGalleryView(folderURL: URL(fileURLWithPath: "/tmp"))
    }
} 