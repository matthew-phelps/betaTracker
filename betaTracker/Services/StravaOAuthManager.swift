//
//  StravaOAuthManager.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation
import SwiftUI
import Combine

/// Manager for Strava OAuth authentication flow
@MainActor
class StravaOAuthManager: ObservableObject {
    static let shared = StravaOAuthManager()

    // Strava OAuth credentials
    private let clientID = "188741"
    private let clientSecret = "7b31247cf6e16cfd134406b4db458e2a31e26e01"
    private let redirectURI = "http://localhost:8080/callback"

    // Local server for OAuth callback
    private var localServer: LocalOAuthServer?

    // Token storage keys
    private let accessTokenKey = "stravaAccessToken"
    private let refreshTokenKey = "stravaRefreshToken"
    private let tokenExpirationKey = "stravaTokenExpiration"

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false

    private init() {
        checkAuthenticationStatus()
    }

    /// Check if user is currently authenticated
    func checkAuthenticationStatus() {
        if let token = getAccessToken(), !token.isEmpty {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }

    /// Start OAuth authorization flow
    func authorize() {
        guard let authURL = buildAuthorizationURL() else {
            print("ERROR: Failed to build authorization URL")
            return
        }

        print("DEBUG: Starting local server on port 8080...")

        // Start local server to catch OAuth callback
        localServer = LocalOAuthServer(port: 8080) { [weak self] code in
            Task { @MainActor in
                guard let self = self else { return }
                print("DEBUG: Received authorization code from local server")
                await self.completeAuthorization(code: code)
            }
        }

        localServer?.start()

        print("DEBUG: Opening authorization URL: \(authURL.absoluteString)")

        #if os(macOS)
        NSWorkspace.shared.open(authURL)
        #else
        UIApplication.shared.open(authURL)
        #endif

        isAuthenticating = true
    }

    /// Complete the authorization with the received code
    private func completeAuthorization(code: String) async {
        do {
            try await exchangeCodeForToken(code: code)
            isAuthenticated = true
            isAuthenticating = false
            localServer?.stop()
            localServer = nil
            print("DEBUG: Successfully authenticated!")
        } catch {
            print("ERROR: Failed to exchange code for token: \(error)")
            isAuthenticating = false
            localServer?.stop()
            localServer = nil
        }
    }

    /// Build the OAuth authorization URL
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all")
        ]
        return components?.url
    }

    /// Handle the OAuth callback with authorization code
    func handleCallback(url: URL) async {
        print("DEBUG: Handling callback URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("ERROR: No authorization code found in callback URL")
            isAuthenticating = false
            return
        }

        print("DEBUG: Got authorization code, exchanging for token...")

        do {
            try await exchangeCodeForToken(code: code)
            isAuthenticated = true
            isAuthenticating = false
            print("DEBUG: Successfully authenticated!")
        } catch {
            print("ERROR: Failed to exchange code for token: \(error)")
            isAuthenticating = false
        }
    }

    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String) async throws {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        print("DEBUG: Token exchange response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("ERROR: Token exchange failed: \(errorString)")
            }
            throw OAuthError.tokenExchangeFailed(statusCode: httpResponse.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        print("DEBUG: Received tokens - access: \(tokenResponse.accessToken.prefix(10))..., refresh: \(tokenResponse.refreshToken.prefix(10))...")
        print("DEBUG: Token expires at: \(Date(timeIntervalSince1970: TimeInterval(tokenResponse.expiresAt)))")

        // Store tokens
        UserDefaults.standard.set(tokenResponse.accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(tokenResponse.refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(tokenResponse.expiresAt, forKey: tokenExpirationKey)
    }

    /// Get current access token, refreshing if needed
    func getAccessToken() -> String? {
        // Check if token is expired
        if isTokenExpired() {
            print("DEBUG: Token is expired, needs refresh")
            return nil
        }

        return UserDefaults.standard.string(forKey: accessTokenKey)
    }

    /// Get access token, refreshing automatically if expired
    func getValidAccessToken() async throws -> String {
        if isTokenExpired() {
            print("DEBUG: Token expired, refreshing...")
            try await refreshAccessToken()
        }

        guard let token = UserDefaults.standard.string(forKey: accessTokenKey) else {
            throw OAuthError.noTokenAvailable
        }

        return token
    }

    /// Check if the current token is expired
    private func isTokenExpired() -> Bool {
        guard let expiresAt = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Int else {
            return true
        }

        let expirationDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
        // Add 5 minute buffer to refresh before actual expiration
        return Date().addingTimeInterval(300) >= expirationDate
    }

    /// Refresh the access token using refresh token
    func refreshAccessToken() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            throw OAuthError.noRefreshToken
        }

        print("DEBUG: Refreshing access token...")

        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("ERROR: Token refresh failed: \(errorString)")
            }
            throw OAuthError.tokenRefreshFailed(statusCode: httpResponse.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        print("DEBUG: Token refreshed successfully")

        // Update tokens
        UserDefaults.standard.set(tokenResponse.accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(tokenResponse.refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(tokenResponse.expiresAt, forKey: tokenExpirationKey)
    }

    /// Disconnect/logout
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
        isAuthenticated = false
        print("DEBUG: Disconnected from Strava")
    }
}

// MARK: - Response Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

// MARK: - OAuth Errors

enum OAuthError: LocalizedError {
    case invalidResponse
    case tokenExchangeFailed(statusCode: Int)
    case tokenRefreshFailed(statusCode: Int)
    case noTokenAvailable
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .tokenExchangeFailed(let code):
            return "Failed to get access token (status: \(code))"
        case .tokenRefreshFailed(let code):
            return "Failed to refresh token (status: \(code))"
        case .noTokenAvailable:
            return "No access token available. Please connect to Strava."
        case .noRefreshToken:
            return "No refresh token available. Please reconnect to Strava."
        }
    }
}
