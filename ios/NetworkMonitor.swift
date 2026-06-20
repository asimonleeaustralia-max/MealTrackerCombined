import Foundation
import Network
import Combine

// Observable NWPathMonitor wrapper for SwiftUI.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isExpensive: Bool = false   // true on Cellular / Personal Hotspot
    @Published private(set) var interfaceTypeDescription: String = "unknown"

    var isOnWiFi: Bool {
        // Heuristic: Wi‑Fi when path uses .wifi and not expensive.
        // Note: Some Wi‑Fi can be marked expensive (metered). We still show a warning if isExpensive == true.
        return !isExpensive && interfaceTypeDescription == "wifi"
    }

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isConnected = (path.status == .satisfied)
                self.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self.interfaceTypeDescription = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    self.interfaceTypeDescription = "cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.interfaceTypeDescription = "ethernet"
                } else if path.usesInterfaceType(.loopback) {
                    self.interfaceTypeDescription = "loopback"
                } else if path.usesInterfaceType(.other) {
                    self.interfaceTypeDescription = "other"
                } else {
                    self.interfaceTypeDescription = "unknown"
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

private extension NWPath {
    func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {
        availableInterfaces.contains(where: { $0.type == type }) && (usesInterfaceTypeInternal(type))
    }

    // When the API is limited, approximate by checking if any of the satisfied interfaces match.
    func usesInterfaceTypeInternal(_ type: NWInterface.InterfaceType) -> Bool {
        for interface in availableInterfaces where interface.type == type {
            if self.status == .satisfied { return true }
        }
        return false
    }
}
