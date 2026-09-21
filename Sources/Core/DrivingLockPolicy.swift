import Foundation

/// 是否要求「僅停車時可播放影片」的策略開關。
///
/// Apple 對 CarPlay 影片播放的正式規定是行駛中必須自動降級為純音訊，
/// 但這個限制只在真實車機上有意義。原型階段只在 CarPlay Simulator 測試，
/// 所以先設為 `.alwaysUnlocked`；等要在真機／上架前，把 `current` 改成
/// `.parkedOnly`，並在 CarPlayVideoCoordinator 串接車機回報的真實行駛狀態。
enum DrivingLockPolicy {
    case alwaysUnlocked
    case parkedOnly

    @MainActor
    static var current: DrivingLockPolicy = .alwaysUnlocked

    func canPlayVideo(isVehicleParked: Bool = true) -> Bool {
        switch self {
        case .alwaysUnlocked:
            return true
        case .parkedOnly:
            return isVehicleParked
        }
    }
}
