//
//  KeychainWrapper.swift
//  RunBeat
//
//  Simple keychain wrapper for storing Spotify tokens securely
//

import Foundation
import Security

class KeychainWrapper {
    static let shared = KeychainWrapper()
    
    private let service = Bundle.main.bundleIdentifier ?? "com.runbeat.app"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Store a string value in the keychain
    func store(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ [Keychain] Failed to convert string to data for key: \(key)")
            return false
        }
        
        return store(data, forKey: key)
    }
    
    /// Retrieve a string value from the keychain
    func retrieve(forKey key: String) -> String? {
        guard let data = retrieveData(forKey: key) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Remove a value from the keychain
    func remove(forKey key: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        
        if status == errSecSuccess {
            print("✅ [Keychain] Successfully removed item for key: \(key)")
            return true
        } else if status == errSecItemNotFound {
            print("ℹ️ [Keychain] Item not found for key: \(key)")
            return true // Consider not found as success for removal
        } else {
            print("❌ [Keychain] Failed to remove item for key: \(key), status: \(status)")
            return false
        }
    }
    
    /// Check if a key exists in the keychain
    func exists(forKey key: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: false
        ] as CFDictionary
        
        let status = SecItemCopyMatching(query, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Implementation
    
    private func store(_ data: Data, forKey key: String) -> Bool {
        // First, try to update existing item
        let updateQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as CFDictionary
        
        let updateAttributes = [
            kSecValueData: data
        ] as CFDictionary
        
        var status = SecItemUpdate(updateQuery, updateAttributes)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, create new one
            let addQuery = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ] as CFDictionary
            
            status = SecItemAdd(addQuery, nil)
        }
        
        if status == errSecSuccess {
            print("✅ [Keychain] Successfully stored item for key: \(key)")
            return true
        } else {
            print("❌ [Keychain] Failed to store item for key: \(key), status: \(status)")
            return false
        }
    }
    
    private func retrieveData(forKey key: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status == errSecSuccess {
            print("✅ [Keychain] Successfully retrieved item for key: \(key)")
            return result as? Data
        } else if status == errSecItemNotFound {
            print("ℹ️ [Keychain] Item not found for key: \(key)")
            return nil
        } else {
            print("❌ [Keychain] Failed to retrieve item for key: \(key), status: \(status)")
            return nil
        }
    }
}

// MARK: - Keychain Error Handling

extension KeychainWrapper {
    private func errorDescription(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case -25293: // errSecUserCancel
            return "User cancelled"
        case errSecNotAvailable:
            return "Keychain not available"
        default:
            return "Unknown error (\(status))"
        }
    }
}