import SwiftUI

@main
struct PhoneCarPlayVideoApp: App {
    var body: some Scene {
        WindowGroup {
            VideoLibraryView(source: SampleVideoProvider(), playback: PlaybackController.shared)
        }
    }
}
