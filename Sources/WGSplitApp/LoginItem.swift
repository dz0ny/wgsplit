import Foundation
import ServiceManagement

/// Wraps SMAppService so the menu can show real registration state and a
/// real error, rather than a checkbox that silently does nothing.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Returns nil on success, or a human-readable reason on failure.
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "Start at Login failed: \(error.localizedDescription). "
                 + "Move WGSplit.app to /Applications and try again."
        }
    }
}
