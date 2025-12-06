# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

betaTracker is a Strava activity tracking application for iOS and macOS that supports multiple household users with individual profiles. Built with SwiftUI, it provides comprehensive activity visualization including weekly summaries, speed/pace analysis, and long-term trends.

**Key Features:**
- Multi-user profile system with isolated data per user
- OAuth 2.0 with PKCE authentication for Strava
- Four chart types: Current Week, Speed & Pace, Weekly Summary, 12-Month Rolling
- Automatic activity caching with profile-specific storage
- Performance-optimized with in-memory caches for fast chart rendering
- Activity type filtering (Run, Ride, Swim, etc.)
- Distance filtering for speed/pace analysis
- Previous period comparison charts

**Project Structure:**
- `betaTracker/Models/`: Data models (StravaActivity, UserProfile)
- `betaTracker/Services/`: API services, OAuth, profile management, data caching
- `betaTracker/Views/`: SwiftUI views (WeeklyDistanceView, ProfileManagementView, etc.)
- `betaTrackerApp.swift`: App entry point

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
1. **Profile Management**: User creates/selects profile via `ProfileManager`
2. **Authentication**: OAuth 2.0 flow via `StravaOAuthManager` stores tokens in Keychain per profile
3. **Data Fetching**: `StravaAPIService` fetches all activities with automatic pagination (200 per page)
4. **Caching**: `ActivityDataManager` caches activities to UserDefaults with profile-specific keys
5. **Performance Caches**: Weekly totals and speed caches built in-memory on app launch
6. **Display**: `WeeklyDistanceView` shows 4 chart types using Swift Charts framework

### Key Components

**Models (betaTracker/Models/)**
- `StravaActivity`: Codable model for Strava activity data
  - Fields: id, name, type, distance (meters), movingTime (seconds), startDate
  - Computed: distanceKm, localDate (date without time for grouping)
  - ISO8601 date parsing
- `UserProfile`: Represents a household user
  - Fields: id (UUID), name, clientID, clientSecret, lastSyncedAt
  - Methods: token management, cache management, hasTokens(), hasCachedData()
  - Profile-specific UserDefaults and Keychain keys

**Services (betaTracker/Services/)**
- `ProfileManager`: Singleton managing all user profiles
  - Stores profiles in UserDefaults as JSON array
  - Current profile selection and switching
  - Profile CRUD operations
  - Coordinates with ActivityDataManager for data reloading

- `StravaOAuthManager`: Singleton handling OAuth 2.0 with PKCE
  - Token management (access + refresh) stored in Keychain per profile
  - Automatic token refresh when expired
  - Profile-aware token storage
  - Uses `LocalOAuthServer` for callback handling on localhost

- `StravaAPIService`: Singleton for Strava API communication
  - `fetchAllActivities()`: Paginated fetching with automatic continuation
  - Rate limiting delay between pages (0.1s)
  - Error handling: auth, network, decoding

- `ActivityDataManager`: @MainActor ObservableObject for data management
  - Profile-specific activity caching in UserDefaults
  - In-memory performance caches: `weeklyTotalsCache`, `weeklySpeedCache`
  - Cache building methods: `buildWeeklyTotalsCache()`, `buildWeeklySpeedCache()`
  - Key methods:
    - `fetchActivities()`: Fetches from Strava and rebuilds caches
    - `reloadForCurrentProfile()`: Loads cached data for current profile
    - `activitiesForWeek()`, `totalDistanceForWeek()`: Cached weekly queries
    - `getRolling12MonthTotals()`: 365-day rolling window calculation
    - `getMovingAverageSpeed()`, `getMovingAveragePace()`: 1-month moving avg at weekly level
    - `getMostActiveTypeInLast6Months()`: Auto-selects default activity type
  - Distance filtering support (calculates on-the-fly when filter applied)

**Views (betaTracker/Views/)**
- `WeeklyDistanceView`: Main dashboard with 4 chart types
  - **Current Week**: Large card with total distance, activity count
  - **Speed & Pace**: 1-month moving average chart with distance filtering
  - **Weekly Summary**: Distance trends, current vs previous year comparison
  - **12-Month Rolling**: Rolling cumulative total, current vs previous period
  - Sidebar: profile selector, activity type filter, date navigation
  - Toolbar menu: refresh, reconnect, disconnect, manage profiles, clear cache

- `ProfileManagementView`: Profile CRUD interface
  - List of profiles with status indicators
  - Switch, edit, delete, clear cache actions

- `ProfileEditorView`: Create/edit profile form
  - Name, Client ID, Client Secret inputs
  - Instructions for Strava API setup

- `ProfileSelectorView`: Compact profile switcher in sidebar
  - Current profile display with last sync
  - Quick-switch dropdown menu

- `TokenInputView`: OAuth flow initiation
  - "Connect with Strava" button
  - Launches OAuth flow via StravaOAuthManager

### SwiftUI App Lifecycle
Uses modern SwiftUI App lifecycle with `@main` on `betaTrackerApp`. Entry point shows `WeeklyDistanceView` directly.

### Strava API Integration
- Base URL: `https://www.strava.com/api/v3`
- Endpoint: `/athlete/activities`
- Auth: Bearer token in Authorization header
- Pagination: `page` and `per_page` parameters (max 200)
- Response: Array of activities with ISO8601 dates
- OAuth: Authorization endpoint + token exchange

### Data Storage

**UserDefaults** (per profile):
- Activities: `cachedStravaActivities_{profileID}`
- Cache timestamp: `activitiesCacheTimestamp_{profileID}`
- Profiles list: `userProfiles`
- Current profile: `currentProfileID`

**Keychain** (secure, per profile):
- Access token: `stravaAccessToken_{profileID}`
- Refresh token: `stravaRefreshToken_{profileID}`
- Token expiry: `stravaTokenExpiry_{profileID}`

**In-Memory Caches** (rebuilt on app launch):
- `weeklyTotalsCache`: Weekly distance totals by activity type
- `weeklySpeedCache`: Weekly 1-month moving average speeds by activity type

### Performance Optimization

**Caching Strategy:**
- Activities cached to disk (UserDefaults) on fetch
- Derived caches (weekly totals, speeds) built in-memory on app launch
- Chart queries use pre-built caches for instant rendering
- Distance-filtered queries calculate on-the-fly (not cached)

**Known Performance Considerations:**
- Cache building happens on main thread during app launch
- Large activity datasets (1000+) may cause noticeable delay on launch
- Weekly speed cache calculates 1-month moving average for each week
- UserDefaults may hit size limits with 5000+ activities

**Future Optimization Opportunities:**
1. Disk caching for derived data (not yet implemented)
2. Background thread cache building
3. Lazy/on-demand cache building
4. Core Data or file-based storage for activities

### Chart System

All charts use SwiftUI Charts framework with dynamic styling:

**Color Scheme:**
- Blue: Current period/year data (solid lines)
- Orange: Previous period/year comparison (dashed lines)
- Green: Speed/pace chart theme
- Purple: Distance filter picker

**Chart Types:**
1. **Current Week** - Card layout, no chart
2. **Speed & Pace** - LineMark with weekly data points, 1-month moving average
3. **Weekly Summary** - LineMark with dual year comparison
4. **12-Month Rolling** - LineMark with relative day axis

**Dynamic Axis Labeling:**
- Short periods (≤6 months): Monthly labels
- Long periods (>12 months): Monthly + year labels
- Rolling chart: Relative days (0 = today, negative = past)

### Testing Framework
- Uses XCTest for both unit and UI tests
- Test classes inherit from `XCTestCase`
- Performance tests available via `measure { }` blocks

## Current Limitations

1. **No disk caching of derived data**: Weekly totals and speed caches rebuilt on each app launch
2. **Distance filtering not cached**: Always calculates on-the-fly
3. **UserDefaults for activity storage**: May hit size limits with many activities (consider Core Data/files)
4. **Single-threaded cache building**: Could be moved to background thread
5. **No automatic background sync**: User must manually refresh

## Recent Development

**Latest Session (2025-12-06):**
- Added previous period comparison to 12-month rolling chart with relative day axis
- Unified color scheme (blue/orange) across all charts
- Changed weekly summary from week-based to month-based time periods
- Added Speed & Pace chart with 1-month moving average
- Implemented weekly-level speed/pace calculations with caching
- Added distance filtering to speed/pace chart (run: 5-30km, cycling: 20-100km)
- Distance filter calculates on-the-fly while non-filtered uses cache

## Code Style Guidelines

- Use SwiftUI declarative syntax for all views
- @MainActor for data managers and published state
- Async/await for API calls and asynchronous operations
- Guard-let for early returns and optional unwrapping
- Computed properties for derived data
- Private methods for view helpers and internal logic
- Descriptive method names that explain what they do
- Comments for complex algorithms (e.g., rolling windows, moving averages)
