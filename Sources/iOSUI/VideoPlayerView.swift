import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let item: VideoItem
    @ObservedObject var playback: PlaybackController

    var body: some View {
        VideoPlayer(player: playback.player)
            .navigationTitle(item.title)
            .onAppear { playback.play(item) }
    }
}
