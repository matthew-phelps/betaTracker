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
    @StateObject private var profileManager = ProfileManager.shared
    @State private var accessToken: String = ""
    @State private var showingTokenInput = false
    @State private var showingProfileManagement = false
    @State private var currentWeekStart: Date = Date().startOfWeek()
    @State private var hasAttemptedInitialFetch = false
    @State private var numberOfWeeks = 10 // Number of weeks to display in chart
    @State private var rollingDays = 365 // Number of days to show in rolling chart
    @State private var selectedActivityType: String? = nil // nil means "all activities"
    @State private var selectedChartType: ChartType = .weekly

    // Chart type selection
    enum ChartType: String, CaseIterable, Identifiable {
        case weekly = "Weekly Summary"
        case rolling = "12-Month Rolling"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .weekly: return "chart.line.uptrend.xyaxis"
            case .rolling: return "chart.xyaxis.line"
            }
        }
    }

    // Cache current week to avoid recalculation
    private let currentWeek = Date().startOfWeek()

    var body: some View {
        Group {
            if profileManager.currentProfile == nil {
                // No profile selected - prompt to create one
                VStack(spacing: 20) {
                    Image(systemName: "person.3")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Welcome to Strava Tracker")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Create a profile to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button(action: {
                        showingProfileManagement = true
                    }) {
                        Label("Create Profile", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            } else if dataManager.isLoading {
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
                HStack(spacing: 0) {
                    // Sidebar with controls
                    controlsSidebar
                        .frame(width: 300)
                        .background(Color.cardBackground)

                    Divider()

                    // Main content area
                    mainContentArea
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            toolbarMenu
        }
        .sheet(isPresented: $showingTokenInput) {
            TokenInputView(accessToken: $accessToken)
        }
        .sheet(isPresented: $showingProfileManagement) {
            ProfileManagementView()
        }
        .onAppear {
            // Check OAuth authentication status
            oauthManager.checkAuthenticationStatus()

            // Set default activity type if we have cached data
            if !dataManager.activities.isEmpty && selectedActivityType == nil {
                selectedActivityType = dataManager.getMostActiveTypeInLast6Months()
            }

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
        .onChange(of: profileManager.currentProfile?.id) { _ in
            // Reload data when profile changes
            dataManager.reloadForCurrentProfile()
            oauthManager.checkAuthenticationStatus()
            // Set default activity type to most active in last 6 months
            selectedActivityType = dataManager.getMostActiveTypeInLast6Months()
        }
        .onChange(of: dataManager.activities.count) { count in
            // Update default activity type when activities change
            if count > 0 && selectedActivityType == nil {
                // Use a small delay to ensure data is fully processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedActivityType = dataManager.getMostActiveTypeInLast6Months()
                }
            }
        }
    }

    // MARK: - Sidebar Controls

    private var controlsSidebar: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Profile")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ProfileSelectorView(showingProfileManagement: $showingProfileManagement)
                }

                Divider()

                // Date navigation (only show for weekly view)
                if selectedChartType == .weekly {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Date Range")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        weekNavigationView
                    }

                    Divider()
                }

                // Activity type selector
                if !dataManager.availableActivityTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Activity Type")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        activityTypeSelector
                    }

                    Divider()
                }

                // Last sync info
                if let lastUpdate = dataManager.lastCacheDate() {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Last Synced")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(lastUpdate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Main Content Area

    private var mainContentArea: some View {
        VStack(spacing: 0) {
            // Chart type selector
            chartTypeSelector
                .padding()
                .background(Color.cardBackground)

            Divider()

            // Chart content
            ScrollView {
                VStack(spacing: 25) {
                    // Stats cards
                    HStack(spacing: 20) {
                        totalDistanceCard
                        rideCountCard
                    }
                    .padding(.horizontal)

                    // Selected chart
                    Group {
                        switch selectedChartType {
                        case .weekly:
                            weeklyChartCard
                        case .rolling:
                            rollingChartCard
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
        }
    }

    private var chartTypeSelector: some View {
        HStack(spacing: 15) {
            ForEach(ChartType.allCases) { chartType in
                Button(action: {
                    selectedChartType = chartType
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: chartType.icon)
                        Text(chartType.rawValue)
                            .font(.subheadline)
                    }
                    .foregroundColor(selectedChartType == chartType ? .white : .blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(selectedChartType == chartType ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var weekNavigationView: some View {
        VStack(spacing: 10) {
            Text(weekDateRange)
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!canGoToPreviousWeek())

                Button(action: goToCurrentWeek) {
                    Text("Today")
                        .font(.caption)
                }
                .buttonStyle(BorderedProminentButtonStyle())

                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!canGoToNextWeek())
            }
        }
    }

    private var activityTypeSelector: some View {
        VStack(spacing: 8) {
            // "All" button
            Button(action: {
                selectedActivityType = nil
            }) {
                HStack {
                    Text("All")
                    Spacer()
                    if selectedActivityType == nil {
                        Image(systemName: "checkmark")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedActivityType == nil ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            // Individual activity type buttons
            ForEach(dataManager.availableActivityTypes, id: \.self) { activityType in
                Button(action: {
                    selectedActivityType = activityType
                }) {
                    HStack {
                        Text(activityType)
                        Spacer()
                        if selectedActivityType == activityType {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(selectedActivityType == activityType ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
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

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Weekly Distances")
                    .font(.title2)
                    .fontWeight(.semibold)

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
            .padding(.top)

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
                .frame(height: 350)
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

    private var rollingChartCard: some View {
        let rollingData = dataManager.getRolling12MonthTotals(days: rollingDays, activityType: selectedActivityType)

        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("12-Month Rolling Total")
                    .font(.title2)
                    .fontWeight(.semibold)

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
            .padding(.top)

            if rollingData.isEmpty {
                Text("Not enough data for rolling calculation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(40)
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
                .frame(height: 350)
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

            Divider()

            Button(action: {
                showingProfileManagement = true
            }) {
                Label("Manage Profiles", systemImage: "person.2")
            }

            Button(action: {
                dataManager.clearCache()
            }) {
                Label("Clear Cache", systemImage: "trash")
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
