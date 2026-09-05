# PlayTimer

PlayTimer is a native iPadOS spike for a shared-iPad child mode:

1. Parent grants Screen Time authorization.
2. Parent creates a 4-6 digit PIN.
3. Parent starts a play session.
4. DeviceActivity counts actual app and web usage.
5. When the threshold is reached, the monitor extension applies a ManagedSettings shield.
6. The shield remains after the break ends until the parent verifies and starts another round or ends child mode.

## Current Spike Scope

- iPad-only SwiftUI app.
- Default play duration: 25 minutes.
- Default break duration: 5 minutes.
- Play duration options: 15, 25, 30, 45, 60 minutes.
- Break duration options: 5, 10, 15 minutes.
- Parent PIN stored in Keychain as salted SHA-256 verification data.
- Biometric verification uses Face ID / Touch ID only, then falls back to the app PIN.
- Shared session state is stored as JSON in the App Group container.
- ManagedSettings uses a named store shared by the app and extensions.
- App collections use `FamilyActivityPicker` and store only application tokens.
- Parents can create multiple named app collections, similar to playlists, such as "English study" and "Games".
- If no app collection is selected, PlayTimer falls back to whole-iPad usage timing.
- If an app collection is selected, child mode shields all other apps during play and only times the apps in the selected collection.

## Real iPad Checklist

1. Open `PlayTimer.xcodeproj`.
2. Set your Apple Developer Team on all four targets.
3. Ensure the app and extension bundle IDs have Family Controls and App Groups enabled.
4. Use the same App Group ID in all targets: `group.com.wenlei.PlayTimer`.
5. Run on a real iPad. Screen Time APIs cannot be fully validated in the simulator.
6. Grant Screen Time authorization, create a PIN, start a short test session, leave the app, and use another app until the threshold triggers.

For faster testing, temporarily add a 1-minute play option in `Sources/Shared/AppConstants.swift`.
