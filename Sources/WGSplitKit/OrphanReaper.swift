import Foundation

/// Kills sing-box processes we previously spawned but no longer own.
///
/// wgsplitd can die without running its cleanup — SIGKILL, a crash, or
/// `launchctl bootout` racing the signal handler. The orphaned sing-box keeps
/// the TUN device and its address, which makes every subsequent start fail
/// with "sing-box exited within 5.0s of start". Reaping at startup makes the
/// daemon self-healing instead of permanently wedged.
public enum OrphanReaper {
    /// Matches only sing-box processes launched from our own binary path, so a
    /// sing-box the user runs by hand is left alone.
    public static func orphanPIDs(psOutput: String,
                                  binaryPath: String,
                                  excluding: Set<Int32> = []) -> [Int32] {
        psOutput.split(separator: "\n").compactMap { line -> Int32? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " "),
                  let pid = Int32(trimmed[..<space]),
                  !excluding.contains(pid)
            else { return nil }
            let command = trimmed[trimmed.index(after: space)...]
                .trimmingCharacters(in: .whitespaces)
            return command.hasPrefix(binaryPath + " ") ? pid : nil
        }
    }

    public static func runningProcesses() -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axo", "pid=,command="]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    @discardableResult
    public static func reap(binaryPath: String, excluding: Set<Int32> = []) -> [Int32] {
        let pids = orphanPIDs(psOutput: runningProcesses(),
                              binaryPath: binaryPath, excluding: excluding)
        for pid in pids { kill(pid, SIGTERM) }
        return pids
    }
}
