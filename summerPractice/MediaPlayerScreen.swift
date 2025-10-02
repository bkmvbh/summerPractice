import SwiftUI

struct MediaPlayerScreen: View {
    @ObservedObject var cameraModel: CameraModel
    @ObservedObject var playerModel: MediaPlayerModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 15) {
                    Text("Ваш жест: \(cameraModel.gesture)")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    // Показываем действие последнего жеста
                    Text("Действие: \(cameraModel.lastAction?.rawValue ?? "-")")
                        .font(.title2)
                        .foregroundColor(.yellow)

                    // Текущий трек
                    Text("Текущий трек: \(playerModel.tracks[playerModel.currentTrack])")
                        .font(.title)
                        .foregroundColor(.white)

                    // Статус Play/Pause
                    Text(playerModel.isPlaying ? "▶️ Воспроизведение" : "⏸️ Пауза")
                        .font(.title2)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)

                    // Подсказка жестов
                    HStack(spacing: 20) {
                        VStack { Text("👊\nPlay/Pause").multilineTextAlignment(.center) }
                        VStack { Text("👆\nСледующий трек").multilineTextAlignment(.center) }
                        VStack { Text("🖐️\nСтоп").multilineTextAlignment(.center) }
                        VStack { Text("✌️\nСменить экран").multilineTextAlignment(.center) }
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.bottom, 50)
            }
        }
        .onReceive(playerModel.$isPlaying) { _ in
            
        }
    }
}
