import Foundation
import WGSplitKit

@MainActor
final class AppModel: ObservableObject {
    @Published var status: Status?
    @Published var errorMessage: String?

    private let client = ControlClient()

    var isRunning: Bool { status?.running ?? false }

    func refresh() { send(.status) }

    func toggleEnabled() { send(.setEnabled(!isRunning)) }

    func setActive(_ id: UUID?) { send(.setActiveTunnel(id)) }

    func setRules(_ patterns: [String]) {
        send(.setRules(patterns.map(Rule.init(pattern:))))
    }

    func importZip(at url: URL) {
        do {
            let tunnels = try TunnelImporter.importTunnels(fromZip: url)
            for tunnel in tunnels { send(.importTunnel(tunnel)) }
        } catch {
            errorMessage = "Import failed: \(error)"
        }
    }

    private func send(_ request: ControlRequest) {
        do {
            switch try client.send(request) {
            case .status(let s):
                status = s
                errorMessage = s.lastError
            case .failure(let m):
                errorMessage = m
            }
        } catch {
            status = nil
            errorMessage = "Daemon unavailable. Run Scripts/install-daemon.sh with sudo."
        }
    }
}
