import AVFoundation
import MediaPlayer
import Combine

/// iPhone 端與 CarPlay 端共用的播放核心，包裝一個 AVPlayer，
/// 並把狀態同步到 Now Playing / 遠端控制中心，讓 CarPlay 的控制項可以運作。
@MainActor
final class PlaybackController: ObservableObject {
    static let shared = PlaybackController()

    let player = AVPlayer()

    @Published private(set) var currentItem: VideoItem?
    @Published private(set) var isPlaying = false

    private init() {
        configureRemoteCommandCenter()
    }

    func play(_ item: VideoItem) {
        currentItem = item
        player.replaceCurrentItem(with: AVPlayerItem(url: item.playbackURL))
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard currentItem != nil else { return }
        player.play()
        isPlaying = true
    }

    private func configureRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        // MPRemoteCommand 的 handler 保證在主執行緒呼叫，但型別是 @Sendable，
        // 編譯器無法單靠型別系統證明，所以一樣用 MainActor.assumeIsolated 橋接。
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let currentItem else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentItem.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        if let duration = player.currentItem?.asset.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
