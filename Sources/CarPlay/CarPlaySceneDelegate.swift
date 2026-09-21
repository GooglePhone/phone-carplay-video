import CarPlay

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private let videoSource: VideoSourceProviding = SampleVideoProvider()
    private var coordinator: CarPlayVideoCoordinator?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        let coordinator = CarPlayVideoCoordinator(
            interfaceController: interfaceController,
            videoSource: videoSource,
            playback: .shared,
            lockPolicy: .current
        )
        self.coordinator = coordinator
        coordinator.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        coordinator?.stop()
        coordinator = nil
    }
}
