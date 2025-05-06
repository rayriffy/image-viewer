import SwiftUI

#if os(iOS)
struct ImageDetailView: View {
    let imageUrl: URL
    let allImageUrls: [URL]
    let initialIndex: Int
    
    @State private var currentIndex: Int
    @State private var image: Image?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @StateObject private var resourceManager = SecurityScopedResourceManager.shared
    private let imageLoader = ImageLoader()
    
    init(imageUrl: URL, allImageUrls: [URL] = [], initialIndex: Int = 0) {
        self.imageUrl = imageUrl
        self.allImageUrls = allImageUrls
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
        
        print("🖼️ Opening detail view for image \(initialIndex+1)/\(allImageUrls.count): \(imageUrl.lastPathComponent)")
    }
    
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
                
                // Navigation controls overlay
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            navigateToPrevious()
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(currentIndex <= 0)
                        .opacity(currentIndex <= 0 ? 0.3 : 1)
                        
                        Spacer()
                        
                        Text("\(currentIndex + 1) / \(allImageUrls.count)")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
                        
                        Spacer()
                        
                        Button(action: {
                            navigateToNext()
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(currentIndex >= allImageUrls.count - 1)
                        .opacity(currentIndex >= allImageUrls.count - 1 ? 0.3 : 1)
                    }
                    .padding()
                }
            }
            .navigationTitle(allImageUrls[currentIndex].lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(allImageUrls[currentIndex].lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            // Jump back 10 images
                            jumpToImage(offset: -10)
                        }) {
                            Image(systemName: "backward.end.fill")
                                .imageScale(.large)
                        }
                        .disabled(currentIndex < 10)
                        
                        Button(action: {
                            // Jump forward 10 images
                            jumpToImage(offset: 10)
                        }) {
                            Image(systemName: "forward.end.fill")
                                .imageScale(.large)
                        }
                        .disabled(currentIndex >= allImageUrls.count - 10)
                    }
                }
            }
        }
        .task {
            // Initial preloading around the current image
            print("🏁 Starting initial preload for detail view at index \(currentIndex)")
            await ImagePreloader.shared.preloadImagesAround(index: currentIndex)
            await loadCurrentImage()
        }
    }
    
    private func loadCurrentImage() async {
        resetZoomAndOffset()
        isLoading = true
        
        print("🔄 Loading image at index \(currentIndex): \(allImageUrls[currentIndex].lastPathComponent)")
        
        // Check if image is in cache first
        if let loadedImage = await imageLoader.loadImage(from: allImageUrls[currentIndex]) {
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
                print("✅ Image loaded successfully at index \(currentIndex)")
            }
        } else {
            await MainActor.run {
                self.isLoading = false
                print("❌ Failed to load image at index \(currentIndex)")
            }
        }
    }
    
    private func navigateToPrevious() {
        guard currentIndex > 0 else { return }
        
        let previousIndex = currentIndex - 1
        print("⬅️ Navigating from \(currentIndex) to previous: \(previousIndex)")
        
        currentIndex = previousIndex
        
        Task {
            await ImagePreloader.shared.preloadImagesAround(index: currentIndex)
            await loadCurrentImage()
        }
    }
    
    private func navigateToNext() {
        guard currentIndex < allImageUrls.count - 1 else { return }
        
        let nextIndex = currentIndex + 1
        print("➡️ Navigating from \(currentIndex) to next: \(nextIndex)")
        
        currentIndex = nextIndex
        
        Task {
            await ImagePreloader.shared.preloadImagesAround(index: currentIndex)
            await loadCurrentImage()
        }
    }
    
    private func jumpToImage(offset: Int) {
        let newIndex = max(0, min(allImageUrls.count - 1, currentIndex + offset))
        guard newIndex != currentIndex else { return }
        
        print("↔️ Jumping from \(currentIndex) to \(newIndex) (offset: \(offset))")
        
        currentIndex = newIndex
        
        Task {
            await ImagePreloader.shared.preloadImagesAround(index: currentIndex)
            await loadCurrentImage()
        }
    }
    
    private func resetZoomAndOffset() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    NavigationStack {
        // Mock preview with placeholder image
        ImageDetailView(imageUrl: URL(fileURLWithPath: "example.jpg"))
    }
}
#endif 