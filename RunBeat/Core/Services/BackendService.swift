import Foundation
import UIKit

// MARK: - Array Extension for Unique Elements
extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        var unique = [Element]()
        for element in self {
            if !unique.contains(element) {
                unique.append(element)
            }
        }
        return unique
    }
}

/**
 * BackendService
 *
 * Handles HTTP communication with the RunBeat FastAPI backend.
 * Manages Spotify token storage, retrieval, and network error handling.
 * Implements intelligent token caching based on iOS app lifecycle.
 */
class BackendService {
    
    static let shared = BackendService()
    
    private let session: URLSession
    private var activeBaseURL: String
    private let deviceID: String
    
    // Network configuration
    private let timeoutInterval: TimeInterval = 15.0
    private let maxRetries = 3
    
    // Endpoint fallback configuration
    private let fallbackEndpoints: [String]
    private var currentEndpointIndex = 0
    
    // MARK: - Token Caching
    private var cachedToken: SpotifyTokenResponse?
    private var cacheTimestamp: Date?
    private let cacheExpirationBuffer: TimeInterval = 300 // 5 minutes before actual expiration
    
    // App lifecycle tracking
    private var isAppActive = true
    private var lastForegroundTimestamp: Date?
    
    private init() {
        // Configure URLSession for responsive connection testing
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        config.waitsForConnectivity = false  // Faster fallback
        config.networkServiceType = .responsiveData
        
        self.session = URLSession(configuration: config)
        
        // Get device ID
        self.deviceID = DeviceIDManager.shared.deviceID
        
        // Set up endpoint fallback list
        let configuredURL = ConfigurationManager.shared.getValue(for: "BackendBaseURL") ?? "https://runbeat-backend-production.up.railway.app"
        
        // Create fallback endpoints list for different scenarios
        self.fallbackEndpoints = [
            configuredURL,                              // Primary from config (Railway deployment)
            "https://runbeat-backend-production.up.railway.app",  // Railway deployment
            "http://192.168.68.53:8000",               // Mac IP address (local dev)
            "http://localhost:8000",                    // Localhost (simulator)
            "http://127.0.0.1:8000"                    // Loopback (simulator)
        ].uniqued()  // Remove duplicates
        
        self.activeBaseURL = fallbackEndpoints[0]
        
        print("[BackendService] Initialized with device ID: \(deviceID)")
        print("[BackendService] Primary endpoint: \(activeBaseURL)")
        print("[BackendService] Fallback endpoints: \(fallbackEndpoints)")
        
        // Set up app lifecycle observers
        setupAppLifecycleObservers()
        
        // Test connectivity on initialization
        Task {
            await testConnectivity()
        }
    }
    
    // MARK: - Spotify Token Management
    
    /**
     * Store Spotify tokens in the backend after successful OAuth
     */
    func storeSpotifyTokens(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int
    ) async throws {
        let url = URL(string: "\(activeBaseURL)/api/v1/devices/\(deviceID)/spotify-tokens")!
        
        let requestBody: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "expires_in": expiresIn
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[BackendService] Storing tokens for device \(deviceID)")
        
        do {
            let (data, response) = try await performRequest(request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[BackendService] Tokens stored successfully")
                    
                    // Parse response for confirmation
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("[BackendService] Server response: \(json)")
                    }
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw BackendError.httpError(httpResponse.statusCode, errorMsg)
                }
            }
        } catch {
            print("[BackendService] Failed to store tokens: \(error)")
            throw BackendError.networkError(error)
        }
    }
    
    /**
     * Get a fresh Spotify access token with intelligent caching
     * 
     * Caching behavior (app state independent):
     * - Cache tokens for up to 30 minutes OR until token expires (whichever comes first)
     * - Automatic token validation on each request
     * - No dependency on app foreground/background state
     * - Eliminates race conditions during app transitions
     */
    func getFreshSpotifyToken() async throws -> SpotifyTokenResponse {
        // Check if we have a valid cached token (app state independent)
        if let cached = cachedToken, let cacheTime = cacheTimestamp {
            // Use cached token if it's not expired and not near expiration
            if !cached.isExpiredOrExpiring {
                let cacheAge = Date().timeIntervalSince(cacheTime)
                // Use cache for up to 30 minutes or until token expires (whichever comes first)
                if cacheAge < 1800 { // 30 minutes
                    print("[BackendService] ✅ Using cached token (age: \(Int(cacheAge))s) - app state independent caching")
                    return cached
                } else {
                    print("[BackendService] Cache age exceeded 30 minutes (\(Int(cacheAge))s) - fetching fresh token")
                }
            } else {
                print("[BackendService] Cached token expired or expiring soon - fetching fresh token")
            }
        } else {
            print("[BackendService] No cached token available - fetching fresh token")
        }
        
        // Cache miss or expired - fetch from backend
        print("[BackendService] 🔄 Requesting fresh token from backend")
        return try await fetchTokenFromBackend()
    }
    
    /**
     * Fetch token from backend and update cache
     */
    private func fetchTokenFromBackend() async throws -> SpotifyTokenResponse {
        let url = URL(string: "\(activeBaseURL)/api/v1/devices/\(deviceID)/spotify-token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("[BackendService] Requesting fresh token for device \(deviceID)")
        
        do {
            let (data, response) = try await performRequest(request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                    
                    // Update cache
                    cachedToken = tokenResponse
                    cacheTimestamp = Date()
                    
                    print("[BackendService] Fresh token received and cached, expires at: \(tokenResponse.expiresAt)")
                    return tokenResponse
                } else if httpResponse.statusCode == 404 {
                    // Clear cache on 404
                    clearTokenCache()
                    throw BackendError.noTokensFound
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw BackendError.httpError(httpResponse.statusCode, errorMsg)
                }
            }
            
            throw BackendError.invalidResponse
        } catch let error as BackendError {
            throw error
        } catch {
            print("[BackendService] Failed to get fresh token: \(error)")
            throw BackendError.networkError(error)
        }
    }
    
    /**
     * Delete stored tokens from the backend (for logout)
     */
    func deleteSpotifyTokens() async throws {
        let url = URL(string: "\(activeBaseURL)/api/v1/devices/\(deviceID)/spotify-tokens")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        print("[BackendService] Deleting tokens for device \(deviceID)")
        
        do {
            let (data, response) = try await performRequest(request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[BackendService] Tokens deleted successfully")
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw BackendError.httpError(httpResponse.statusCode, errorMsg)
                }
            }
        } catch {
            print("[BackendService] Failed to delete tokens: \(error)")
            throw BackendError.networkError(error)
        }
        
        // Clear cache after successful deletion
        clearTokenCache()
    }
    
    // MARK: - Health Check
    
    /**
     * Check if the backend is reachable and healthy
     */
    func healthCheck() async -> Bool {
        let url = URL(string: "\(activeBaseURL)/api/v1/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // Shorter timeout for health checks
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("[BackendService] Health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Endpoint Management
    
    /**
     * Test connectivity to all endpoints and select the best one
     */
    private func testConnectivity() async {
        print("[BackendService] Testing connectivity to \(fallbackEndpoints.count) endpoints...")
        
        for (index, endpoint) in fallbackEndpoints.enumerated() {
            let healthURL = URL(string: "\(endpoint)/api/v1/health")!
            var request = URLRequest(url: healthURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 10.0  // Quick test
            
            do {
                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("[BackendService] ✅ Connectivity test successful: \(endpoint)")
                    await switchToEndpoint(index)
                    return
                }
            } catch {
                print("[BackendService] ❌ Connectivity test failed for \(endpoint): \(error.localizedDescription)")
            }
        }
        
        print("[BackendService] ⚠️ No endpoints are reachable, using primary: \(activeBaseURL)")
    }
    
    /**
     * Switch to a different endpoint
     */
    @MainActor
    private func switchToEndpoint(_ index: Int) {
        guard index < fallbackEndpoints.count else { return }
        
        let newEndpoint = fallbackEndpoints[index]
        if newEndpoint != activeBaseURL {
            print("[BackendService] 🔄 Switching from \(activeBaseURL) to \(newEndpoint)")
            activeBaseURL = newEndpoint
            currentEndpointIndex = index
        }
    }
    
    /**
     * Try next endpoint in fallback list
     */
    private func tryNextEndpoint() async -> Bool {
        let nextIndex = (currentEndpointIndex + 1) % fallbackEndpoints.count
        if nextIndex == 0 {
            // We've tried all endpoints
            return false
        }
        
        let nextEndpoint = fallbackEndpoints[nextIndex]
        print("[BackendService] 🔄 Trying next endpoint: \(nextEndpoint)")
        
        // Quick health check on the next endpoint
        let healthURL = URL(string: "\(nextEndpoint)/api/v1/health")!
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await switchToEndpoint(nextIndex)
                return true
            }
        } catch {
            print("[BackendService] ❌ Next endpoint \(nextEndpoint) also failed: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // MARK: - App Lifecycle Management
    
    /**
     * Set up observers for app lifecycle events to manage token cache
     */
    private func setupAppLifecycleObservers() {
        // App entering background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        
        // App returning to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
        
        // App becoming active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
    }
    
    private func handleAppDidEnterBackground() {
        isAppActive = false
        print("[BackendService] App entered background - token cache will be validated on foreground")
    }
    
    private func handleAppWillEnterForeground() {
        lastForegroundTimestamp = Date()
        print("[BackendService] App returning to foreground - token will be validated on next request")
        
        // REMOVED: Cache clearing that caused token request storms during training start
        // Existing token expiration logic (isExpiredOrExpiring + 30min cache age) handles staleness
        // clearTokenCache()
    }
    
    private func handleAppDidBecomeActive() {
        isAppActive = true
        print("[BackendService] App became active - caching enabled")
    }
    
    /**
     * Clear the token cache
     */
    private func clearTokenCache() {
        cachedToken = nil
        cacheTimestamp = nil
        print("[BackendService] Token cache cleared")
    }
    
    // MARK: - Cache Management
    
    /**
     * Force clear token cache (for logout or token issues)
     */
    func invalidateTokenCache() {
        clearTokenCache()
        print("[BackendService] Token cache manually invalidated")
    }
    
    /**
     * Get cache status for debugging
     */
    var cacheStatus: [String: Any] {
        return [
            "has_cached_token": cachedToken != nil,
            "cache_timestamp": cacheTimestamp?.description ?? "none",
            "cache_age_seconds": cacheTimestamp.map { Int(Date().timeIntervalSince($0)) } ?? 0,
            "is_app_active": isAppActive, // Note: No longer affects caching logic
            "last_foreground": lastForegroundTimestamp?.description ?? "none",
            "cached_token_expires_at": cachedToken?.expiresAt ?? "none",
            "cached_token_is_expired": cachedToken?.isExpiredOrExpiring ?? true,
            "app_state_independent": true // Cache logic is now app state independent
        ]
    }
    
    /**
     * Test helper: Verify app state independent caching behavior
     */
    func testAppStateIndependentCaching() -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        // Test 1: Cache works when app is "not active"
        isAppActive = false
        let cachesWhenInactive = (cachedToken != nil) ? true : false
        results["caches_when_app_inactive"] = cachesWhenInactive
        
        // Test 2: Cache works when app becomes active
        isAppActive = true
        let cachesWhenActive = (cachedToken != nil) ? true : false
        results["caches_when_app_active"] = cachesWhenActive
        
        // Test 3: Foreground transition doesn't clear cache
        let hadCachedToken = cachedToken != nil
        handleAppWillEnterForeground()
        let stillHasCachedToken = cachedToken != nil
        results["survives_foreground_transition"] = hadCachedToken == stillHasCachedToken
        
        print("[BackendService] App state independent caching test results: \(results)")
        return results
    }

    // MARK: - Private Helper Methods
    
    /**
     * Perform HTTP request with retry logic and endpoint fallback
     */
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        // First try the request with the active URL
        for attempt in 1...maxRetries {
            // Create request with current active URL
            let activeRequest = createRequestWithActiveURL(from: request)
            
            do {
                print("[BackendService] Attempt \(attempt)/\(maxRetries) on \(activeBaseURL): \(activeRequest.httpMethod ?? "GET") \(activeRequest.url?.path ?? "")")
                
                let (data, response) = try await session.data(for: activeRequest)
                
                // Check for successful response
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode < 400 {
                        print("[BackendService] ✅ Request successful on \(activeBaseURL)")
                        return (data, response)
                    } else {
                        print("[BackendService] ❌ HTTP error \(httpResponse.statusCode) on \(activeBaseURL)")
                        lastError = BackendError.httpError(httpResponse.statusCode)
                    }
                }
                
            } catch {
                lastError = error
                print("[BackendService] ❌ Network error on \(activeBaseURL): \(error.localizedDescription)")
                
                // Check if this looks like a connectivity issue
                if isConnectivityError(error) {
                    print("[BackendService] 🔄 Connectivity issue detected, trying endpoint fallback...")
                    
                    // Try next endpoint
                    if await tryNextEndpoint() {
                        print("[BackendService] ✅ Switched to working endpoint, retrying request...")
                        continue  // Retry with new endpoint
                    }
                }
                
                // Don't retry on the last attempt
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = Double(attempt) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? BackendError.allEndpointsUnavailable
    }
    
    /**
     * Create a new request with the current active base URL
     */
    private func createRequestWithActiveURL(from originalRequest: URLRequest) -> URLRequest {
        guard let originalURL = originalRequest.url,
              let originalPath = originalURL.path.isEmpty ? nil : originalURL.path else {
            return originalRequest
        }
        
        // Extract the path from the original URL and combine with active base URL
        let newURLString = activeBaseURL + originalPath + (originalURL.query.map { "?\($0)" } ?? "")
        
        guard let newURL = URL(string: newURLString) else {
            return originalRequest
        }
        
        var newRequest = originalRequest
        newRequest.url = newURL
        return newRequest
    }
    
    /**
     * Check if error indicates connectivity issue
     */
    private func isConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Common connectivity error codes
        let connectivityCodes = [
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorResourceUnavailable,
            NSURLErrorBadServerResponse
        ]
        
        return connectivityCodes.contains(nsError.code)
    }
}

// MARK: - Response Models

/**
 * Spotify token response from backend
 */
struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case expiresAt = "expires_at"
    }
    
    /**
     * Convert expires_at ISO string to Date
     */
    var expirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: expiresAt)
    }
    
    /**
     * Check if token is expired or expiring soon (within 5 minutes)
     */
    var isExpiredOrExpiring: Bool {
        guard let expiration = expirationDate else { return true }
        let fiveMinutesFromNow = Date().addingTimeInterval(300)
        return expiration <= fiveMinutesFromNow
    }
}

// MARK: - Error Types

/**
 * Backend service specific errors
 */
enum BackendError: Error, LocalizedError {
    case networkError(Error)
    case httpError(Int, String = "")
    case noTokensFound
    case invalidResponse
    case allEndpointsUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .noTokensFound:
            return "No Spotify tokens found for this device"
        case .invalidResponse:
            return "Invalid response from backend"
        case .allEndpointsUnavailable:
            return "All backend endpoints are unavailable"
        case .unknown:
            return "Unknown backend error"
        }
    }
    
    /**
     * Check if error indicates backend is offline/unreachable
     */
    var isNetworkUnavailable: Bool {
        switch self {
        case .networkError(let error):
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain &&
                   (nsError.code == NSURLErrorNotConnectedToInternet ||
                    nsError.code == NSURLErrorTimedOut ||
                    nsError.code == NSURLErrorCannotConnectToHost)
        case .httpError(let code, _):
            return code >= 500 // Server errors indicate backend issues
        default:
            return false
        }
    }
}