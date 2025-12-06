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
    @Published var availableActivityTypes: [String] = []

    private var cacheKey: String {
        guard let profileID = ProfileManager.shared.currentProfile?.id.uuidString else {
            return "cachedStravaActivities_default"
        }
        return "cachedStravaActivities_\(profileID)"
    }

    private var cacheTimestampKey: String {
        guard let profileID = ProfileManager.shared.currentProfile?.id.uuidString else {
            return "activitiesCacheTimestamp_default"
        }
        return "activitiesCacheTimestamp_\(profileID)"
    }

    private var isFetching = false // Prevent concurrent fetches

    // Cached weekly totals for performance, keyed by activity type
    private var weeklyTotalsCache: [String: [Date: Double]] = [:]

    init() {
        loadCachedActivities()
        updateAvailableActivityTypes()
        buildWeeklyTotalsCache()
    }

    /// Reload data for the current profile (call when switching profiles)
    func reloadForCurrentProfile() {
        loadCachedActivities()
        updateAvailableActivityTypes()
        buildWeeklyTotalsCache()
        print("DEBUG: Reloaded data for current profile - \(activities.count) activities")
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

            // Store all activities (no filtering by type)
            activities = fetchedActivities

            // Cache the activities
            cacheActivities()

            // Update available activity types
            updateAvailableActivityTypes()

            // Rebuild weekly totals cache
            buildWeeklyTotalsCache()

            // Update profile's last synced timestamp
            ProfileManager.shared.updateLastSyncedTimestamp()

            print("DEBUG: Successfully fetched and cached \(activities.count) activities")

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

    /// Get activities for a specific week, optionally filtered by activity type
    func activitiesForWeek(startDate: Date, activityType: String? = nil) -> [StravaActivity] {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: startDate) else {
            return []
        }

        return activities.filter { activity in
            let dateMatch = activity.localDate >= startDate && activity.localDate < weekEnd
            let typeMatch = activityType == nil || activity.type == activityType
            return dateMatch && typeMatch
        }
    }

    /// Get total distance for a week (in km) - uses cache for performance
    func totalDistanceForWeek(startDate: Date, activityType: String? = nil) -> Double {
        let cacheKey = activityType ?? "all"

        // Use cached value if available
        if let cachedDistance = weeklyTotalsCache[cacheKey]?[startDate] {
            return cachedDistance
        }

        // Calculate and cache if not found
        let distance = activitiesForWeek(startDate: startDate, activityType: activityType)
            .reduce(0) { $0 + $1.distanceKm }

        if weeklyTotalsCache[cacheKey] == nil {
            weeklyTotalsCache[cacheKey] = [:]
        }
        weeklyTotalsCache[cacheKey]?[startDate] = distance
        return distance
    }

    /// Get daily distances for a week, optionally filtered by activity type
    func dailyDistancesForWeek(startDate: Date, activityType: String? = nil) -> [(date: Date, distance: Double)] {
        let calendar = Calendar.current
        var dailyDistances: [(date: Date, distance: Double)] = []

        for dayOffset in 0..<7 {
            guard let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: currentDay)
            let distanceForDay = activities
                .filter { activity in
                    let dateMatch = activity.localDate == dayStart
                    let typeMatch = activityType == nil || activity.type == activityType
                    return dateMatch && typeMatch
                }
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

    /// Clear all cached data for the current user
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        activities = []
        availableActivityTypes = []
        weeklyTotalsCache.removeAll()
        print("DEBUG: Cleared cache for current user")
    }

    // MARK: - Performance Optimization

    /// Update the list of available activity types from the data
    private func updateAvailableActivityTypes() {
        let types = Set(activities.map { $0.type })
        availableActivityTypes = Array(types).sorted()
        print("DEBUG: Found \(availableActivityTypes.count) activity types: \(availableActivityTypes)")
    }

    /// Build cache of weekly totals for fast lookups
    private func buildWeeklyTotalsCache() {
        weeklyTotalsCache.removeAll()

        let calendar = Calendar.current

        // Build cache for "all" activities
        var allWeeklyGroups: [Date: [StravaActivity]] = [:]
        for activity in activities {
            let weekStart = activity.localDate.startOfWeek()
            allWeeklyGroups[weekStart, default: []].append(activity)
        }

        weeklyTotalsCache["all"] = [:]
        for (weekStart, weekActivities) in allWeeklyGroups {
            let totalDistance = weekActivities.reduce(0) { $0 + $1.distanceKm }
            weeklyTotalsCache["all"]?[weekStart] = totalDistance
        }

        // Build cache for each activity type
        for activityType in availableActivityTypes {
            var weeklyGroups: [Date: [StravaActivity]] = [:]

            for activity in activities where activity.type == activityType {
                let weekStart = activity.localDate.startOfWeek()
                weeklyGroups[weekStart, default: []].append(activity)
            }

            weeklyTotalsCache[activityType] = [:]
            for (weekStart, weekActivities) in weeklyGroups {
                let totalDistance = weekActivities.reduce(0) { $0 + $1.distanceKm }
                weeklyTotalsCache[activityType]?[weekStart] = totalDistance
            }
        }

        print("DEBUG: Built weekly cache for \(weeklyTotalsCache.keys.count) activity types")
    }

    // MARK: - Daily and Rolling Calculations

    /// Get daily distance totals sorted by date, optionally filtered by activity type
    func getDailyTotals(activityType: String? = nil) -> [(date: Date, distance: Double)] {
        var dailyGroups: [Date: Double] = [:]

        // Sum distances for each day
        for activity in activities {
            if activityType == nil || activity.type == activityType {
                dailyGroups[activity.localDate, default: 0] += activity.distanceKm
            }
        }

        // Convert to array and sort by date
        return dailyGroups
            .map { (date: $0.key, distance: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Calculate rolling 12-month totals for the specified number of days, optionally filtered by activity type
    func getRolling12MonthTotals(days: Int, activityType: String? = nil) -> [(date: Date, total: Double)] {
        let dailyTotals = getDailyTotals(activityType: activityType)
        guard !dailyTotals.isEmpty else { return [] }

        let calendar = Calendar.current
        var result: [(date: Date, total: Double)] = []

        // Get the most recent date
        guard let mostRecentDate = dailyTotals.last?.date else { return [] }

        // Calculate rolling totals for the last N days
        let startDate = calendar.date(byAdding: .day, value: -days, to: mostRecentDate) ?? mostRecentDate

        // Create a date lookup for daily totals
        var dailyLookup: [Date: Double] = [:]
        for item in dailyTotals {
            dailyLookup[item.date] = item.distance
        }

        // For each day in range, calculate 12-month rolling sum
        var currentDate = startDate
        while currentDate <= mostRecentDate {
            // Get date 12 months ago
            guard let twelveMonthsAgo = calendar.date(byAdding: .day, value: -365, to: currentDate) else {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }

            // Sum all distances in the 365-day window
            var rollingSum = 0.0
            var checkDate = twelveMonthsAgo
            while checkDate <= currentDate {
                if let distance = dailyLookup[checkDate] {
                    rollingSum += distance
                }
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
                checkDate = nextDate
            }

            result.append((date: currentDate, total: rollingSum))

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return result
    }
}
