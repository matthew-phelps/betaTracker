# OAuth Setup Instructions

## Step 1: Configure URL Scheme in Xcode

You need to add a custom URL scheme so Safari can redirect back to your app after OAuth authorization.

### Instructions:

1. **Open Xcode** and select the **betaTracker** project (blue icon at top of navigator)

2. **Select the betaTracker target** (under TARGETS)

3. **Go to the "Info" tab**

4. **Expand "URL Types"** section (or add it if not present)

5. **Click the "+" button** to add a new URL Type

6. **Fill in the following:**
   - **Identifier**: `com.betaTracker.oauth`
   - **URL Schemes**: `stravatracker`
   - **Role**: Editor

7. **Save** (Cmd + S)

This registers `stravatracker://` as a custom URL scheme that opens your app.

## Step 2: Update Strava API Settings

1. Go to https://www.strava.com/settings/api

2. Find **"Authorization Callback Domain"**

3. Set it to: `localhost`
   (The actual redirect URI is `stravatracker://oauth/callback` but Strava requires the domain field)

## Step 3: Test the OAuth Flow

After completing steps 1 and 2:

1. **Rebuild the app** (Cmd + Shift + K to clean, then Cmd + R to run)

2. **Tap "Connect to Strava"**

3. **Safari will open** with Strava's authorization page

4. **Click "Authorize"**

5. **You'll be redirected back to the app** automatically with a valid token

## Troubleshooting

### "No application is registered for this URL"
- Make sure you added the URL scheme correctly in Xcode
- Rebuild the app completely

### "Invalid redirect_uri"
- Check that Strava callback domain is set to `localhost`
- Make sure there are no typos in the URL scheme

### Safari doesn't redirect back
- Check the URL scheme in Xcode is exactly: `stravatracker` (no ://)
- Make sure the app is installed on the device/simulator

## How It Works

1. App opens: `https://www.strava.com/oauth/authorize?client_id=...&redirect_uri=stravatracker://oauth/callback`
2. User authorizes on Strava's website
3. Strava redirects to: `stravatracker://oauth/callback?code=XXXXX`
4. iOS/macOS opens your app because it registered `stravatracker://`
5. App exchanges code for access token + refresh token
6. Tokens are stored securely

The refresh token allows automatic token renewal without user intervention!
