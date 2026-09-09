import Foundation

public enum ZipError: Error, Equatable {
    case unreadable(String)
}

/// Reads `.conf` entries out of a zip using /usr/bin/unzip.
/// Shelling out avoids a third-party dependency; unzip ships with macOS.
public enum ZipReader {
    public static func confEntries(at url: URL) throws -> [String: String] {
        let names = try run(["-Z1", url.path])
            .split(separator: "\n").map(String.init)
            .filter { $0.lowercased().hasSuffix(".conf") }

        var out: [String: String] = [:]
        for name in names {
            out[name] = try run(["-p", url.path, name])
        }
        return out
    }

    private static func run(_ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = args
        let stdout = Pipe(), stderr = Pipe()
        p.standardOutput = stdout; p.standardError = stderr
        do { try p.run() } catch { throw ZipError.unreadable(error.localizedDescription) }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: errData, encoding: .utf8) ?? "unzip failed"
            throw ZipError.unreadable(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
