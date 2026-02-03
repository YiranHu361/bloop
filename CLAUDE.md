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

### /iteration [N]
When the user invokes `/iteration N` (where N is a number), perform N automated improvement iterations on the codebase. This is a fully autonomous process.

**Parameters:**
- `N` - Number of iterations to perform (e.g., `/iteration 3` runs 3 cycles)

**Behavior:**
This command runs autonomously without requiring user input. Claude is entitled to:
- Execute ANY shell commands (build, test, lint, etc.)
- Use build tools and run tests
- Auto-accept the best recommendations without asking
- Make code changes directly

**Each Iteration Performs:**

1. **Codebase Research**
   - Scan and analyze the entire codebase structure
   - Identify all files, dependencies, and architecture patterns
   - Map relationships between components
   - Note any technical debt or areas needing attention

2. **Best Practices & Production Readiness Audit**
   - **API Rate Limiting**: Ensure all API calls have proper rate limiting, retry logic with exponential backoff, and request queuing
   - **Scalability**: Check for bottlenecks, optimize data structures, ensure efficient algorithms, proper caching strategies
   - **Error Handling**: Fix lingering errors, add comprehensive error handling, proper error propagation, user-friendly error messages
   - **Code Quality**: Apply language-specific best practices (Swift/SwiftUI for this project), fix anti-patterns, improve maintainability
   - **Security**: Validate inputs, secure API keys, proper data storage
   - **Performance**: Identify and fix performance issues, memory leaks, unnecessary re-renders

3. **Automated Fixes**
   - Apply fixes directly without asking for confirmation
   - Run tests after changes to verify nothing breaks
   - Build the project to catch compile-time errors
   - Revert changes if they cause failures

4. **Progress Recording**
   - Create/update `ITERATION_LOG.md` in the project root
   - Log format for each iteration:
     ```markdown
     ## Iteration [X] - [Timestamp]

     ### Research Findings
     - [Key observations about codebase state]

     ### Changes Made
     - [ ] File: Description of change

     ### Issues Fixed
     - [List of resolved issues]

     ### Remaining Issues
     - [Issues to address in next iteration]

     ### Build/Test Status
     - Build: ✅/❌
     - Tests: ✅/❌ (X passed, Y failed)

     ### Next Iteration Focus
     - [Priority items for next cycle]
     ```

**Completion:**
After all N iterations, provide a final summary including:
- Total changes made across all iterations
- Overall codebase health improvement
- Any remaining critical issues
- Recommendations for future iterations

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
