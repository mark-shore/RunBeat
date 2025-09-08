import SwiftUI

/**
 * LoggingTestView - Simple test view to demonstrate the new logging system
 * This view allows testing different log levels and rate limiting behavior
 */
struct LoggingTestView: View {
    @State private var selectedLogLevel = AppLogger.LogLevel.info
    @State private var testMessage = "Test message"
    @State private var spamCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Logging System Test")
                .font(.title)
            
            // Log level picker
            Picker("Log Level", selection: $selectedLogLevel) {
                ForEach(AppLogger.LogLevel.allCases, id: \.self) { level in
                    Text(level.name).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Current log level display
            Text("Current System Log Level: \(AppLogger.currentLogLevel.name)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Test message input
            TextField("Test Message", text: $testMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Log level test buttons
            VStack(spacing: 10) {
                Button("Test Error") {
                    AppLogger.error(testMessage, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("Test Warning") {
                    AppLogger.warn(testMessage, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                Button("Test Info") {
                    AppLogger.info(testMessage, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button("Test Debug") {
                    AppLogger.debug(testMessage, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Test Verbose") {
                    AppLogger.verbose(testMessage, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            
            Divider()
            
            // Rate limiting test
            VStack(spacing: 10) {
                Text("Rate Limiting Test")
                    .font(.headline)
                
                Button("Spam Test (Rate Limited)") {
                    spamCount += 1
                    AppLogger.rateLimited(.info, message: "Spam message #\(spamCount)", key: "spam_test", component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                
                Text("Spam Count: \(spamCount)")
                    .font(.caption)
            }
            
            Divider()
            
            // Player state test
            VStack(spacing: 10) {
                Text("Player State Test")
                    .font(.headline)
                
                Button("Test Player State") {
                    AppLogger.playerState("Player state test", trackName: "Test Song", artist: "Test Artist", isPlaying: true, component: "LogTest")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Log level controls
            VStack(spacing: 10) {
                Text("System Controls")
                    .font(.headline)
                
                Button("Set Log Level: \(selectedLogLevel.name)") {
                    AppLogger.setLogLevel(selectedLogLevel)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
                
                Button("Clear Rate Limit Cache") {
                    AppLogger.clearRateLimitCache()
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
            }
        }
        .padding()
    }
}

#Preview {
    LoggingTestView()
}