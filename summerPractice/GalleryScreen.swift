import SwiftUI

struct GalleryScreen: View {
    @ObservedObject var cameraModel: CameraModel
    @State private var currentIndex = 0
    private let images = ["photo1","photo2","photo3","photo4","photo5","photo6","photo7","photo8","photo9","photo10"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if images.indices.contains(currentIndex) {
                Image(images[currentIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 400)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }

            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Text("Жест: \(cameraModel.gesture)")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 50)
            }
        }
        .onReceive(cameraModel.$lastAction) { action in
            guard let action = action else { return }
            switch action {
            case .select: currentIndex = min(currentIndex + 1, images.count - 1)   // 👆 следующий фото
            case .playPause: currentIndex = max(currentIndex - 1, 0)               // 👊 предыдущий фото
            case .stop: currentIndex = 0                                           // 🖐️ сброс
            case .like: print("👍 Лайк фото \(currentIndex + 1)")                  // 👍 лайк
            default: break
            }
        }
    }
}
