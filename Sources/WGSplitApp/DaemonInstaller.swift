import Foundation

/// Installs the LaunchDaemon by elevating through osascript.
///
/// The command handed to `do shell script … with administrator privileges`
/// runs as root, so it is built only from Bundle.main's own path — never from
/// user input or persisted state. The script is copied out of the bundle to a
/// root-owned location by the script itself; the daemon never executes from
/// inside the user-writable bundle.
enum DaemonInstaller {
    enum Failure: Error {
        case scriptMissing
        case cancelled
        case failed(String)

        var message: String {
            switch self {
            case .scriptMissing:
                return "This build has no bundled installer. Run Scripts/install-daemon.sh with sudo."
            case .cancelled:
                return "Installation cancelled."
            case .failed(let detail):
                return "Install failed: \(detail)"
            }
        }
    }

    static var bundledScript: URL? {
        Bundle.main.url(forResource: "install-daemon", withExtension: "sh")
    }

    static func install() -> Failure? {
        guard let script = bundledScript else { return .scriptMissing }
        return runAsAdmin(shellQuoted(script.path))
    }

    /// Run one shell command as root through the standard macOS password
    /// dialog. Callers build the command from trusted paths only — this runs
    /// as root, so user input or persisted state must never reach it.
    static func runAsAdmin(_ shellCommand: String) -> Failure? {
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\")
                                  .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        do shell script "\(escaped)" with administrator privileges
        """

        var errorInfo: NSDictionary?
        _ = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return nil }

        // -128 is the standard "user cancelled" code; not an error worth alarming about.
        if (errorInfo[NSAppleScript.errorNumber] as? Int) == -128 { return .cancelled }
        return .failed(errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown error")
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
