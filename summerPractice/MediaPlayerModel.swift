//
//  MediaPlayerModel.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 02.10.2025.
//

import Foundation
import AVFAudio

final class MediaPlayerModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTrack: Int = 0
    let tracks = ["track1", "track2", "track3"] // Имена файлов в проекте
    private var player: AVAudioPlayer?

    func playPause() {
        if let player = player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
        } else {
            playCurrentTrack()
        }
    }

    func nextTrack() {
        currentTrack = (currentTrack + 1) % tracks.count
        playCurrentTrack()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func likeTrack() {
        print("👍 Лайк трека: \(tracks[currentTrack])")
    }

    private func playCurrentTrack() {
        guard let url = Bundle.main.url(forResource: tracks[currentTrack], withExtension: "mp3") else {
            print("Файл не найден: \(tracks[currentTrack]).mp3")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
        } catch {
            print("Ошибка воспроизведения трека: \(error)")
        }
    }
}
