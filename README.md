# PhoneCarPlayVideo（技術原型）

iPhone + CarPlay 影片播放的技術原型。完整背景、限制與規劃見
`C:\Users\USER\.claude\plans\iphone-carplay-app-lucky-lampson.md`。

## 重要：這份程式碼是在 Windows 上寫的，真正的 Xcode/CarPlay Simulator 測試仍需在 macOS 完成

Xcode、iOS Simulator、CarPlay Simulator 都只能在 macOS 上跑，這台機器沒有
這些，所以**沒辦法**做到真正跑 Xcode build 或 CarPlay Simulator 這一步。

但有做過比人工審查更進一步的驗證：在 Windows 上裝了 Swift 6 工具鏈，並用
Docker 跑官方 Linux `swift:6.0` image，針對這 10 個檔案（`Models/`、`Core/`、
`CarPlay/`、`iOSUI/`、`App/` 全部）做了**真正的 swiftc 編譯**——因為
CarPlay/AVFoundation/MediaPlayer/SwiftUI/AVKit/Combine 在 Linux 上不存在，
另外寫了一組「shim」模組，簽名對照 Apple 官方文件（CarPlay 的部分是直接
查證 developer.apple.com 的即時文件）逐一核對過，讓這 10 個檔案可以在
Swift 6 嚴格 concurrency 檢查下被真的編譯一次。這個過程另外抓到並修正了
兩個真實的 bug（見下面「已修正」）。這不是真正的 Apple SDK，還是需要在
Mac 上用 Xcode 對照官方 SDK 再跑一次，但已經比純人工讀程式碼可靠很多。

## 在 Mac 上開啟專案

推薦用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 從 `project.yml`
產生 `.xcodeproj`：

```bash
brew install xcodegen
cd PhoneCarPlayVideo   # 這個資料夾
xcodegen generate
open PhoneCarPlayVideo.xcodeproj
```

沒有 XcodeGen 的話，也可以手動建立：新增一個 SwiftUI App 專案，把預設的
`App.swift` 和 `Info.plist` 刪掉，改把 `Sources/` 底下所有檔案加進 target，
再到 target 設定裡把 Info.plist 指到 `Resources/Info.plist`、
Signing & Capabilities 加上 `Resources/PhoneCarPlayVideo.entitlements`。

## 驗證步驟

1. `Product > Run` 在一般 iOS Simulator 上，確認影片庫能瀏覽、點進去能播放
   （`Sources/iOSUI`）。
2. 開 CarPlay Simulator（Simulator 執行中：`I/O > External Displays >
   CarPlay`，或 Xcode 開發者工具內的獨立 CarPlay Simulator App），確認：
   - App 出現在 CarPlay 首頁
   - 瀏覽模板列得出影片清單（`Sources/CarPlay/CarPlayVideoCoordinator.swift`）
   - 選片後能播放、且 iPhone 端與 CarPlay 端播放狀態同步

## CarPlay 影片播放 API（已查證、已改用官方正式作法）

原本以為 iOS 26 CarPlay 會有一個獨立的「video scene」類別（例如猜測的
`CPTemplateApplicationVideoScene`），查證 Apple 官方文件
（[developer.apple.com/documentation/carplay](https://developer.apple.com/documentation/carplay)）
後發現**沒有這回事**：影片播放是掛在既有的 `CPTemplateApplicationScene` /
`CPListTemplate` 架構上，透過 iOS 26.4+ 新增的：

- `protocol CPPlayableItem`：要求 `var playbackConfiguration: CPPlaybackConfiguration?`，
  `CPListItem` 等既有型別直接 conform。
- `class CPPlaybackConfiguration`（`@MainActor`）：`preferredPresentation`
  （`.video` / `.audio` / `.none`）、`playbackAction`（`.play` / `.pause` /
  `.replay` / `.none`）、`elapsedTime`、`duration`。

做法是把 `CPListItem.playbackConfiguration` 設成 `.video`，選取後系統就會在
車機螢幕顯示影片介面，實際解碼/輸出仍是我方的 `AVPlayer`；已在
`Sources/CarPlay/CarPlayVideoCoordinator.swift` 實作完成，並拿掉了原本
`CPNowPlayingTemplate` 頂替的暫時作法。`DrivingLockPolicy` 現在直接對應到
`preferredPresentation`：解鎖給 `.video`，鎖定（行駛中）給 `.audio`，這正是
Apple 文件說的「行駛中自動降級為純音訊」的機制。

Scene delegate 的生命週期方法（`templateApplicationScene(_:didConnect:)` +
`CPInterfaceController.setRootTemplate(_:animated:completion:)`）維持原設計，
與官方 [Displaying Content in CarPlay](https://developer.apple.com/documentation/carplay/displaying-content-in-carplay)
指南的範例程式碼一致。

**仍未確認的一點**：官方 [Requesting CarPlay Entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
頁面目前列出的 entitlement key 只有 audio／communication／charging／maps／
parking／quick-ordering，還沒列出影片專用的 entitlement key 字串（很可能是
`com.apple.developer.carplay-video`，但這是推測，非文件確認）。這不影響
Simulator 測試（Simulator 不檢查真實 entitlement），但正式申請/上架前要跟
Apple 核對正確 key 名稱。

## 已修正（Linux + shim 編譯檢查時抓到的真實 bug）

- `PlaybackController.swift` 用了 `ObservableObject`/`@Published`，但沒有
  `import Combine`（只 import 了 AVFoundation/MediaPlayer）——已補上。
- `DrivingLockPolicy.current` 是 nonisolated 的全域可變靜態狀態，在 Swift 6
  嚴格 concurrency 下不安全——已標成 `@MainActor`（用到它的地方本來就都在
  MainActor context，不需要改呼叫端）。
- `VideoSourceProviding` protocol 沒有要求 `Sendable`，導致
  `CarPlayVideoCoordinator`（`@MainActor`）呼叫
  `videoSource.fetchLibrary()` 時被判定為跨 isolation domain 的資料競爭風險
  ——已把 protocol 改成 `VideoSourceProviding: Sendable`，`VideoItem` 也明確
  標上 `Sendable`。

## 已知待辦

- `Sources/Core/DrivingLockPolicy.swift` 目前是 `.alwaysUnlocked`，正式上
  真機／上架前要切回 `.parkedOnly` 並接上車機真實的行駛狀態。
- 影片來源目前是 `SampleVideoProvider`（Apple 官方測試串流），之後要換成
  合規的真實來源時，新增一個 `VideoSourceProviding` 實作即可。
- 請在 Mac 上照上面步驟跑一次 `xcodegen generate` + Xcode build 做最終確認
  ——這裡的編譯檢查是對照 shim（模擬 Apple SDK 簽名）做的，不是真正的
  Apple SDK，理論上仍可能有 shim 沒完全還原到的細節，把任何編譯錯誤回報
  回來。
