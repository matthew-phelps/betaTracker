# betaTracker

A Strava activity tracking application for iOS and macOS that supports multiple household users with individual profiles.

## Overview

betaTracker allows multiple people in a household to track their Strava activities using a single app installation. Each user has their own profile with separate Strava API credentials, avoiding Strava's athlete connection limits.

## Features

### Multi-User Profile System
- Create unlimited user profiles
- Each profile has isolated data and authentication
- Quick profile switching via sidebar
- Profile-specific data caching and sync timestamps

### Activity Tracking
- Sync all your Strava activities (Run, Ride, Swim, etc.)
- Automatic activity caching for offline viewing
- Filter by activity type
- Auto-defaults to your most active type

### Visualization Charts

#### 1. Current Week Summary
- Large display of total distance for the current week
- Activity count with type-specific icons
- Week date range navigation
- Previous/next week buttons

#### 2. Speed & Pace Analysis
- 1-month moving average of speed/pace over time
- **Running**: Shows pace (min:sec per km)
- **Cycling**: Shows speed (km/h)
- **Distance filtering**:
  - Running: 5, 10, 15, 20, 30+ km
  - Cycling: 20, 40, 60, 80, 100+ km
  - All activities: 5, 10, 20, 40, 60+ km
- Time periods: 3, 6, 12, 24 months
- Weekly data points for granular trends

#### 3. Weekly Summary
- Distance trends over time
- **Current year** (blue solid line) vs **previous year** (orange dashed line) comparison
- Time periods: 1, 2, 6, 12, 24 months
- Dynamic axis labeling based on time window
- Weekly data points

#### 4. 12-Month Rolling Total
- Rolling 12-month cumulative distance
- **Current period** (blue) vs **previous period** (orange) comparison
- Relative day axis (day 0 = today, negative = past)
- Calendar dates shown below for current period orientation
- Time windows: 6 months, 1 year, 2 years

### Authentication
- OAuth 2.0 with PKCE for secure Strava authentication
- Automatic token refresh when expired
- Per-profile token management in Keychain

## Getting Started

### Prerequisites
- macOS 14.0+ or iOS 17.0+
- Xcode 15.0+
- Strava account

### Strava API Setup

Each user needs their own Strava API application:

1. Go to https://www.strava.com/settings/api
2. Create a new API application
3. Set **Authorization Callback Domain** to: `localhost`
4. Note your **Client ID** and **Client Secret**

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/betaTracker.git
   cd betaTracker
   ```

2. Open `betaTracker.xcodeproj` in Xcode

3. Build and run (⌘R)

### First Time Setup

1. **Create a Profile**:
   - When the app launches, tap "Create Profile"
   - Enter your name
   - Enter your Strava API Client ID
   - Enter your Strava API Client Secret
   - Tap "Save"

2. **Connect to Strava**:
   - Tap the menu icon (⋯) in the toolbar
   - Select "Connect to Strava"
   - Authorize the app in your browser
   - You'll be redirected back to the app

3. **Sync Activities**:
   - Tap the menu icon (⋯) in the toolbar
   - Select "Refresh Activities"
   - Wait for all activities to sync (may take a moment for large histories)
   - Your data is now cached locally for offline viewing

## Usage

### Switching Profiles

**In the sidebar:**
1. Click the profile selector
2. Choose a different profile from the dropdown menu
3. Or select "Manage Profiles" to create/edit/delete profiles

Your data automatically reloads when switching profiles.

### Viewing Different Chart Types

**Select chart type** using the buttons at the top:
- **Current Week** - This week's summary with large distance display
- **Speed & Pace** - Moving average speed/pace analysis with distance filtering
- **Weekly Summary** - Long-term distance trends with year-over-year comparison
- **12-Month Rolling** - Cumulative progress with period comparison

**Sidebar filters:**
- **Activity Type** - Auto-defaults to most active type, or select All/Run/Ride/etc.
- **Date Range** - Navigate weeks (for Current Week view)

**Chart-specific controls:**
- **Speed & Pace**:
  - Distance filter (purple) - Filter activities by minimum distance
  - Time period (green) - 3, 6, 12, or 24 months
- **Weekly Summary**: Time period - 1, 2, 6, 12, or 24 months
- **12-Month Rolling**: Time window - 6 months, 1 year, or 2 years

### Refreshing Data

- **Manual refresh**: Menu (⋯) → "Refresh Activities"
- **Check last sync**: Look in the sidebar for "Last Synced" timestamp
- **When to refresh**: Only when you have new activities (data is cached locally)

### Managing Cache

- **Clear cache for current profile**: Menu (⋯) → "Clear Cache"
- **Clear cache for specific profile**: Manage Profiles → Profile menu (⋯) → "Clear Cache"
- **What clearing does**: Removes all locally stored activities (requires re-sync)

### Disconnecting from Strava

When you're done using the app (to free up your Strava API athlete limit):
1. Menu (⋯) → "Disconnect"
2. Your cached data remains until you clear it
3. You can reconnect anytime to sync new activities

## Architecture

### Data Flow

```
User → Profile Selection → OAuth Authentication → Strava API
                                                       ↓
                                              ActivityDataManager
                                                       ↓
                                       Disk Cache (UserDefaults per profile)
                                                       ↓
                                    In-Memory Performance Caches (rebuilt on launch)
                                                       ↓
                                                   Charts & UI
```

### Key Components

- **ProfileManager**: Manages user profiles and profile switching
- **StravaOAuthManager**: Handles OAuth flow, token storage, and automatic refresh
- **StravaAPIService**: Communicates with Strava REST API (paginated fetching)
- **ActivityDataManager**: Caches activities and provides data to views
  - Weekly totals cache (in-memory)
  - Weekly speed/pace cache (in-memory)
  - Distance filtering (calculated on-demand)
- **WeeklyDistanceView**: Main UI with all 4 chart types

### Performance

**Fast:**
- Activities cached to disk per profile
- Weekly totals pre-calculated and cached in-memory
- Speed/pace averages pre-calculated and cached in-memory
- Chart rendering uses cached data (instant)

**Slower:**
- Cache building on app launch (noticeable with 1000+ activities)
- Distance-filtered speed/pace (calculated on-demand, not cached)

## Data Storage

### Cached to Disk (UserDefaults)
- **Activities**: `cachedStravaActivities_{profileID}`
- **Cache timestamp**: `activitiesCacheTimestamp_{profileID}`
- **Profiles**: `userProfiles`
- **Current profile**: `currentProfileID`

### Secure Storage (Keychain)
- **Access token**: `stravaAccessToken_{profileID}`
- **Refresh token**: `stravaRefreshToken_{profileID}`
- **Token expiry**: `stravaTokenExpiry_{profileID}`

### In-Memory Caches (Rebuilt on Launch)
- Weekly distance totals by activity type
- Weekly 1-month moving average speeds by activity type

## Troubleshooting

### "No activities yet" despite having Strava data
1. Check connection status: Menu → Connect to Strava
2. Manually refresh: Menu → Refresh Activities
3. Verify your Strava API credentials in profile settings

### "Access token is empty" error
1. Menu → Reconnect
2. Re-authorize in your browser
3. Check Strava API application is active and callback domain is `localhost`

### Activities not syncing
1. Verify Strava API application status at https://www.strava.com/settings/api
2. Check Authorization Callback Domain is set to `localhost`
3. Try: Menu → Disconnect, then Menu → Connect to Strava

### Slow performance
- Initial cache building with 1000+ activities may take a few seconds on app launch
- Once caches are built, chart rendering is instant
- Distance filtering calculates on-the-fly (may be slower)
- Consider clearing old data if you have 5000+ activities

### Profile switching not working
1. Ensure profile has been created with valid API credentials
2. Each profile needs its own Strava API application
3. Connect to Strava after switching profiles (if not already connected)

## Privacy & Security

- **Local-first**: All activity data stored locally on your device
- **No cloud sync**: Data never sent to third-party servers (only Strava)
- **Secure storage**: OAuth tokens stored in system Keychain
- **Profile isolation**: Each user's data completely separate
- **API limits**: Each profile uses its own API application (no athlete limit issues)

## Known Limitations

1. **UserDefaults storage**: May hit size limits with 5000+ activities (consider Core Data migration)
2. **Cache rebuilding**: Derived caches rebuilt on each app launch (not persisted to disk)
3. **Main thread caching**: Cache building happens on launch, may cause brief delay
4. **No background sync**: Must manually refresh to get new activities
5. **Distance filtering not cached**: Recalculates on every filter change

## Future Enhancements

### Performance
- [ ] Disk caching for derived data (weekly totals, speed caches)
- [ ] Background thread cache building
- [ ] Core Data or file-based storage for activities
- [ ] Lazy/on-demand cache building

### Features
- [ ] Activity detail view (map, splits, heart rate)
- [ ] Custom goals and targets
- [ ] Notifications for milestones
- [ ] Export data to CSV/GPX
- [ ] Workout calendar view
- [ ] Segment analysis
- [ ] Training load metrics

### User Experience
- [ ] Onboarding tutorial
- [ ] Dark mode refinements
- [ ] Widget support
- [ ] Apple Watch companion app

## Contributing

This is a personal project built for household use. Feel free to fork and adapt for your own needs.

## Author

Matthew Phelps (MEWP)

## License

[Your chosen license]

## Acknowledgments

- Built with SwiftUI and Swift Charts
- Powered by the [Strava API](https://developers.strava.com/)
- OAuth implementation follows Strava's recommended PKCE flow
