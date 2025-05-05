import SwiftUI

struct ImageDetailView: View {
    let image: ImageItem
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                image.image
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
            .navigationTitle(image.url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(image.url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        // Mock preview with placeholder image
        let uiImage = UIImage(systemName: "photo") ?? UIImage()
        let imageItem = ImageItem(
            id: 1,
            url: URL(fileURLWithPath: "example.jpg"),
            image: Image(uiImage: uiImage)
        )
        
        ImageDetailView(image: imageItem)
    }
} 