# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

betaTracker is a personal iOS app built with SwiftUI to track and visualize Strava cycling data. The app displays weekly cycling statistics including total distance, number of rides, and a daily distance chart using Swift Charts.

**Key Features:**
- Manual Strava access token authentication (stored in UserDefaults)
- Fetches ALL cycling activities from Strava API with automatic pagination
- Local caching of activities to minimize API calls
- Weekly distance summary view with bar chart visualization
- Week navigation to browse historical data
- Refresh functionality to update with new rides

**Project Structure:**
- `betaTracker/Models/`: Data models (StravaActivity)
- `betaTracker/Services/`: API service and data manager
- `betaTracker/Views/`: SwiftUI views (WeeklyDistanceView, TokenInputView)
- `betaTrackerApp.swift`: App entry point
- Unit tests in `betaTrackerTests/`
- UI tests in `betaTrackerUITests/`

## Development Commands

### Building and Running
Since this is an Xcode project, it's designed to be built and run through Xcode IDE. If Xcode command-line tools are properly configured:

```bash
# Build the project
xcodebuild -project betaTracker.xcodeproj -scheme betaTracker build

# Run tests
xcodebuild test -project betaTracker.xcodeproj -scheme betaTracker -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for specific configuration
xcodebuild -project betaTracker.xcodeproj -scheme betaTracker -configuration Debug build
xcodebuild -project betaTracker.xcodeproj -scheme betaTracker -configuration Release build
```

Note: If you encounter "xcode-select: error: tool 'xcodebuild' requires Xcode", the system only has Command Line Tools installed. Full Xcode is required for building.

### Testing
```bash
# Run all tests
xcodebuild test -project betaTracker.xcodeproj -scheme betaTracker -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project betaTracker.xcodeproj -scheme betaTracker -only-testing:betaTrackerTests/betaTrackerTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -project betaTracker.xcodeproj -scheme betaTracker -only-testing:betaTrackerUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### Data Flow
1. **Authentication**: User enters Strava access token via `TokenInputView`, stored in UserDefaults
2. **Data Fetching**: `StravaAPIService` fetches all activities with automatic pagination (200 per page)
3. **Caching**: `ActivityDataManager` caches activities locally and filters for cycling only
4. **Display**: `WeeklyDistanceView` shows summary stats and Swift Charts visualization

### Key Components

**Models (betaTracker/Models/)**
- `StravaActivity`: Codable model for Strava activity data with ISO8601 date parsing
  - Includes `isCyclingActivity` filter for "Ride", "VirtualRide", "EBikeRide" types
  - Converts distance from meters to km, provides local date for grouping

**Services (betaTracker/Services/)**
- `StravaAPIService`: Singleton handling Strava API communication
  - `fetchAllActivities()`: Paginated fetching with automatic continuation until all data retrieved
  - Includes rate limiting delay between pages (0.1s)
  - Error handling for auth, network, and decoding issues
- `ActivityDataManager`: @MainActor ObservableObject for state management
  - Caches activities in UserDefaults using JSONEncoder
  - Provides filtered queries: `activitiesForWeek()`, `totalDistanceForWeek()`, `dailyDistancesForWeek()`
  - Tracks loading states and error messages

**Views (betaTracker/Views/)**
- `WeeklyDistanceView`: Main view with stats, chart, and navigation
  - Shows total km (large display), ride count, and Swift Charts bar chart
  - Week navigation with "Previous", "Next", "Today" buttons
  - Disabled navigation when at boundaries (first ride or current week)
  - Menu with refresh and token update options
- `TokenInputView`: Simple token input with validation and UserDefaults persistence

### SwiftUI App Lifecycle
Uses modern SwiftUI App lifecycle with `@main` on `betaTrackerApp`. Entry point shows `WeeklyDistanceView` directly.

### Strava API Integration
- Base URL: `https://www.strava.com/api/v3`
- Endpoint: `/athlete/activities`
- Auth: Bearer token in Authorization header
- Pagination: `page` and `per_page` parameters (max 200)
- Response: Array of activities with ISO8601 dates

### Testing Framework
- Uses XCTest for both unit and UI tests
- Test classes inherit from `XCTestCase`
- Performance tests available via `measure { }` blocks
