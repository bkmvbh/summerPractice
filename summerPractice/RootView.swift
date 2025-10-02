import SwiftUI

enum Screen {
    case gallery
    case mediaPlayer
}

struct RootView: View {
    @State private var currentScreen: Screen = .gallery
    @ObservedObject var cameraModel: CameraModel

    init(cameraModel: CameraModel) {
        _cameraModel = ObservedObject(wrappedValue: cameraModel)
    }

    var body: some View {
        ZStack {
            switch currentScreen {
            case .gallery:
                GalleryScreen(cameraModel: cameraModel)
            case .mediaPlayer:
                MediaPlayerScreen(cameraModel: cameraModel)
            }

            CameraViewWrapper(cameraModel: cameraModel)
                .ignoresSafeArea()
        }
        .onReceive(cameraModel.$lastAction) { action in
            guard let action = action else { return }
            if action == .nextScreen {
                toggleScreen()
            }
        }
    }

    private func toggleScreen() {
        currentScreen = currentScreen == .gallery ? .mediaPlayer : .gallery
    }
}

struct CameraViewWrapper: View {
    @ObservedObject var cameraModel: CameraModel

    var body: some View {
        CameraView(model: cameraModel, showCloseButton: false)
    }
}
