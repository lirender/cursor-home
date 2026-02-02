import Foundation
import AppKit

/// Monitors Synergy 3 for cursor transitions between machines.
/// Detects when the cursor leaves to another computer (e.g., Linux) or returns.
@Observable
final class SynergyMonitor {
    static let shared = SynergyMonitor()

    // MARK: - Published State

    /// Whether Synergy 3 appears to be running
    private(set) var isSynergyRunning = false

    /// The last detected transition event
    private(set) var lastTransition: CursorTransition?

    /// Whether the cursor is currently on a remote machine
    private(set) var cursorIsRemote = false

    // MARK: - Callbacks

    /// Called when cursor leaves this machine to go to another
    var onCursorLeft: ((String) -> Void)?

    /// Called when cursor returns to this machine from another
    var onCursorReturned: ((String) -> Void)?

    // MARK: - Private State

    private var logFileHandle: FileHandle?
    private var logWatcher: DispatchSourceFileSystemObject?
    private var synergyCheckTimer: Timer?
    private var lastLogPosition: UInt64 = 0

    // Synergy 3 log file locations
    private let synergyLogPaths = [
        "~/Library/Logs/Synergy/synergy.log",
        "~/.synergy/synergy.log",
        "/var/log/synergy.log",
        "~/Library/Application Support/Synergy/synergy.log"
    ].map { NSString(string: $0).expandingTildeInPath }

    private init() {}

    // MARK: - Public API

    func start() {
        // Check if Synergy is running periodically
        startSynergyDetection()

        // Try to find and monitor the log file
        if let logPath = findSynergyLogFile() {
            startLogMonitoring(at: logPath)
        }
    }

    func stop() {
        synergyCheckTimer?.invalidate()
        synergyCheckTimer = nil

        stopLogMonitoring()
    }

    // MARK: - Synergy Detection

    private func startSynergyDetection() {
        // Check immediately
        checkSynergyRunning()

        // Then check periodically
        synergyCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkSynergyRunning()
        }
    }

    private func checkSynergyRunning() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "synergy", "synergy-core", "synergys", "synergyc"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let wasRunning = isSynergyRunning
            isSynergyRunning = task.terminationStatus == 0

            // If Synergy just started, try to find log file
            if !wasRunning && isSynergyRunning {
                if let logPath = findSynergyLogFile() {
                    startLogMonitoring(at: logPath)
                }
            }
        } catch {
            isSynergyRunning = false
        }
    }

    // MARK: - Log File Monitoring

    private func findSynergyLogFile() -> String? {
        let fileManager = FileManager.default

        for path in synergyLogPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func startLogMonitoring(at path: String) {
        stopLogMonitoring()

        guard let handle = FileHandle(forReadingAtPath: path) else {
            return
        }

        logFileHandle = handle

        // Seek to end of file (we only want new entries)
        handle.seekToEndOfFile()
        lastLogPosition = handle.offsetInFile

        // Watch for changes using dispatch source
        let fd = handle.fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.processNewLogEntries()
        }

        source.setCancelHandler { [weak handle] in
            handle?.closeFile()
        }

        logWatcher = source
        source.resume()
    }

    private func stopLogMonitoring() {
        logWatcher?.cancel()
        logWatcher = nil
        logFileHandle = nil
    }

    private func processNewLogEntries() {
        guard let handle = logFileHandle else { return }

        // Read new content
        handle.seek(toFileOffset: lastLogPosition)
        let data = handle.readDataToEndOfFile()
        lastLogPosition = handle.offsetInFile

        guard let content = String(data: data, encoding: .utf8) else { return }

        // Parse each line for transition events
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if let transition = parseTransitionEvent(from: line) {
                handleTransition(transition)
            }
        }
    }

    // MARK: - Log Parsing

    /// Parses Synergy log lines for cursor transition events.
    /// Synergy 3 log format examples:
    /// - "INFO: leaving screen" or "switching to <screen-name>"
    /// - "INFO: entering screen" or "switch from <screen-name>"
    private func parseTransitionEvent(from line: String) -> CursorTransition? {
        let lowercased = line.lowercased()

        // Detect cursor leaving this machine
        if lowercased.contains("leaving") || lowercased.contains("switch to") || lowercased.contains("switching to") {
            // Try to extract destination screen name
            let destination = extractScreenName(from: line, direction: .leaving) ?? "remote"
            return CursorTransition(
                type: .left,
                screenName: destination,
                timestamp: Date()
            )
        }

        // Detect cursor returning to this machine
        if lowercased.contains("entering") || lowercased.contains("switch from") || lowercased.contains("switching from") {
            // Try to extract source screen name
            let source = extractScreenName(from: line, direction: .entering) ?? "remote"
            return CursorTransition(
                type: .returned,
                screenName: source,
                timestamp: Date()
            )
        }

        return nil
    }

    private func extractScreenName(from line: String, direction: TransitionDirection) -> String? {
        // Common patterns in Synergy logs
        let patterns: [String]
        switch direction {
        case .leaving:
            patterns = [
                "switching to ([\\w\\-\\.]+)",
                "switch to ([\\w\\-\\.]+)",
                "leaving .*?to ([\\w\\-\\.]+)",
                "-> ([\\w\\-\\.]+)"
            ]
        case .entering:
            patterns = [
                "switching from ([\\w\\-\\.]+)",
                "switch from ([\\w\\-\\.]+)",
                "entering .*?from ([\\w\\-\\.]+)",
                "<- ([\\w\\-\\.]+)"
            ]
        }

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range),
                   let captureRange = Range(match.range(at: 1), in: line) {
                    return String(line[captureRange])
                }
            }
        }

        return nil
    }

    // MARK: - Transition Handling

    private func handleTransition(_ transition: CursorTransition) {
        lastTransition = transition

        switch transition.type {
        case .left:
            cursorIsRemote = true
            onCursorLeft?(transition.screenName)
            NotificationCenter.default.post(
                name: .cursorLeftToRemote,
                object: self,
                userInfo: ["screenName": transition.screenName]
            )

        case .returned:
            cursorIsRemote = false
            onCursorReturned?(transition.screenName)
            NotificationCenter.default.post(
                name: .cursorReturnedFromRemote,
                object: self,
                userInfo: ["screenName": transition.screenName]
            )
        }
    }
}

// MARK: - Supporting Types

struct CursorTransition {
    enum TransitionType {
        case left      // Cursor left this machine
        case returned  // Cursor returned to this machine
    }

    let type: TransitionType
    let screenName: String
    let timestamp: Date
}

private enum TransitionDirection {
    case leaving
    case entering
}

// MARK: - Notification Names

extension Notification.Name {
    static let cursorLeftToRemote = Notification.Name("CursorHome.cursorLeftToRemote")
    static let cursorReturnedFromRemote = Notification.Name("CursorHome.cursorReturnedFromRemote")
}
