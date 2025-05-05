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
                                ProgressiveImageView(imageUrl: imageUrl)
                            }
                            .buttonStyle(PlainButtonStyle()) // Removes default navigation styling
                        }
                    }
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
                includingPropertiesForKeys: [.isRegularFileKey],
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

struct ProgressiveImageView: View {
    let imageUrl: URL
    @State private var image: Image? = nil
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 2) {
            Text(imageUrl.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            if let loadedImage = image {
                loadedImage
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        do {
            let imageData = try Data(contentsOf: imageUrl)
            if let uiImage = UIImage(data: imageData) {
                await MainActor.run {
                    self.image = Image(uiImage: uiImage)
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading image at \(imageUrl.lastPathComponent): \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        // Mock preview with empty URL
        ImageGalleryView(folderURL: URL(fileURLWithPath: "/tmp"))
    }
} 
