//
//  ProfileEditorView.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import SwiftUI

/// View for creating or editing a profile
struct ProfileEditorView: View {
    enum Mode {
        case create
        case edit(UserProfile)

        var title: String {
            switch self {
            case .create: return "New Profile"
            case .edit: return "Edit Profile"
            }
        }
    }

    @Environment(\.dismiss) var dismiss
    @StateObject private var profileManager = ProfileManager.shared

    let mode: Mode

    @State private var name: String = ""
    @State private var clientID: String = ""
    @State private var clientSecret: String = ""
    @State private var showingSaveError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Matthew, Partner, etc.", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .autocapitalization(.words)
                            #endif
                    }
                }

                Section(header: Text("Strava API Credentials")) {
                    Text("Each person needs their own Strava API application. Get credentials from:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("Strava API Settings", destination: URL(string: "https://www.strava.com/settings/api")!)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter Client ID", text: $clientID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter Client Secret", text: $clientSecret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .disableAutocorrection(true)
                    }
                }

                Section(header: Text("Instructions")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Each person creates their own API app on Strava")
                        Text("2. Set Authorization Callback Domain to: localhost")
                        Text("3. Copy Client ID and Client Secret")
                        Text("4. Paste them here")
                        Text("5. Connect to Strava to sync activities")
                        Text("6. Disconnect when done to avoid athlete limits")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 500, minHeight: 600)
            .navigationTitle(mode.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadProfile()
            }
            .alert("Error", isPresented: $showingSaveError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 700)
        #endif
    }

    private var isValid: Bool {
        !name.isEmpty && !clientID.isEmpty && !clientSecret.isEmpty
    }

    private func loadProfile() {
        if case .edit(let profile) = mode {
            name = profile.name
            clientID = profile.clientID
            clientSecret = profile.clientSecret
        }
    }

    private func saveProfile() {
        switch mode {
        case .create:
            let profile = profileManager.createProfile(
                name: name,
                clientID: clientID,
                clientSecret: clientSecret
            )
            dismiss()

        case .edit(let existingProfile):
            var updatedProfile = existingProfile
            updatedProfile.name = name
            updatedProfile.clientID = clientID
            updatedProfile.clientSecret = clientSecret
            profileManager.updateProfile(updatedProfile)
            dismiss()
        }
    }
}

#Preview {
    ProfileEditorView(mode: .create)
}
