import Foundation
import WGSplitKit

let supportDirectory = URL(fileURLWithPath:
    ProcessInfo.processInfo.environment["WGSPLIT_SUPPORT_DIR"]
        ?? "/Library/Application Support/WGSplit")
let socketPath = ProcessInfo.processInfo.environment["WGSPLIT_SOCKET"]
    ?? "/var/run/wgsplit.sock"
let singBoxBinary = URL(fileURLWithPath:
    ProcessInfo.processInfo.environment["WGSPLIT_SINGBOX"]
        ?? "/Library/PrivilegedHelperTools/wgsplit/sing-box")

let store = StateStore(directory: supportDirectory)
let clashAPI = try store.loadOrCreateClashAPI()
let supervisor = Supervisor(store: store, runner: ProcessRunner(binary: singBoxBinary),
                            clashAPI: clashAPI)

// Restore whatever was running before a reboot or daemon restart.
let startupState = store.load()
if startupState.enabled {
    do { try supervisor.apply(startupState) }
    catch { FileHandle.standardError.write(Data("startup apply failed: \(error)\n".utf8)) }
}

func respond(_ requestLine: Data) -> Data {
    func reply(_ response: ControlResponse) -> Data {
        (try? ControlCodec.encode(response)) ?? Data("{\"failure\":\"encode\"}\n".utf8)
    }
    do {
        let request = try ControlCodec.decode(ControlRequest.self, from: requestLine)
        var state = store.load()

        switch request {
        case .status:
            break
        case .importTunnel(let tunnel):
            state.tunnels.removeAll { $0.name == tunnel.name }
            state.tunnels.append(tunnel)
            if state.activeTunnelID == nil { state.activeTunnelID = tunnel.id }
        case .setActiveTunnel(let id):
            state.activeTunnelID = id
        case .setRules(let rules):
            state.rules = rules
        case .setEnabled(let enabled):
            state.enabled = enabled
        }

        if case .status = request {
            // Read-only: never touches the running process.
        } else {
            try supervisor.apply(state)
        }
        return reply(.status(Status(state: store.load(),
                                    running: supervisor.isRunning,
                                    health: supervisor.health,
                                    lastError: supervisor.lastError)))
    } catch {
        return reply(.failure("\(error)"))
    }
}

// gid 20 is `staff`; the console user belongs to it and needs socket access.
try SocketServer(path: socketPath, ownerGID: 20, handler: respond).run()
