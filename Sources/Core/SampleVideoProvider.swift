import Foundation

/// 原型階段使用的範例影片來源，內容是 Apple 官方公開的 HLS 測試串流（BipBop），
/// 純粹用來打通「瀏覽 → 播放」這條技術管線。
///
/// TODO: 之後替換成合規的真實來源 provider（見計畫文件第 6 節）。
struct SampleVideoProvider: VideoSourceProviding {
    func fetchLibrary() async throws -> [VideoItem] {
        [
            VideoItem(
                id: "bipbop-4x3",
                title: "Apple Sample Stream — BipBop (4:3)",
                thumbnailURL: nil,
                playbackURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!
            ),
            VideoItem(
                id: "bipbop-16x9",
                title: "Apple Sample Stream — BipBop (16:9)",
                thumbnailURL: nil,
                playbackURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
            ),
        ]
    }
}
