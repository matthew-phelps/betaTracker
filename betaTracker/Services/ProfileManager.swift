//
//  ProfileManager.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation
import Combine

/// Manager for user profiles and profile switching
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [UserProfile] = []
    @Published var currentProfile: UserProfile?

    private let profilesKey = "userProfiles"
    private let currentProfileIDKey = "currentProfileID"

    private init() {
        loadProfiles()
        loadCurrentProfile()
    }

    // MARK: - Profile Management

    /// Create a new profile
    func createProfile(name: String, clientID: String, clientSecret: String) -> UserProfile {
        let profile = UserProfile(name: name, clientID: clientID, clientSecret: clientSecret)
        profiles.append(profile)
        saveProfiles()

        // Set as current profile if it's the first one
        if currentProfile == nil {
            setCurrentProfile(profile)
        }

        print("DEBUG: Created profile: \(profile.name) (ID: \(profile.id))")
        return profile
    }

    /// Update an existing profile
    func updateProfile(_ profile: UserProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()

            // Update current profile if it's the one being edited
            if currentProfile?.id == profile.id {
                currentProfile = profile
                saveCurrentProfileID()
            }

            print("DEBUG: Updated profile: \(profile.name)")
        }
    }

    /// Delete a profile and all its associated data
    func deleteProfile(_ profile: UserProfile) {
        // Clear all data for this profile
        profile.clearCache()
        profile.clearTokens()

        // Remove from list
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()

        // If this was the current profile, switch to another or clear
        if currentProfile?.id == profile.id {
            currentProfile = profiles.first
            saveCurrentProfileID()
        }

        print("DEBUG: Deleted profile: \(profile.name)")
    }

    /// Switch to a different profile
    func setCurrentProfile(_ profile: UserProfile) {
        currentProfile = profile
        saveCurrentProfileID()
        print("DEBUG: Switched to profile: \(profile.name)")
    }

    /// Update the last synced timestamp for current profile
    func updateLastSyncedTimestamp() {
        guard var profile = currentProfile else { return }
        profile.lastSyncedAt = Date()
        updateProfile(profile)
    }

    // MARK: - Persistence

    private func saveProfiles() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profiles)
            UserDefaults.standard.set(data, forKey: profilesKey)
        } catch {
            print("ERROR: Failed to save profiles: \(error)")
        }
    }

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            profiles = try decoder.decode([UserProfile].self, from: data)
            print("DEBUG: Loaded \(profiles.count) profiles")
        } catch {
            print("ERROR: Failed to load profiles: \(error)")
        }
    }

    private func saveCurrentProfileID() {
        if let profileID = currentProfile?.id {
            UserDefaults.standard.set(profileID.uuidString, forKey: currentProfileIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentProfileIDKey)
        }
    }

    private func loadCurrentProfile() {
        guard let profileIDString = UserDefaults.standard.string(forKey: currentProfileIDKey),
              let profileID = UUID(uuidString: profileIDString) else {
            // No saved current profile, use first available
            currentProfile = profiles.first
            return
        }

        currentProfile = profiles.first { $0.id == profileID }

        // If saved profile no longer exists, use first available
        if currentProfile == nil {
            currentProfile = profiles.first
        }

        if let profile = currentProfile {
            print("DEBUG: Loaded current profile: \(profile.name)")
        }
    }
}
