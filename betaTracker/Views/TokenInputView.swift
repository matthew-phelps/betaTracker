//
//  TokenInputView.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import SwiftUI

/// View for connecting to Strava via OAuth
struct TokenInputView: View {
    @Binding var accessToken: String
    @StateObject private var oauthManager = StravaOAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Strava logo/icon
                Image(systemName: "bicycle.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)

                Text("Connect to Strava")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Authorize this app to access your Strava cycling activities")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 20) {
                    if oauthManager.isAuthenticating {
                        // Authenticating state
                        VStack(spacing: 15) {
                            ProgressView()
                            Text("Waiting for authorization...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Please authorize in your browser")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if oauthManager.isAuthenticated {
                        // Already authenticated
                        VStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)

                            Text("Connected to Strava!")
                                .font(.headline)

                            Button(action: {
                                if let token = oauthManager.getAccessToken() {
                                    accessToken = token
                                }
                                dismiss()
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 300)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                oauthManager.disconnect()
                            }) {
                                Text("Disconnect")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        // Not authenticated - show connect button
                        Button(action: {
                            oauthManager.authorize()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Connect to Strava")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("You'll be redirected to Strava to authorize this app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()
                Spacer()
            }
            .frame(minWidth: 400, minHeight: 500)
            .navigationTitle("Setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                oauthManager.checkAuthenticationStatus()
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
    }
}

#Preview {
    TokenInputView(accessToken: .constant(""))
}
