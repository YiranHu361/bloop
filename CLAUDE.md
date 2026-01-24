# HearingApp - Claude Code Instructions

## Custom Commands

### /clarify
When the user invokes `/clarify`, ask clarifying questions about their prompt before making any code changes. This helps ensure the implementation matches their intent.

**Behavior:**
- Do NOT edit any code yet
- Analyze the user's request thoroughly
- Identify any ambiguities, assumptions, or missing details
- Ask 3-7 targeted questions covering:
  - **Scope**: What files/features are affected?
  - **Behavior**: What exactly should happen? Edge cases?
  - **UI/UX**: Any specific design requirements?
  - **Data**: What data structures or models are involved?
  - **Dependencies**: Any constraints on libraries or patterns to use?
  - **Testing**: How should this be verified?
- Wait for answers before proceeding with implementation

### /check
When the user invokes `/check`, perform a comprehensive code review of recent changes or specified files.

**Behavior:**
1. **Best Practices Review (Swift/SwiftUI)**
   - Proper use of `@State`, `@Binding`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
   - Memory management (weak references, retain cycles)
   - Correct use of async/await and MainActor
   - SwiftData best practices
   - View composition and reusability
   - Proper error handling

2. **Bug Detection**
   - Force unwraps that could crash (`!`)
   - Optional handling issues
   - Race conditions in async code
   - Missing nil checks
   - Incorrect date/calendar handling
   - Off-by-one errors
   - State management issues

3. **Security Review**
   - Sensitive data exposure (API keys, credentials)
   - Insecure data storage
   - Input validation
   - Proper use of Keychain vs UserDefaults
   - App Transport Security compliance
   - Privacy issues (unnecessary permissions)

4. **Output Format**
   - Group findings by severity as you review each file
   - Include file path and line numbers
   - Provide specific fix recommendations
   - Highlight any patterns that should be refactored

5. **Comprehensive Summary (at the end)**
   Provide a summary table with all issues categorized:

   ```
   ## Summary

   | Level | Count | Description |
   |-------|-------|-------------|
   | 🔴 Critical | X | Issues that will cause crashes, data loss, or security vulnerabilities |
   | 🟡 Warning | X | Issues that may cause bugs, poor performance, or maintenance problems |
   | 🟢 Minor | X | Style issues, minor improvements, or suggestions for better practices |

   ### Critical Issues
   - [ ] File:Line - Brief description

   ### Warning Issues
   - [ ] File:Line - Brief description

   ### Minor Issues
   - [ ] File:Line - Brief description

   ### Overall Assessment
   [Brief paragraph on code health, key areas needing attention, and recommended priority for fixes]
   ```

---

## Project Context

This is an iOS app (HearingApp) that tracks headphone sound exposure using HealthKit data.

**Key Technologies:**
- SwiftUI with iOS 17+ deployment target
- SwiftData for persistence
- HealthKit for exposure data
- WidgetKit for home screen widgets
- UserNotifications for alerts

**Architecture:**
- MVVM pattern with ViewModels
- Singleton services (HealthKitSyncService, NotificationService, PersonalizationService)
- SwiftData models in `/Storage`
- Feature-based folder structure

**Design System:**
- Glassmorphism design with `.ultraThinMaterial` backgrounds
- Custom `GlassCard`, `SectionGlassCard` components
- `AppColors` and `AppTypography` for consistency
- Entrance animations via `AnimationTokens`

**App Group:**
- `group.com.hearingapp.shared` for widget data sharing
