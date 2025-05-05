# ImageViewer

A SwiftUI application that allows users to browse and view images from a selected folder.

## Features

- Select a folder using the folder picker
- View all images in the selected folder (supports PNG, JPG, JPEG, and WebP formats)
- Images are displayed in a grid layout, sorted alphabetically (A-Z)
- Tap an image to view it in full-screen mode
- Zoom and pan in the detail view
- Bookmark the selected folder for persistent access

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 14.0+
- Swift 5.7+

## Usage

1. Launch the app
2. Tap "Select Folder" to choose a directory containing images
3. Browse through the images in the grid
4. Tap any image to view it in full detail
5. In the detail view:
   - Double-tap to zoom in/out
   - Pinch to zoom
   - Drag to pan when zoomed in

## Implementation Details

The app uses:

- SwiftUI for the user interface
- The `fileImporter` API to select folders
- Security-scoped bookmarks for persistent access to selected folders
- Asynchronous loading of images to prevent UI blocking
- LazyVGrid for efficient grid layout

## Privacy

The app requires access to photo library for displaying images. It only accesses the folders that users explicitly select through the picker. 