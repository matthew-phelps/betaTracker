# Getting Started with Your Strava Tracker

## Quick Start Guide

### Step 1: Get Your Strava Access Token

1. Visit [https://www.strava.com/settings/api](https://www.strava.com/settings/api)
2. If you don't have an app yet, click "Create an App"
   - Fill in the required fields (name, website, etc.)
   - For "Authorization Callback Domain" you can use `localhost` for personal use
3. Once created, you'll see your API credentials including an **Access Token**
4. Copy this access token - you'll need it in the app

**Note**: The token shown on the API settings page is a temporary token. For production use, you'd typically implement OAuth to get a long-lived token, but for personal use, this temporary token works fine.

### Step 2: Open the Project in Xcode

```bash
cd /Users/mewp/git/betaTracker/betaTracker
open betaTracker.xcodeproj
```

### Step 3: Build and Run

1. In Xcode, select your target device (iOS Simulator or your iPhone)
2. Make sure it's iOS 16+ (required for Swift Charts)
3. Press Cmd + R to build and run

### Step 4: Enter Your Token

1. When the app launches, you'll see the token input screen
2. Paste your Strava access token
3. Tap "Save Token"

### Step 5: Wait for Initial Load

- The app will now fetch ALL your cycling activities from Strava
- This is a one-time process and may take a minute depending on your activity history
- You'll see a loading indicator with progress
- Activities are cached locally, so subsequent launches are instant

### Step 6: Explore Your Data

Once loaded, you'll see:
- Your current week's total distance in large numbers
- Number of rides for the week
- A bar chart showing daily distances
- Navigation buttons to explore other weeks

## Tips for R Users New to Swift

Since you're familiar with R, here are some Swift/SwiftUI parallels:

### Data Structures
- **R vectors** → Swift arrays: `[StravaActivity]`
- **R data frames** → Arrays of structs or custom types
- **R lists** → Swift dictionaries or structs

### Functional Programming
Swift has similar functional methods to R's apply family:
- `filter()` - like R's `subset()` or `filter()` in dplyr
- `map()` - like R's `lapply()` or `map()` in purrr
- `reduce()` - like R's `Reduce()` or `reduce()` in purrr

Example in this app:
```swift
// Similar to: sum(activities$distance)
let totalDistance = activities.reduce(0) { $0 + $1.distanceKm }

// Similar to: activities[activities$type == "Ride",]
let rides = activities.filter { $0.type == "Ride" }
```

### Plotting
- **ggplot2** → **Swift Charts**: Both use layered grammar of graphics
- `geom_bar()` → `BarMark()`
- `aes(x = date, y = distance)` → `.value("Date", date)` and `.value("Distance", distance)`

### Dates
- **R's lubridate** → **Swift's Calendar and DateFormatter**
- Both have functions for date arithmetic, formatting, and extraction

## Common Development Tasks

### Adding a New Metric

To add a new statistic to the weekly view:

1. Add a computed property to `ActivityDataManager.swift`:
```swift
func averageSpeedForWeek(startDate: Date) -> Double {
    let activities = activitiesForWeek(startDate: startDate)
    guard !activities.isEmpty else { return 0 }
    let totalSpeed = activities.compactMap { $0.averageSpeed }.reduce(0, +)
    return totalSpeed / Double(activities.count)
}
```

2. Add a card in `WeeklyDistanceView.swift` similar to `rideCountCard`

### Changing the Chart Type

Swift Charts supports multiple chart types:
- `BarMark` - bar chart (currently used)
- `LineMark` - line chart
- `AreaMark` - area chart
- `PointMark` - scatter plot

Just replace `BarMark` with your preferred type in the `Chart` view.

### Testing API Calls

To test without the full app:
1. Open `StravaAPIService.swift`
2. Add a print statement in `fetchActivitiesPage()`
3. Run the app and check Xcode console for API responses

## Troubleshooting

### Build Errors

**"Cannot find 'Chart' in scope"**
- Make sure your deployment target is iOS 16+
- Check that you've imported `Charts` at the top of the file

**"Command xcodebuild requires Xcode"**
- You need full Xcode installed, not just Command Line Tools
- Download from the Mac App Store

### Runtime Issues

**Activities not loading**
- Check Xcode console for error messages
- Verify your token is correct
- Ensure you have internet connectivity

**Chart not displaying**
- Verify you have activities for the selected week
- Check that `dailyDistancesForWeek()` is returning data

## Next Steps

Now that you have the basics working, consider:

1. **Testing with real data**: Add your actual Strava token and load your rides
2. **Customizing the UI**: Adjust colors, fonts, or layout to your preference
3. **Adding features**: Check the "Future Enhancements" section in README.md
4. **Learning SwiftUI**: Apple's SwiftUI tutorials are excellent

## Resources

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Swift Charts Documentation](https://developer.apple.com/documentation/charts)
- [Strava API Documentation](https://developers.strava.com/docs/reference/)

Happy tracking! 🚴‍♂️
