# HearingApp

A privacy-first iOS app that tracks your headphone sound exposure to help protect your hearing.

## Features

- **Daily Sound Allowance tracking** - See how much of your safe listening limit you've used
- **Real-time status** - Green/Yellow/Red indicators show your current exposure level
- **7-day and 30-day trends** - Track your listening habits over time
- **Smart notifications** - Get alerts at 50%, 80%, and 100% of your daily limit
- **Privacy-first** - No microphone access, no content analysis, all data stays on device

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

### Option 1: Using Xcodegen (Recommended)

1. Install Xcodegen if you haven't already:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd hearing-app
   xcodegen generate
   ```

3. Open the generated project:
   ```bash
   open HearingApp.xcodeproj
   ```

### Option 2: Manual Xcode Setup

1. Open Xcode and create a new iOS App project
2. Choose SwiftUI for the interface
3. Enable HealthKit capability in Signing & Capabilities
4. Copy the source files from `HearingApp/` into your project
5. Add the Info.plist entries for HealthKit usage descriptions

## Project Structure

```
hearing-app/
├── HearingApp/
│   ├── App/                    # App entry point and state
│   ├── Features/
│   │   ├── Today/              # Main dashboard
│   │   ├── Trends/             # Weekly/monthly charts
│   │   ├── Settings/           # User preferences
│   │   └── Onboarding/         # First-run experience
│   ├── Services/
│   │   ├── HealthKit/          # HealthKit integration
│   │   ├── Dose/               # Sound dose calculations
│   │   └── Notifications/      # Local notifications
│   ├── Storage/                # SwiftData models
│   ├── DesignSystem/           # Colors, typography, components
│   └── Resources/              # Assets, Info.plist, entitlements
├── HearingAppTests/            # Unit tests
├── project.yml                 # Xcodegen configuration
└── README.md
```

## How It Works

### Sound Dose Calculation

The app uses the NIOSH/WHO-recommended formula for calculating safe sound exposure:

- **Reference level**: 85 dBA for 8 hours = 100% daily dose
- **Exchange rate**: Every 3 dB increase halves the allowable time
- **Formula**: `Allowable Time = 8h × 2^((85-L)/3)`

For example:
- 85 dB → 8 hours
- 88 dB → 4 hours
- 91 dB → 2 hours
- 94 dB → 1 hour

### Data Sources

The app reads headphone audio exposure data from Apple HealthKit:
- `HKQuantityTypeIdentifierHeadphoneAudioExposure` - Sound level samples in dBASPL
- `HKCategoryTypeIdentifierHeadphoneAudioExposureEvent` - Exposure threshold events

**Note**: Accuracy is highest with AirPods and Beats headphones, which report actual measured levels. Other headphones use estimated values based on volume settings.

## Privacy

This app is designed with privacy as a core principle:

- **No microphone access** - We never record ambient sound
- **No content analysis** - We don't know what you're listening to
- **On-device processing** - All calculations happen locally
- **No network requests** - Your data never leaves your phone
- **No analytics** - We don't track your usage

## Testing

Run the unit tests:
```bash
xcodebuild test -scheme HearingApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

MIT License - See LICENSE file for details.

## Acknowledgments

- WHO Safe Listening Guidelines
- NIOSH Noise Exposure Standards
- Apple HealthKit Documentation
