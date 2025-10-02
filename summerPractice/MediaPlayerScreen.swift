//
//  MediaPlayerScreen.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 02.10.2025.
//
import SwiftUI

struct MediaPlayerScreen: View {
    @StateObject private var cameraModel = CameraModel()

    var body: some View {
        ZStack {
            CameraPreview(session: cameraModel.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
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

                    HStack(spacing: 20) {
                        VStack {
                            Text("👊\nПлей/Пауза").multilineTextAlignment(.center)
                        }
                        VStack {
                            Text("✌️\nСледующий трек").multilineTextAlignment(.center)
                        }
                        VStack {
                            Text("👍\nЛайк").multilineTextAlignment(.center)
                        }
                        VStack {
                            Text("🖐️\nСтоп").multilineTextAlignment(.center)
                        }
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
    }
}

