# Strava Cycling Tracker

A personal iOS app built with SwiftUI to track and visualize your Strava cycling data. View weekly cycling statistics including total distance, number of rides, and daily distance charts.

## Features

- **Simple Authentication**: Manually input your Strava access token (no OAuth needed)
- **Complete Activity History**: Automatically fetches ALL your cycling activities using pagination
- **Weekly Summary View**:
  - Large, prominent total distance display (in km)
  - Number of rides for the week
  - Bar chart showing daily distances
- **Week Navigation**: Browse through all your historical weeks back to your first ride
- **Smart Caching**: Activities are cached locally to minimize API calls
- **Refresh on Demand**: Update with new rides via the refresh button

## Getting Started

### Prerequisites

- Xcode 14+ (for iOS 16+ Swift Charts support)
- iOS 16+ device or simulator
- Strava account with API access

### Getting Your Strava Access Token

1. Go to [https://www.strava.com/settings/api](https://www.strava.com/settings/api)
2. Create an application (if you haven't already)
3. Note your **Access Token** from the API settings page
4. For testing, you can use the temporary access token shown
5. For longer-term use, you may want to generate a refresh token

### Installation

1. Clone this repository
2. Open `betaTracker.xcodeproj` in Xcode
3. Select your target device/simulator (iOS 16+)
4. Build and run (Cmd + R)

### First-Time Setup

1. When you first launch the app, you'll be prompted to enter your Strava access token
2. Paste your token and tap "Save Token"
3. The app will automatically fetch all your cycling activities (this may take a moment)
4. Once loaded, you'll see your current week's cycling statistics

## Usage

### Main View

- **Total Distance**: Large display showing your total km for the selected week
- **Rides**: Number of cycling activities for the week
- **Daily Distance Chart**: Bar chart showing distance for each day of the week

### Navigation

- **Previous/Next Week**: Browse through your cycling history
- **Today Button**: Quickly jump back to the current week
- **Menu (⋯)**:
  - Refresh Activities: Fetch new rides from Strava
  - Update Token: Change your access token

### Activity Types

The app filters for these Strava activity types:
- Ride (regular cycling)
- VirtualRide (indoor cycling, Zwift, etc.)
- EBikeRide (e-bike rides)

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **Swift Charts**: Native iOS charting for data visualization
- **URLSession**: Async/await API calls to Strava
- **UserDefaults**: Token storage and activity caching
- **@MainActor**: Thread-safe state management

### Strava API

- Endpoint: `https://www.strava.com/api/v3/athlete/activities`
- Pagination: Fetches 200 activities per request until all data is retrieved
- Rate limiting: 0.1 second delay between pagination requests

### Data Storage

- **Access Token**: Stored in UserDefaults (`stravaAccessToken`)
- **Activities Cache**: JSON-encoded activities in UserDefaults
- **Cache Timestamp**: Tracks when data was last refreshed

## Project Structure

```
betaTracker/
├── Models/
│   └── StravaActivity.swift          # Data model for Strava activities
├── Services/
│   ├── StravaAPIService.swift        # API client with pagination
│   └── ActivityDataManager.swift     # Caching and data management
├── Views/
│   ├── WeeklyDistanceView.swift      # Main weekly summary view
│   └── TokenInputView.swift          # Token configuration view
└── betaTrackerApp.swift              # App entry point
```

## Troubleshooting

### "Unauthorized" Error
- Check that your access token is valid
- Go to Strava API settings and verify your token hasn't expired
- Use the menu to update your token

### No Activities Showing
- Ensure you have cycling activities in your Strava account
- Try pulling down to refresh
- Check that activities are of type "Ride", "VirtualRide", or "EBikeRide"

### App Not Loading Data
- Check your internet connection
- Verify the token has proper permissions (read activities)
- Look for error messages in the app

## Future Enhancements

Potential features for future development:
- OAuth authentication flow
- Monthly/yearly statistics views
- Activity trend analysis
- Export data to CSV
- Dark mode support
- Achievement badges
- Comparison with previous periods

## Author

Matthew Phelps (MEWP)

## License

This is a personal project for individual use.
