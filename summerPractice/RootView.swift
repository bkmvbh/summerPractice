import SwiftUI
import AVFoundation

enum Screen {
    case gallery
    case mediaPlayer
}

struct RootView: View {
    @State private var currentScreen: Screen = .gallery
    @ObservedObject var cameraModel: CameraModel
    @StateObject private var playerModel = MediaPlayerModel() // Модель медиаплеера

    init(cameraModel: CameraModel) {
        _cameraModel = ObservedObject(wrappedValue: cameraModel)
    }

    var body: some View {
        ZStack {
            // Основные экраны
            switch currentScreen {
            case .gallery:
                GalleryScreen(cameraModel: cameraModel)
            case .mediaPlayer:
                MediaPlayerScreen(cameraModel: cameraModel, playerModel: playerModel)
            }

            // Камера сверху
            CameraViewWrapper(cameraModel: cameraModel)
                .ignoresSafeArea()
        }
        .onReceive(cameraModel.$lastAction) { action in
            guard let action = action else { return }

            // Переключение экранов по ✌️
            if action == .nextScreen {
                toggleScreen()
            }

            // Управление медиаплеером только на экране MediaPlayer
            guard currentScreen == .mediaPlayer else { return }

            switch action {
            case .playPause: playerModel.playPause()  // 👊
            case .select: playerModel.nextTrack()     // 👆
            case .stop: playerModel.stop()            // 🖐️
            case .like: playerModel.likeTrack()       // 👍
            default: break
            }
        }
    }

    private func toggleScreen() {
        currentScreen = currentScreen == .gallery ? .mediaPlayer : .gallery
    }
}

// Обёртка для CameraView
struct CameraViewWrapper: View {
    @ObservedObject var cameraModel: CameraModel

    var body: some View {
        CameraView(model: cameraModel, showCloseButton: false)
    }
}
