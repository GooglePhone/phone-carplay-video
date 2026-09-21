import SwiftUI

struct VideoLibraryView: View {
    let source: VideoSourceProviding
    @ObservedObject var playback: PlaybackController

    @State private var items: [VideoItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(item.title) {
                    VideoPlayerView(item: item, playback: playback)
                }
            }
            .navigationTitle("影片庫")
            .task { await loadLibrary() }
            .overlay {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
    }

    private func loadLibrary() async {
        do {
            items = try await source.fetchLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
