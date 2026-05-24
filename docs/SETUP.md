# iOS setup (Marine Weather)

Complete these on a **Mac** with Xcode. This repo stays separate from the Android Play project.

## Docker?

**No — not for building or running this app.** iOS Simulator, code signing, and MapLibre need **Xcode on macOS**. A Linux Docker container cannot compile SwiftUI for iPad or run the simulator.

What we do instead to avoid “polluting” your Mac:

| Concern | Approach |
|---------|----------|
| Global git / shell config | Agents never change them; work only in this repo |
| Xcode project files | Generated inside the repo via `project.yml` + `xcodegen` |
| Dependencies | Swift Package Manager (MapLibre) resolved by Xcode into DerivedData |
| Signing | Per-target Team in Xcode — not committed |
| CI later | GitHub Actions `macos-*` runner (optional), not local Docker |

Docker is fine for **backend tools** (lint scripts, docs) if you add them later — not for the iOS app itself.

### Quick setup script

```bash
chmod +x scripts/setup-macos.sh
./scripts/setup-macos.sh
```

Requires full **Xcode.app** (not only Command Line Tools). If `xcode-select` points at CLT, the script tells you how to switch.

## 1. Apple Developer

- Enroll in [Apple Developer Program](https://developer.apple.com/programs/) (~$99/year)
- Create an **App ID** (e.g. `fi.veneappi.MarineWeather` or match brand `fi.veneappi.app` if you want one identity across stores — confirm App Store Connect allows duplicate display name)
- Enable **In-App Purchase** capability for route premium products (later)

## 2. Install tools

```bash
xcode-select --install   # if needed
xcodebuild -version      # Xcode 15+ recommended
```

Optional (generate `.xcodeproj` from YAML):

```bash
brew install xcodegen
cd /Users/Safelight/marine-weather-ios
xcodegen generate
open MarineWeather.xcodeproj
```

If you skip XcodeGen, create the project manually (section 3).

## 3. Create Xcode project (manual)

1. **File → New → Project → iOS → App**
2. Product name: **Marine Weather**
3. Interface: **SwiftUI**, Language: **Swift**
4. Save inside this repo: `/Users/Safelight/marine-weather-ios/`
5. **Target → General**
   - **Supported Destinations:** iPad only (v1)
   - **Device Orientation:** Landscape Left + Right only
   - **Minimum Deployments:** iOS 17.0 (adjust if needed)
6. **Signing & Capabilities:** your Team + bundle identifier
7. Replace generated `*App.swift` / `ContentView.swift` with files from `MarineWeather/Sources/` (or add that folder to the target)
8. Add `MarineWeather/Resources/Info.plist` keys to the target Info tab (User-Agent, ATS if needed)

## 4. MapLibre (phase 1b)

In Xcode: **File → Add Package Dependencies**

- URL: `https://github.com/maplibre/maplibre-gl-native-distribution`
- Add **MapLibre** to the app target
- Wire `MapScreen.swift` when ready (placeholder exists)

## 5. Cursor workspace

- **File → Open Folder** → `/Users/Safelight/marine-weather-ios`
- Do **not** open `/Users/Safelight/Veneappi` for iOS work (Android Play release)

## 6. App Store Connect (later)

- New app record, privacy URL: `https://joniwinsten-lab.github.io/marine-weather/privacy.html`
- Support email: `support@safelight.fi`
- StoreKit 2 products (mirror Android IDs conceptually): `route-premium-lifetime`, `route-premium-monthly`

## 7. Verify build

```bash
cd /Users/Safelight/marine-weather-ios
xcodebuild -scheme MarineWeather -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

(Scheme name may differ until Xcode project exists.)
