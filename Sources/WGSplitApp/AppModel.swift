import Foundation
import SwiftUI
import WGSplitKit

@MainActor
final class AppModel: ObservableObject {
    @Published var status: Status?
    @Published var errorMessage: String?

    private let client = ControlClient()
    private var refreshing = false
    private var revision = 0
    private var poll: Timer?
    private var pulse: Timer?
    /// Flips while a request is in flight so the menu bar icon animates.
    @Published private var pulseOn = false

    init() {
        // .onAppear is unreliable for NSMenu-backed MenuBarExtra items, and the
        // daemon can be briefly unreachable while it restarts. Polling keeps the
        // menu honest and lets the app recover on its own.
        poll = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
        if autoCheckUpdates { Task { await checkForUpdate() } }
    }

    deinit { poll?.invalidate() }

    @Published var startsAtLogin = LoginItem.isEnabled
    /// Applying a change can take 10s on the daemon side (5s settle, plus a
    /// 5s rollback restart if it fails), so requests must never run on the
    /// main actor or the menu freezes for the duration.
    @Published var busy = false

    var isRunning: Bool { status?.running ?? false }

    /// Filled shield only once traffic has actually gone through the tunnel;
    /// "running" is deliberately distinguished from "working". While a request
    /// is in flight the icon pulses, because applying a change takes seconds
    /// and a frozen-looking menu reads as a broken app.
    var menuBarSymbol: String {
        // Deliberately drops the lock glyph so the pulse cannot be mistaken
        // for the steady lock.shield.fill of a running tunnel.
        if busy { return pulseOn ? "shield.fill" : "shield" }
        switch status?.health ?? .stopped {
        case .stopped: return "lock.shield"
        case .running: return "lock.shield.fill"
        case .active: return "checkmark.shield.fill"
        }
    }

    private func startPulse() {
        guard pulse == nil else { return }
        pulse = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulseOn.toggle() }
        }
    }

    private func stopPulse() {
        pulse?.invalidate()
        pulse = nil
        pulseOn = false
    }

    /// After installing, the daemon needs a moment to bind its socket and can
    /// then spend seconds restoring state. Poll hard until it answers so the
    /// menu updates promptly instead of looking like the install did nothing.
    private func awaitDaemon(deadline: Date = Date().addingTimeInterval(40)) {
        guard status == nil, Date() < deadline else {
            // Give up cleanly: clearing busy re-enables the menu and lets
            // Install Helper reappear rather than stranding it on "Working…".
            if status == nil {
                errorMessage = "Helper installed but the daemon did not respond. "
                             + "Check: make status"
            }
            busy = false
            stopPulse()
            return
        }
        Task {
            let reachable = await Task.detached { (try? ControlClient().send(.status)) != nil }.value
            if reachable {
                self.busy = false
                self.send(.status)
            } else {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.awaitDaemon(deadline: deadline)
            }
        }
    }

    /// One line combining state and active tunnel, so the top of the menu
    /// says something useful instead of showing a greyed-out fragment.
    var headline: String {
        if installing { return "Installing helper…" }
        if busy { return "Working…" }
        guard let status else { return errorMessage ?? "Connecting…" }

        let tunnel = status.tunnels.first { $0.id == status.activeTunnelID }?.name
        switch status.health {
        case .stopped:
            return tunnel.map { "Stopped · \($0)" } ?? "Stopped"
        case .running:
            return "Connected · not passing traffic"
        case .active:
            let latency = status.latencyMs.map { " · \($0) ms" } ?? ""
            return "Connected\(tunnel.map { " · \($0)" } ?? "")\(latency)"
        }
    }

    /// True when the daemon has never answered, i.e. it probably is not installed.
    @Published var installing = false

    func installHelper() {
        busy = true
        startPulse()
        installing = true
        Task {
            let failure = await Task.detached { DaemonInstaller.install() }.value
            self.installing = false
            if let failure {
                self.errorMessage = failure.message
                self.busy = false
                self.stopPulse()
                return
            }
            self.errorMessage = nil
            self.awaitDaemon()
        }
    }

    // MARK: app self-update

    @Published var availableUpdate: SelfUpdater.Release?
    @Published var updating = false
    @Published var updateError: String?
    /// Checked once per launch, and whenever Settings asks. Failures stay
    /// silent — the next launch or a manual check retries.
    @AppStorage("autoCheckUpdates") var autoCheckUpdates = true

    var installedVersion: String { SelfUpdater.installedVersion }

    func checkForUpdate() async {
        availableUpdate = (try? await SelfUpdater.check()) ?? availableUpdate
    }

    /// Download, verify, and install `availableUpdate`. The app relaunches
    /// itself on success, so this only returns on failure.
    func installUpdate() {
        guard let release = availableUpdate, !updating else { return }
        updating = true
        updateError = nil
        Task {
            do {
                try await SelfUpdater.installAndRelaunch(release)
            } catch {
                self.updateError = error.localizedDescription
                self.updating = false
            }
        }
    }

    func toggleStartAtLogin() {
        if let problem = LoginItem.setEnabled(!startsAtLogin) {
            errorMessage = problem
        }
        startsAtLogin = LoginItem.isEnabled
    }

    func refresh() {
        guard !busy, !refreshing else { return }
        refreshing = true
        let revision = self.revision
        let client = self.client
        Task {
            let response = await Task.detached { try? client.send(.status) }.value
            self.refreshing = false
            guard self.revision == revision else { return }
            if case .status(let status) = response {
                self.status = status
                if self.errorMessage == nil { self.errorMessage = status.lastError }
                // Keep action errors visible until the next user action.
            } else if response == nil {
                self.status = nil
            }
        }
    }

    func toggleEnabled() { send(.setEnabled(!isRunning)) }

    func setActive(_ id: UUID?) { send(.setActiveTunnel(id)) }

    func setRules(_ patterns: [String]) {
        send(.setRules(patterns.map(Rule.init(pattern:))))
    }

    func importZip(at url: URL) {
        do {
            let tunnels = try TunnelImporter.importTunnels(fromZip: url)
            send(tunnels.map(ControlRequest.importTunnel))
        } catch {
            errorMessage = "Import failed: \(error)"
        }
    }

    private func send(_ request: ControlRequest) { send([request]) }

    private func send(_ requests: [ControlRequest]) {
        guard !busy || installing, !requests.isEmpty else { return }
        revision += 1
        errorMessage = nil
        busy = true
        startPulse()
        let client = self.client
        Task {
            let outcome = await Task.detached { () -> Result<ControlResponse, Error> in
                do {
                    var response: ControlResponse = .failure("No request was sent.")
                    for request in requests {
                        response = try client.send(request)
                        if case .failure = response { break }
                    }
                    return .success(response)
                } catch { return .failure(error) }
            }.value

            switch outcome {
            case .success(.status(let s)):
                self.status = s
                self.errorMessage = s.lastError
            case .success(.failure(let m)):
                self.errorMessage = m
            case .failure:
                self.status = nil
                self.errorMessage =
                    "Cannot reach the helper. Open Settings → General to install it."
            }
            self.busy = false
            self.stopPulse()
        }
    }
}
