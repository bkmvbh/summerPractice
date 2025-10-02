//
//  GalleryScreen.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 02.10.2025.
//

import SwiftUI

struct GalleryScreen: View {
    @StateObject private var cameraModel = CameraModel()
    @State private var currentIndex = 0
    private let images = ["photo1", "photo2", "photo3"] 

    var body: some View {
        ZStack {
            CameraPreview(session: cameraModel.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                if images.indices.contains(currentIndex) {
                    Image(images[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 400)
                        .cornerRadius(12)
                        .shadow(radius: 5)
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
                        VStack { Text("👆\nВыбрать").multilineTextAlignment(.center) }
                        VStack { Text("✌️\nСледующая").multilineTextAlignment(.center) }
                        VStack { Text("👊\nПредыдущая").multilineTextAlignment(.center) }
                        VStack { Text("🖐️\nЗакрыть").multilineTextAlignment(.center) }
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { cameraModel.startSession() }
        .onDisappear { cameraModel.stopSession() }
        .onChange(of: cameraModel.lastAction) { action in
            handleAction(action)
        }
    }

    private func handleAction(_ action: GestureAction?) {
        switch action {
        case .nextScreen, .like: // перелистываем вперед
            currentIndex = min(currentIndex + 1, images.count - 1)
        case .playPause, .select: // можно использовать для выбора
            print("Выбрана картинка \(currentIndex)")
        case .stop: // закрытие
            currentIndex = 0
        case .none:
            break
        }
    }
}
