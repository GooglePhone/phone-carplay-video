import Foundation

/// 影片來源的抽象介面。現階段只有 `SampleVideoProvider` 這個實作，
/// 之後要換成真正合規的來源（自有內容、授權串流服務等）時，
/// 只需新增另一個實作這個 protocol 的型別，不用動 UI 或 CarPlay 端的程式碼。
protocol VideoSourceProviding: Sendable {
    func fetchLibrary() async throws -> [VideoItem]
}
