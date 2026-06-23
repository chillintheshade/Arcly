# Arcly

Arcly is a macOS radial launcher for quickly opening apps, files, folders, and media controls from a lightweight pie menu.

## Build

```bash
xcodebuild -project Orbis.xcodeproj -scheme Orbis -configuration Release build
```

The Xcode project and some internal identifiers still use `Orbis` / `com.qingshan.orbis` to preserve update and in-app purchase compatibility. The user-facing app name is `Arcly`.

## Notes

- The self-distributed local build should be signed without the App Sandbox entitlement if MediaRemote music metadata is required.
- App Store distribution should keep the normal App Store signing and sandbox flow.
