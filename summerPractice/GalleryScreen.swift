import SwiftUI

struct GalleryScreen: View {
    @ObservedObject var cameraModel: CameraModel
    @State private var currentIndex = 0
    private let images = ["photo1", "photo2", "photo3"] // Добавь свои фото в Assets

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Черный фон под камерой

            VStack {
                Spacer()

                if images.indices.contains(currentIndex) {
                    Image(images[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 400)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding()
                }

                VStack(spacing: 15) {
                    Text("Ваш жест: \(cameraModel.gesture)")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    Text("Действие: \(cameraModel.lastAction?.rawValue ?? "-")")
                        .font(.title2)
                        .foregroundColor(.yellow)

                    HStack(spacing: 15) {
                        VStack { Text("✌️\nСледующая").multilineTextAlignment(.center) }
                        VStack { Text("👊\nПредыдущая").multilineTextAlignment(.center) }
                        VStack { Text("👆\nВыбрать").multilineTextAlignment(.center) }
                        VStack { Text("👍\nПерейти в Музыку").multilineTextAlignment(.center) }
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.bottom, 50)
            }
        }
        .onChange(of: cameraModel.lastAction) { action in
            handleAction(action)
        }
    }

    private func handleAction(_ action: GestureAction?) {
        switch action {
        case .like, .nextScreen: // Следующая фотография
            currentIndex = min(currentIndex + 1, images.count - 1)
        case .playPause: // Предыдущая фотография
            currentIndex = max(currentIndex - 1, 0)
        case .select: // Выбрать текущую
            print("Выбрана картинка \(currentIndex)")
        case .stop: // Сброс
            currentIndex = 0
        case .none:
            break
        }
    }
}
