//
//  WeeklyDistanceView.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import SwiftUI
import Charts

/// Main view showing weekly cycling distance and statistics
struct WeeklyDistanceView: View {
    @StateObject private var dataManager = ActivityDataManager()
    @StateObject private var oauthManager = StravaOAuthManager.shared
    @State private var accessToken: String = ""
    @State private var showingTokenInput = false
    @State private var currentWeekStart: Date = Date().startOfWeek()
    @State private var hasAttemptedInitialFetch = false
    @State private var numberOfWeeks = 10 // Number of weeks to display in chart
    @State private var rollingDays = 365 // Number of days to show in rolling chart
    @State private var selectedActivityType: String? = nil // nil means "all activities"

    // Cache current week to avoid recalculation
    private let currentWeek = Date().startOfWeek()

    var body: some View {
        NavigationView {
            Group {
                if dataManager.isLoading {
                    VStack {
                        ProgressView("Loading activities...")
                            .padding()
                        Text("This may take a moment for large activity histories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage = dataManager.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await dataManager.fetchActivities(accessToken: accessToken)
                            }
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                    }
                    .padding()
                } else if dataManager.activities.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("No activities yet")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Pull to refresh or tap the refresh button to load your Strava activities")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    weeklyStatsView
                }
            }
            .navigationTitle("Strava Tracker")
            .toolbar {
                toolbarMenu
            }
            .sheet(isPresented: $showingTokenInput) {
                TokenInputView(accessToken: $accessToken)
            }
            .onAppear {
                // Check OAuth authentication status
                oauthManager.checkAuthenticationStatus()

                // Only attempt initial fetch once
                guard !hasAttemptedInitialFetch else { return }
                hasAttemptedInitialFetch = true

                if !oauthManager.isAuthenticated {
                    showingTokenInput = true
                } else if dataManager.activities.isEmpty {
                    Task {
                        if let token = try? await oauthManager.getValidAccessToken() {
                            accessToken = token
                            await dataManager.fetchActivities(accessToken: token)
                        }
                    }
                }
            }
            .onChange(of: oauthManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated, dataManager.activities.isEmpty {
                    Task {
                        if let token = try? await oauthManager.getValidAccessToken() {
                            accessToken = token
                            await dataManager.fetchActivities(accessToken: token)
                        }
                    }
                }
            }
        }
    }

    private var weeklyStatsView: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Week navigation
                weekNavigationView

                // Activity type selector
                if !dataManager.availableActivityTypes.isEmpty {
                    activityTypeSelector
                }

                // Total distance display
                totalDistanceCard

                // Number of rides
                rideCountCard

                // Weekly distances chart
                dailyDistanceChart

                // Rolling 12-month chart
                rolling12MonthChart

                // Last updated timestamp
                if let lastUpdate = dataManager.lastCacheDate() {
                    Text("Last updated: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    private var weekNavigationView: some View {
        VStack(spacing: 10) {
            Text(weekDateRange)
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                Button(action: previousWeek) {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!canGoToPreviousWeek())

                Button(action: nextWeek) {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!canGoToNextWeek())

                Button(action: goToCurrentWeek) {
                    Text("Today")
                }
                .buttonStyle(BorderedProminentButtonStyle())
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var activityTypeSelector: some View {
        VStack(spacing: 12) {
            Text("Activity Type")
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "All" button
                    Button(action: {
                        selectedActivityType = nil
                    }) {
                        Text("All")
                            .font(.subheadline)
                            .fontWeight(selectedActivityType == nil ? .semibold : .regular)
                            .foregroundColor(selectedActivityType == nil ? .white : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedActivityType == nil ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(20)
                    }

                    // Individual activity type buttons
                    ForEach(dataManager.availableActivityTypes, id: \.self) { activityType in
                        Button(action: {
                            selectedActivityType = activityType
                        }) {
                            Text(activityType)
                                .font(.subheadline)
                                .fontWeight(selectedActivityType == activityType ? .semibold : .regular)
                                .foregroundColor(selectedActivityType == activityType ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedActivityType == activityType ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var totalDistanceCard: some View {
        VStack(spacing: 10) {
            Text("Total Distance")
                .font(.headline)
                .foregroundColor(.secondary)

            let totalDistance = dataManager.totalDistanceForWeek(startDate: currentWeekStart, activityType: selectedActivityType)
            Text(String(format: "%.1f km", totalDistance))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var rideCountCard: some View {
        let rideCount = dataManager.activitiesForWeek(startDate: currentWeekStart, activityType: selectedActivityType).count
        let activityLabel = activityCountLabel(for: selectedActivityType, count: rideCount)

        return HStack(spacing: 15) {
            Image(systemName: activityIcon(for: selectedActivityType))
                .font(.system(size: 40))
                .foregroundColor(.green)

            VStack(alignment: .leading) {
                Text(activityLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(rideCount)")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var dailyDistanceChart: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Weekly Distances")
                    .font(.headline)

                Spacer()

                // Week count picker
                Menu {
                    ForEach([4, 8, 10, 12, 16, 20, 26], id: \.self) { weeks in
                        Button("\(weeks) weeks") {
                            numberOfWeeks = weeks
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(numberOfWeeks) weeks")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            weeklyChart

            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(date.formatted(.dateTime.month(.abbreviated)))
                                    .font(.caption2)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text("\(Int(distance)) km")
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 280)
            .padding()
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Chart Components

    private var weeklyChart: some View {
        let weeklyData = getWeeklyDistances()
        let currentYear = Calendar.current.component(.year, from: currentWeek).description
        let previousYear = (Calendar.current.component(.year, from: currentWeek) - 1).description

        return Chart(weeklyData, id: \.weekStart) { item in
            LineMark(
                x: .value("Week", item.weekStart, unit: .weekOfYear),
                y: .value("Distance", item.distance)
            )
            .foregroundStyle(by: .value("Year", item.year))
            .lineStyle(by: .value("Year", item.year))

            PointMark(
                x: .value("Week", item.weekStart, unit: .weekOfYear),
                y: .value("Distance", item.distance)
            )
            .foregroundStyle(by: .value("Year", item.year))
            .symbolSize(50)
        }
        .chartForegroundStyleScale([
            currentYear: .blue,
            previousYear: .orange
        ])
        .chartLineStyleScale([
            currentYear: StrokeStyle(lineWidth: 3),
            previousYear: StrokeStyle(lineWidth: 2, dash: [5, 3])
        ])
        .animation(.none, value: numberOfWeeks)
    }

    private var rolling12MonthChart: some View {
        let rollingData = dataManager.getRolling12MonthTotals(days: rollingDays, activityType: selectedActivityType)

        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("12-Month Rolling Total")
                    .font(.headline)

                Spacer()

                // Days count picker
                Menu {
                    ForEach([180, 365, 730], id: \.self) { days in
                        Button(days == 365 ? "1 year" : days == 730 ? "2 years" : "6 months") {
                            rollingDays = days
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(rollingDays == 365 ? "1 year" : rollingDays == 730 ? "2 years" : "6 months")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            if rollingData.isEmpty {
                Text("Not enough data for rolling calculation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(rollingData, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Total", item.total)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.month(.abbreviated)))
                            }
                            AxisGridLine()
                            AxisTick()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let total = value.as(Double.self) {
                                Text("\(Int(total)) km")
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 250)
                .padding()
                .animation(.none, value: rollingDays)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Weekly Data Calculation

    /// Get weekly distance totals for the specified number of weeks, including previous year
    private func getWeeklyDistances() -> [(weekStart: Date, distance: Double, year: String)] {
        // Pre-allocate array for better performance
        var weeklyData: [(weekStart: Date, distance: Double, year: String)] = []
        weeklyData.reserveCapacity(numberOfWeeks * 2) // Current + previous year

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentWeek)
        let previousYear = currentYear - 1

        // Calculate all week dates at once
        for weekOffset in (0..<numberOfWeeks).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeek) else {
                continue
            }

            // Current year data
            let currentDistance = dataManager.totalDistanceForWeek(startDate: weekStart, activityType: selectedActivityType)
            weeklyData.append((weekStart: weekStart, distance: currentDistance, year: "\(currentYear)"))

            // Previous year data - same week number, previous year
            guard let previousYearWeek = calendar.date(byAdding: .year, value: -1, to: weekStart) else {
                continue
            }

            let previousDistance = dataManager.totalDistanceForWeek(startDate: previousYearWeek, activityType: selectedActivityType)
            // Only add previous year data if there's actual distance (avoid plotting zeros)
            if previousDistance > 0 {
                weeklyData.append((weekStart: weekStart, distance: previousDistance, year: "\(previousYear)"))
            }
        }

        return weeklyData
    }

    // MARK: - Toolbar

    private var toolbarMenu: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            menuContent
        }
        #else
        ToolbarItem(placement: .automatic) {
            menuContent
        }
        #endif
    }

    private var menuContent: some View {
        Menu {
            Button(action: {
                Task {
                    if let token = try? await oauthManager.getValidAccessToken() {
                        await dataManager.fetchActivities(accessToken: token)
                    }
                }
            }) {
                Label("Refresh Activities", systemImage: "arrow.clockwise")
            }

            Button(action: {
                showingTokenInput = true
            }) {
                Label(oauthManager.isAuthenticated ? "Reconnect" : "Connect to Strava", systemImage: "key")
            }

            if oauthManager.isAuthenticated {
                Button(action: {
                    oauthManager.disconnect()
                    showingTokenInput = true
                }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Week Navigation

    private var weekDateRange: String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startString = formatter.string(from: currentWeekStart)
        let endString = formatter.string(from: weekEnd)

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let yearString = yearFormatter.string(from: currentWeekStart)

        return "\(startString) - \(endString), \(yearString)"
    }

    private func previousWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }

    private func nextWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }

    private func goToCurrentWeek() {
        currentWeekStart = Date().startOfWeek()
    }

    private func canGoToPreviousWeek() -> Bool {
        guard let firstActivityDate = dataManager.firstActivityDate() else {
            return false
        }
        return currentWeekStart > firstActivityDate
    }

    private func canGoToNextWeek() -> Bool {
        let thisWeekStart = Date().startOfWeek()
        return currentWeekStart < thisWeekStart
    }

    // MARK: - Token Management

    private func loadAccessToken() {
        if let token = UserDefaults.standard.string(forKey: "stravaAccessToken") {
            accessToken = token
        }
    }

    // MARK: - Activity Type Helpers

    private func activityIcon(for type: String?) -> String {
        guard let type = type else {
            return "figure.mixed.cardio"
        }

        switch type {
        case "Ride", "VirtualRide", "EBikeRide":
            return "bicycle.circle.fill"
        case "Run", "VirtualRun":
            return "figure.run.circle.fill"
        case "Walk":
            return "figure.walk.circle.fill"
        case "Swim":
            return "figure.pool.swim.circle.fill"
        case "Hike":
            return "figure.hiking.circle.fill"
        case "WeightTraining":
            return "dumbbell.fill"
        case "Yoga":
            return "figure.cooldown"
        default:
            return "figure.mixed.cardio"
        }
    }

    private func activityCountLabel(for type: String?, count: Int) -> String {
        guard let type = type else {
            return "Activities"
        }

        switch type {
        case "Ride", "VirtualRide", "EBikeRide":
            return count == 1 ? "Ride" : "Rides"
        case "Run", "VirtualRun":
            return count == 1 ? "Run" : "Runs"
        case "Walk":
            return count == 1 ? "Walk" : "Walks"
        case "Swim":
            return count == 1 ? "Swim" : "Swims"
        case "Hike":
            return count == 1 ? "Hike" : "Hikes"
        case "WeightTraining":
            return count == 1 ? "Session" : "Sessions"
        case "Yoga":
            return count == 1 ? "Session" : "Sessions"
        default:
            return count == 1 ? "Activity" : "Activities"
        }
    }
}

// MARK: - Extensions

extension Date {
    /// Get the start of the week (Monday) for this date
    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}

extension Color {
    /// Cross-platform system gray 6 color
    static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGray6)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

#Preview {
    WeeklyDistanceView()
}
