//
//  UserProfile.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation

/// Represents a user profile with Strava credentials and cached data
struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var clientID: String
    var clientSecret: String
    var createdAt: Date
    var lastSyncedAt: Date?

    init(id: UUID = UUID(), name: String, clientID: String, clientSecret: String) {
        self.id = id
        self.name = name
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.createdAt = Date()
        self.lastSyncedAt = nil
    }

    /// Check if this profile has cached activity data
    func hasCachedData() -> Bool {
        let cacheKey = "cachedStravaActivities_\(id.uuidString)"
        return UserDefaults.standard.data(forKey: cacheKey) != nil
    }

    /// Get the cache timestamp for this profile
    func getCacheTimestamp() -> Date? {
        let timestampKey = "activitiesCacheTimestamp_\(id.uuidString)"
        return UserDefaults.standard.object(forKey: timestampKey) as? Date
    }

    /// Clear this profile's cached data
    func clearCache() {
        let cacheKey = "cachedStravaActivities_\(id.uuidString)"
        let timestampKey = "activitiesCacheTimestamp_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }

    // Token storage keys for this profile
    var accessTokenKey: String { "stravaAccessToken_\(id.uuidString)" }
    var refreshTokenKey: String { "stravaRefreshToken_\(id.uuidString)" }
    var tokenExpirationKey: String { "stravaTokenExpiration_\(id.uuidString)" }

    /// Check if this profile has stored tokens
    func hasTokens() -> Bool {
        return UserDefaults.standard.string(forKey: accessTokenKey) != nil
    }

    /// Clear this profile's stored tokens
    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
    }
}
