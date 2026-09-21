import CarPlay
import AVFoundation
import CoreMedia

/// 把 CarPlay 螢幕上的瀏覽/選片行為，接到共用的 PlaybackController。
///
/// CarPlay 影片播放（iOS 26.4+）沒有獨立的「video scene」類別，而是掛在既有的
/// CPTemplateApplicationScene / CPListTemplate 架構上：CPListItem 透過新的
/// CPPlayableItem 協定，帶一個 CPPlaybackConfiguration（preferredPresentation
/// 為 .video / .audio / .none）。設成 .video 就代表這個項目要以影片畫面呈現，
/// 系統會依此在車機螢幕顯示播放介面；實際的解碼/輸出仍是我方的 AVPlayer。
@MainActor
final class CarPlayVideoCoordinator {
    private let interfaceController: CPInterfaceController
    private let videoSource: VideoSourceProviding
    private let playback: PlaybackController
    private let lockPolicy: DrivingLockPolicy

    private var timeObserverToken: Any?

    init(
        interfaceController: CPInterfaceController,
        videoSource: VideoSourceProviding,
        playback: PlaybackController,
        lockPolicy: DrivingLockPolicy
    ) {
        self.interfaceController = interfaceController
        self.videoSource = videoSource
        self.playback = playback
        self.lockPolicy = lockPolicy
    }

    func start() {
        Task { await presentLibrary() }
    }

    private func presentLibrary() async {
        let items = (try? await videoSource.fetchLibrary()) ?? []

        let listItems = items.map { item -> CPListItem in
            let listItem = CPListItem(text: item.title, detailText: nil)
            listItem.playbackConfiguration = makePlaybackConfiguration(action: .none, elapsedSeconds: 0, duration: .zero)
            listItem.handler = { [weak self] _, completion in
                // 同上：CarPlay 選取事件保證在主執行緒觸發，但編譯器看不出來，
                // 用 MainActor.assumeIsolated 橋接才能呼叫 select(...)。
                MainActor.assumeIsolated { self?.select(item, listItem: listItem) }
                completion()
            }
            return listItem
        }

        let section = CPListSection(items: listItems)
        let listTemplate = CPListTemplate(title: "影片庫", sections: [section])

        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
    }

    private func select(_ item: VideoItem, listItem: CPListItem) {
        // lockPolicy 決定的是「呈現方式」而不是要不要解碼：行駛中（.parkedOnly 且未停車）
        // 一樣播放同一個 AVPlayer，只是 preferredPresentation 降級成 .audio，
        // 車機就只顯示音訊介面，不顯示影像——這正是 Apple 對「僅停車可看影片」的做法。
        playback.play(item)
        observePlayback(listItem: listItem)
    }

    private func observePlayback(listItem: CPListItem) {
        if let token = timeObserverToken {
            playback.player.removeTimeObserver(token)
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = playback.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // addPeriodicTimeObserver 的 callback 是 @Sendable，編譯器沒辦法單靠型別
            // 系統證明它跑在 MainActor 上；但我們指定了 queue: .main，執行時保證一定
            // 在主執行緒，所以用 MainActor.assumeIsolated 明確橋接，才能在裡面呼叫會
            // 建立 @MainActor 型別 CPPlaybackConfiguration 的 makePlaybackConfiguration(...)。
            MainActor.assumeIsolated {
                guard let self else { return }
                // duration 先固定給 .zero（= 未知/不適用，見 CPPlaybackConfiguration
                // 文件），因為範例串流沒有可靠的時長中繼資料；要接真正的影片來源時，
                // 用 AVAsynchronousKeyValueLoading 的 `await asset.load(.duration)`
                // 取代這裡即可。
                listItem.playbackConfiguration = self.makePlaybackConfiguration(
                    action: self.playback.isPlaying ? .play : .pause,
                    elapsedSeconds: time.seconds,
                    duration: .zero
                )
                listItem.isPlaying = self.playback.isPlaying
            }
        }
    }

    private func makePlaybackConfiguration(
        action: CPPlaybackConfiguration.Action,
        elapsedSeconds: Double,
        duration: CMTime
    ) -> CPPlaybackConfiguration {
        CPPlaybackConfiguration(
            preferredPresentation: lockPolicy.canPlayVideo() ? .video : .audio,
            playbackAction: action,
            elapsedTime: CMTime(seconds: elapsedSeconds, preferredTimescale: 600),
            duration: duration
        )
    }

    /// 在 CPTemplateApplicationSceneDelegate 的 didDisconnect 呼叫，清掉 time observer。
    /// （沒有直接寫在 deinit：CarPlayVideoCoordinator 是 @MainActor，但 deinit 預設
    /// 是 nonisolated context，無法在裡面直接碰 playback.player 這種 actor-isolated
    /// 狀態，所以改成由呼叫端在還在 MainActor context 時主動呼叫。）
    func stop() {
        if let token = timeObserverToken {
            playback.player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
