import Foundation

struct VideoItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let playbackURL: URL
}
