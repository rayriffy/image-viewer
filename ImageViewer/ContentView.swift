//
//  ContentView.swift
//  ImageViewer
//
//  Created by Phumrapee Limpianchop on 2025/05/06.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isShowingFolderPicker = false
    @State private var selectedFolderURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                if let folderURL = selectedFolderURL {
                    NavigationLink(destination: ImageGalleryView(folderURL: folderURL)) {
                        Label("View Images", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    Text("Selected folder: \(folderURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        
                    Button("Change Folder") {
                        isShowingFolderPicker = true
                    }
                    .padding(.top, 8)
                } else {
                    Image(systemName: "folder.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.bottom, 20)
                    
                    Text("Select a folder to view images")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 30)
                    
                    Button(action: {
                        isShowingFolderPicker = true
                    }) {
                        Label("Select Folder", systemImage: "folder.badge.plus")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Image Viewer")
            .fileImporter(
                isPresented: $isShowingFolderPicker,
                allowedContentTypes: [.folder],
                onCompletion: { result in
                    switch result {
                    case .success(let url):
                        // Start accessing the URL
                        if url.startAccessingSecurityScopedResource() {
                            selectedFolderURL = url
                            
                            // Save bookmark for future access
                            if FolderBookmarkManager.saveBookmark(for: url) {
                                print("Successfully saved bookmark")
                            }
                            
                            // Don't stop accessing here as we'll need it later
                            // Let the ImageGalleryView handle access
                        }
                    case .failure(let error):
                        print("Error selecting folder: \(error.localizedDescription)")
                    }
                }
            )
            .onAppear {
                // Try to load previously selected folder
                if selectedFolderURL == nil, let bookmarkedURL = FolderBookmarkManager.loadBookmarkedURL() {
                    selectedFolderURL = bookmarkedURL
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
