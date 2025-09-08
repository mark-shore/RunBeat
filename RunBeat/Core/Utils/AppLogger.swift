import Foundation
import UIKit

/**
 * AppLogger - Centralized logging system for RunBeat
 * 
 * Features:
 * - Log levels (ERROR, WARN, INFO, DEBUG, VERBOSE)
 * - Rate limiting to prevent spam
 * - Contextual prefixes for different components
 * - Production-ready output formatting
 */
class AppLogger {
    
    // MARK: - Log Levels
    
    enum LogLevel: Int, CaseIterable {
        case error = 0    // Only critical errors
        case warn = 1     // Important warnings 
        case info = 2     // General information
        case debug = 3    // Debug information
        case verbose = 4  // Detailed debug output
        
        var prefix: String {
            switch self {
            case .error: return "❌"
            case .warn: return "⚠️"
            case .info: return "ℹ️"
            case .debug: return "🔍"
            case .verbose: return "📝"
            }
        }
        
        var name: String {
            switch self {
            case .error: return "ERROR"
            case .warn: return "WARN"
            case .info: return "INFO"
            case .debug: return "DEBUG"
            case .verbose: return "VERBOSE"
            }
        }
    }
    
    // MARK: - Configuration
    
    static var currentLogLevel: LogLevel = {
        #if DEBUG
        return .verbose
        #else
        return .info
        #endif
    }()
    
    // MARK: - Rate Limiting
    
    private static var lastLogTimes: [String: Date] = [:]
    private static var suppressedCounts: [String: Int] = [:]
    private static let rateLimitInterval: TimeInterval = 5.0
    private static let lockQueue = DispatchQueue(label: "com.runbeat.logger.lock")
    
    // MARK: - Public Logging Methods
    
    static func error(_ message: String, component: String = "", function: String = #function, line: Int = #line) {
        log(.error, message: message, component: component, function: function, line: line)
    }
    
    static func warn(_ message: String, component: String = "", function: String = #function, line: Int = #line) {
        log(.warn, message: message, component: component, function: function, line: line)
    }
    
    static func info(_ message: String, component: String = "", function: String = #function, line: Int = #line) {
        log(.info, message: message, component: component, function: function, line: line)
    }
    
    static func debug(_ message: String, component: String = "", function: String = #function, line: Int = #line) {
        log(.debug, message: message, component: component, function: function, line: line)
    }
    
    static func verbose(_ message: String, component: String = "", function: String = #function, line: Int = #line) {
        log(.verbose, message: message, component: component, function: function, line: line)
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Log player state changes with deduplication
    static func playerState(_ message: String, trackName: String = "", artist: String = "", isPlaying: Bool? = nil, component: String = "Player") {
        let stateKey = "\(trackName)|\(artist)|\(isPlaying?.description ?? "")"
        let logKey = "player_state_\(stateKey)"
        
        if shouldLog(key: logKey) {
            let playingStatus = isPlaying.map { $0 ? "▶️" : "⏸️" } ?? ""
            let details = trackName.isEmpty ? "" : " [\(playingStatus) \(trackName) - \(artist)]"
            info("\(message)\(details)", component: component)
        }
    }
    
    /// Log API responses with summary instead of full JSON
    static func apiResponse(_ message: String, statusCode: Int? = nil, dataSize: Int? = nil, component: String = "API") {
        var details: [String] = []
        if let code = statusCode { details.append("Status: \(code)") }
        if let size = dataSize { details.append("Size: \(size)b") }
        let summary = details.isEmpty ? "" : " [\(details.joined(separator: ", "))]"
        debug("\(message)\(summary)", component: component)
    }
    
    /// Log with automatic rate limiting
    static func rateLimited(_ level: LogLevel, message: String, key: String, component: String = "") {
        if shouldLog(key: key) {
            log(level, message: message, component: component)
        }
    }
    
    // MARK: - Core Logging Implementation
    
    private static func log(_ level: LogLevel, message: String, component: String, function: String = #function, line: Int = #line) {
        guard level.rawValue <= currentLogLevel.rawValue else { return }
        
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let componentPrefix = component.isEmpty ? "" : "[\(component)] "
        let locationInfo = currentLogLevel == .verbose ? " (\(function):\(line))" : ""
        
        let logMessage = "\(level.prefix) \(timestamp) \(componentPrefix)\(message)\(locationInfo)"
        print(logMessage)
    }
    
    // MARK: - Rate Limiting Implementation
    
    private static func shouldLog(key: String) -> Bool {
        return lockQueue.sync {
            let now = Date()
            
            if let lastTime = lastLogTimes[key] {
                if now.timeIntervalSince(lastTime) < rateLimitInterval {
                    suppressedCounts[key, default: 0] += 1
                    return false
                } else {
                    // Log suppressed count if any were suppressed
                    if let count = suppressedCounts[key], count > 0 {
                        let message = "(repeated \(count) times in last \(Int(rateLimitInterval))s)"
                        let timestamp = DateFormatter.logTimestamp.string(from: Date())
                        print("📋 \(timestamp) \(message)")
                        suppressedCounts.removeValue(forKey: key)
                    }
                }
            }
            
            lastLogTimes[key] = now
            return true
        }
    }
    
    // MARK: - Configuration Methods
    
    static func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        info("Log level set to \(level.name)", component: "Logger")
    }
    
    static func clearRateLimitCache() {
        lockQueue.sync {
            lastLogTimes.removeAll()
            suppressedCounts.removeAll()
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Legacy Print Replacement

/// Use this for gradual migration from print() statements
func legacyPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    AppLogger.verbose(message, component: "Legacy")
}