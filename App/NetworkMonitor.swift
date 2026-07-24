import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var online = false
    @Published private(set) var interface = "Нет сети"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "wlvpn.transport.path")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.online = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.interface = "Wi‑Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.interface = "Мобильная сеть"
                } else if path.status == .satisfied {
                    self?.interface = "Сеть"
                } else {
                    self?.interface = "Нет сети"
                }
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
