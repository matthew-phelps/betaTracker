//
//  ProfileSelectorView.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import SwiftUI

/// Compact profile selector for quick switching
struct ProfileSelectorView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var dataManager = ActivityDataManager()
    @Binding var showingProfileManagement: Bool

    var body: some View {
        HStack(spacing: 15) {
            // Profile icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                if let profile = profileManager.currentProfile {
                    Text(profile.name)
                        .font(.headline)

                    if profile.hasCachedData(), let lastSync = profile.lastSyncedAt {
                        Text("Last synced: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No Profile")
                        .font(.headline)
                    Text("Tap to create one")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quick switch menu
            Menu {
                if !profileManager.profiles.isEmpty {
                    ForEach(profileManager.profiles) { profile in
                        Button(action: {
                            switchToProfile(profile)
                        }) {
                            HStack {
                                Text(profile.name)
                                if profileManager.currentProfile?.id == profile.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()
                }

                Button(action: {
                    showingProfileManagement = true
                }) {
                    Label("Manage Profiles", systemImage: "person.2")
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private func switchToProfile(_ profile: UserProfile) {
        profileManager.setCurrentProfile(profile)
        dataManager.reloadForCurrentProfile()
    }
}
