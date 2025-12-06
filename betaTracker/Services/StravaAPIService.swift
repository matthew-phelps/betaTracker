//
//  StravaAPIService.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation

/// Service for interacting with Strava API
class StravaAPIService {
    static let shared = StravaAPIService()

    private let baseURL = "https://www.strava.com/api/v3"
    private let perPage = 200 // Maximum allowed by Strava API

    private init() {}

    /// Fetch all activities from Strava API with pagination
    /// - Parameter accessToken: The Strava access token
    /// - Returns: Array of all activities
    func fetchAllActivities(accessToken: String) async throws -> [StravaActivity] {
        var allActivities: [StravaActivity] = []
        var page = 1
        var hasMoreData = true

        while hasMoreData {
            let activities = try await fetchActivitiesPage(
                accessToken: accessToken,
                page: page,
                perPage: perPage
            )

            allActivities.append(contentsOf: activities)

            // If we got fewer activities than perPage, we've reached the end
            hasMoreData = activities.count == perPage
            page += 1

            // Add a small delay to avoid rate limiting
            if hasMoreData {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        return allActivities
    }

    /// Fetch a single page of activities
    private func fetchActivitiesPage(
        accessToken: String,
        page: Int,
        perPage: Int
    ) async throws -> [StravaActivity] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/athlete/activities") else {
            print("ERROR: Failed to create URLComponents from: \(baseURL)/athlete/activities")
            throw StravaAPIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]

        guard let url = urlComponents.url else {
            print("ERROR: Failed to create URL from components")
            throw StravaAPIError.invalidURL
        }

        print("DEBUG: Fetching page \(page) from URL: \(url.absoluteString)")
        print("DEBUG: Access token length: \(accessToken.count) characters")
        print("DEBUG: Access token starts with: \(String(accessToken.prefix(10)))...")
        print("DEBUG: Access token ends with: ...\(String(accessToken.suffix(10)))")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("DEBUG: Received response with \(data.count) bytes")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Response is not HTTPURLResponse")
                throw StravaAPIError.invalidResponse
            }

            print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                // Print the error response body to see what Strava says
                if let errorString = String(data: data, encoding: .utf8) {
                    print("ERROR: Strava response body: \(errorString)")
                }

                if httpResponse.statusCode == 401 {
                    throw StravaAPIError.unauthorized
                }
                throw StravaAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let activities = try decoder.decode([StravaActivity].self, from: data)
                print("DEBUG: Successfully decoded \(activities.count) activities")
                return activities
            } catch {
                print("ERROR: Decoding error: \(error)")
                throw StravaAPIError.decodingError(error)
            }
        } catch let error as URLError {
            print("ERROR: URLError occurred: \(error.localizedDescription)")
            print("ERROR: URLError code: \(error.code.rawValue)")
            throw StravaAPIError.networkError(error)
        } catch {
            print("ERROR: Unexpected error: \(error)")
            throw error
        }
    }
}

/// Errors that can occur when interacting with Strava API
enum StravaAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(URLError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please check your access token."
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
