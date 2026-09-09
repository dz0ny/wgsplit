import Foundation

public final class ProcessHandle: SingBoxRunning, @unchecked Sendable {
    private let process: Process
    init(process: Process) { self.process = process }
    public var isRunning: Bool { process.isRunning }
    public func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
    }
}

public struct ProcessRunner: SingBoxRunner {
    private let binary: URL
    private let checkArguments: @Sendable (URL) -> [String]
    private let startArguments: @Sendable (URL) -> [String]

    public init(binary: URL,
                checkArguments: @escaping @Sendable (URL) -> [String] = { ["check", "-c", $0.path] },
                startArguments: @escaping @Sendable (URL) -> [String] = { ["run", "-c", $0.path] }) {
        self.binary = binary
        self.checkArguments = checkArguments
        self.startArguments = startArguments
    }

    public func check(configPath: URL) throws {
        let p = Process()
        p.executableURL = binary
        p.arguments = checkArguments(configPath)
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        try p.run()
        let message = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw ApplyError.checkFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public func start(configPath: URL) throws -> SingBoxRunning {
        let p = Process()
        p.executableURL = binary
        p.arguments = startArguments(configPath)
        p.standardOutput = FileHandle.standardOutput
        p.standardError = FileHandle.standardError
        try p.run()
        return ProcessHandle(process: p)
    }
}
