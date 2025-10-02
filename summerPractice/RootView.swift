//
//  RootView.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 02.10.2025.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Демонстрация управления жестами")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding()

                NavigationLink("Медиа-плеер 🎵", destination: MediaPlayerScreen())
                    .buttonStyle(.borderedProminent)

                NavigationLink("Галерея картинок 🖼", destination: GalleryScreen())
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Главный экран")
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
