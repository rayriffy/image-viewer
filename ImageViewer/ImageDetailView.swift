import SwiftUI

struct ImageDetailView: View {
    let imageUrl: URL
    @State private var image: Image?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @StateObject private var resourceManager = SecurityScopedResourceManager.shared
    private let imageLoader = ImageLoader()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView("Loading image...")
                        .foregroundColor(.white)
                } else if let loadedImage = image {
                    loadedImage
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 5)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                    
                                    // Reset offset if scale is back to normal
                                    if scale <= 1 {
                                        withAnimation {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = min(3, 3)
                                }
                            }
                        }
                }
            }
            .navigationTitle(imageUrl.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(imageUrl.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .task {
            await loadImageOptimized()
        }
    }
    
    private func loadImageOptimized() async {
        isLoading = true
        
        // Check if image is in cache first
        if let loadedImage = await imageLoader.loadImage(from: imageUrl) {
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        // Mock preview with placeholder image
        ImageDetailView(imageUrl: URL(fileURLWithPath: "example.jpg"))
    }
} 