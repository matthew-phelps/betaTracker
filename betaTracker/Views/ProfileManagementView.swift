//
//  ProfileManagementView.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import SwiftUI

/// View for managing user profiles
struct ProfileManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    @State private var showingAddProfile = false
    @State private var showingEditProfile: UserProfile?
    @State private var showingDeleteConfirmation: UserProfile?

    var body: some View {
        NavigationView {
            List {
                if profileManager.profiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Profiles")
                            .font(.headline)
                        Text("Create a profile to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(profileManager.profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isCurrent: profileManager.currentProfile?.id == profile.id,
                            onSelect: {
                                profileManager.setCurrentProfile(profile)
                            },
                            onEdit: {
                                showingEditProfile = profile
                            },
                            onDelete: {
                                showingDeleteConfirmation = profile
                            }
                        )
                    }
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddProfile = true
                    }) {
                        Label("Add Profile", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProfile) {
                ProfileEditorView(mode: .create)
            }
            .sheet(item: $showingEditProfile) { profile in
                ProfileEditorView(mode: .edit(profile))
            }
            .alert("Delete Profile", isPresented: .constant(showingDeleteConfirmation != nil), presenting: showingDeleteConfirmation) { profile in
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirmation = nil
                }
                Button("Delete", role: .destructive) {
                    profileManager.deleteProfile(profile)
                    showingDeleteConfirmation = nil
                }
            } message: { profile in
                Text("Are you sure you want to delete \(profile.name)? This will remove all cached data and cannot be undone.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 500)
        #endif
    }
}

/// Row view for a single profile
struct ProfileRow: View {
    let profile: UserProfile
    let isCurrent: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            // Profile icon
            Image(systemName: isCurrent ? "person.circle.fill" : "person.circle")
                .font(.system(size: 40))
                .foregroundColor(isCurrent ? .blue : .gray)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    if isCurrent {
                        Text("(Current)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if profile.hasCachedData(), let lastSync = profile.getCacheTimestamp() {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No cached data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: profile.hasTokens() ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.caption)
                        .foregroundColor(profile.hasTokens() ? .green : .red)
                    Text(profile.hasTokens() ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons
            Menu {
                if !isCurrent {
                    Button(action: onSelect) {
                        Label("Switch to Profile", systemImage: "arrow.right.circle")
                    }
                }

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                if profile.hasCachedData() {
                    Button(role: .destructive, action: {
                        profile.clearCache()
                    }) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Profile", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCurrent {
                onSelect()
            }
        }
    }
}

#Preview {
    ProfileManagementView()
}
