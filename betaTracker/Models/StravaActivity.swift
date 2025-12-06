//
//  StravaActivity.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation

/// Represents a Strava activity
struct StravaActivity: Codable, Identifiable {
    let id: Int
    let name: String
    let distance: Double // in meters
    let movingTime: Int // in seconds
    let elapsedTime: Int // in seconds
    let totalElevationGain: Double // in meters
    let type: String // "Ride", "VirtualRide", "EBikeRide", etc.
    let startDate: Date
    let startDateLocal: String
    let timezone: String?
    let averageSpeed: Double? // in meters/second
    let maxSpeed: Double? // in meters/second

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case type
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
        case timezone
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
    }

    /// Check if this is a cycling activity
    var isCyclingActivity: Bool {
        ["Ride", "VirtualRide", "EBikeRide"].contains(type)
    }

    /// Distance in kilometers
    var distanceKm: Double {
        distance / 1000.0
    }

    /// Get the local date (without time) for grouping by day
    var localDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        // Parse the local date string (format: "2024-12-06T10:30:00Z")
        if let date = ISO8601DateFormatter().date(from: startDateLocal) {
            let calendar = Calendar.current
            return calendar.startOfDay(for: date)
        }

        // Fallback to startDate
        let calendar = Calendar.current
        return calendar.startOfDay(for: startDate)
    }
}

/// Response from Strava API athlete activities endpoint
struct StravaActivitiesResponse: Codable {
    let activities: [StravaActivity]
}
