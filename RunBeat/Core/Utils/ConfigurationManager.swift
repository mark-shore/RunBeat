//
//  ConfigurationManager.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var configuration: [String: String] = [:]
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        print("Loading configuration...")
        
        // First try to load from .env file (for development)
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            print("Found .env file at: \(envPath)")
            if let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
                print("Successfully loaded .env file")
                parseEnvFile(envContent)
            } else {
                print("Failed to load .env file content")
            }
        } else {
            print("No .env file found in bundle")
        }
        
        // Then try to load from Config.plist (for production)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            print("Found Config.plist at: \(configPath)")
            if let configData = NSDictionary(contentsOfFile: configPath) as? [String: String] {
                print("Successfully loaded Config.plist")
                configuration.merge(configData) { _, new in new }
            } else {
                print("Failed to load Config.plist content")
            }
        } else {
            print("No Config.plist found in bundle")
        }
        
        print("Configuration loaded. Keys: \(configuration.keys)")
    }
    
    private func parseEnvFile(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                let components = trimmedLine.components(separatedBy: "=")
                if components.count == 2 {
                    let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    configuration[key] = value
                }
            }
        }
    }
    
    func getValue(for key: String) -> String? {
        return configuration[key]
    }
    
    func getValue(for key: String, defaultValue: String) -> String {
        return configuration[key] ?? defaultValue
    }
}

// MARK: - Spotify Configuration
extension ConfigurationManager {
    var spotifyClientID: String {
        return getValue(for: "SPOTIFY_CLIENT_ID", defaultValue: "")
    }
    
    var spotifyClientSecret: String {
        return getValue(for: "SPOTIFY_CLIENT_SECRET", defaultValue: "")
    }
    
    var spotifyHighIntensityPlaylistID: String {
        return getValue(for: "SPOTIFY_HIGH_INTENSITY_PLAYLIST_ID", defaultValue: "")
    }
    
    var spotifyRestPlaylistID: String {
        return getValue(for: "SPOTIFY_REST_PLAYLIST_ID", defaultValue: "")
    }
}
