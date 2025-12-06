//
//  ActivityDataManager.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation
import Combine

/// Manager for caching and retrieving Strava activities
@MainActor
class ActivityDataManager: ObservableObject {
    @Published var activities: [StravaActivity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let cacheKey = "cachedStravaActivities"
    private let cacheTimestampKey = "activitiesCacheTimestamp"
    private var isFetching = false // Prevent concurrent fetches

    // Cached weekly totals for performance
    private var weeklyTotalsCache: [Date: Double] = [:]

    init() {
        loadCachedActivities()
        buildWeeklyTotalsCache()
    }

    /// Fetch activities from Strava and cache them
    func fetchActivities(accessToken: String) async {
        // Prevent multiple simultaneous fetches
        guard !isFetching else {
            print("DEBUG: Fetch already in progress, skipping")
            return
        }

        // Validate token before making API call
        guard !accessToken.isEmpty else {
            errorMessage = "Access token is empty. Please enter your Strava token."
            return
        }

        isFetching = true
        isLoading = true
        errorMessage = nil

        print("DEBUG: Starting activity fetch...")

        do {
            let fetchedActivities = try await StravaAPIService.shared.fetchAllActivities(accessToken: accessToken)

            // Filter for cycling activities only
            activities = fetchedActivities.filter { $0.isCyclingActivity }

            // Cache the activities
            cacheActivities()

            // Rebuild weekly totals cache
            buildWeeklyTotalsCache()

            print("DEBUG: Successfully fetched and cached \(activities.count) cycling activities")

            isLoading = false
            isFetching = false
        } catch let error as StravaAPIError {
            errorMessage = error.errorDescription
            isLoading = false
            isFetching = false
            print("ERROR: Fetch failed with StravaAPIError: \(error.errorDescription ?? "unknown")")
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            isLoading = false
            isFetching = false
            print("ERROR: Fetch failed with error: \(error.localizedDescription)")
        }
    }

    /// Get cycling activities for a specific week
    func activitiesForWeek(startDate: Date) -> [StravaActivity] {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: startDate) else {
            return []
        }

        return activities.filter { activity in
            activity.localDate >= startDate && activity.localDate < weekEnd
        }
    }

    /// Get total distance for a week (in km) - uses cache for performance
    func totalDistanceForWeek(startDate: Date) -> Double {
        // Use cached value if available
        if let cachedDistance = weeklyTotalsCache[startDate] {
            return cachedDistance
        }

        // Calculate and cache if not found
        let distance = activitiesForWeek(startDate: startDate)
            .reduce(0) { $0 + $1.distanceKm }

        weeklyTotalsCache[startDate] = distance
        return distance
    }

    /// Get daily distances for a week
    func dailyDistancesForWeek(startDate: Date) -> [(date: Date, distance: Double)] {
        let calendar = Calendar.current
        var dailyDistances: [(date: Date, distance: Double)] = []

        for dayOffset in 0..<7 {
            guard let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: currentDay)
            let distanceForDay = activities
                .filter { $0.localDate == dayStart }
                .reduce(0) { $0 + $1.distanceKm }

            dailyDistances.append((date: dayStart, distance: distanceForDay))
        }

        return dailyDistances
    }

    /// Get the date of the first activity
    func firstActivityDate() -> Date? {
        activities
            .map { $0.localDate }
            .min()
    }

    // MARK: - Caching

    private func cacheActivities() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(activities)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        } catch {
            print("Failed to cache activities: \(error)")
        }
    }

    private func loadCachedActivities() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            activities = try decoder.decode([StravaActivity].self, from: data)
        } catch {
            print("Failed to load cached activities: \(error)")
        }
    }

    /// Get the last cache timestamp
    func lastCacheDate() -> Date? {
        UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date
    }

    // MARK: - Performance Optimization

    /// Build cache of weekly totals for fast lookups
    private func buildWeeklyTotalsCache() {
        weeklyTotalsCache.removeAll()

        // Group activities by week
        let calendar = Calendar.current
        var weeklyGroups: [Date: [StravaActivity]] = [:]

        for activity in activities {
            let weekStart = activity.localDate.startOfWeek()
            weeklyGroups[weekStart, default: []].append(activity)
        }

        // Calculate totals for each week
        for (weekStart, weekActivities) in weeklyGroups {
            let totalDistance = weekActivities.reduce(0) { $0 + $1.distanceKm }
            weeklyTotalsCache[weekStart] = totalDistance
        }

        print("DEBUG: Built weekly cache with \(weeklyTotalsCache.count) weeks")
    }
}
