# BrainFish Improvement Plan

## Overview
This plan addresses the identified issues in the fish movement and behavior system, focusing on performance, code quality, and game mechanics balance. The goal is to create smoother, more reliable animations while maintaining the engaging "swimming fish" experience that serves as a productivity reminder.

## Priority Classification
- **High Priority**: Core performance and correctness issues that affect user experience
- **Medium Priority**: Code quality and maintainability improvements
- **Low Priority**: Enhancements for better balance and polish

## High Priority Issues & Fixes

### 1. Performance Optimization (Critical for 30fps Animation)
**Current Issue**: TimelineView running at 30fps with expensive per-frame calculations causes potential frame drops with multiple fish.

**Improvement Steps**:
- **Step 1**: Implement path caching
  - Create a `FishPathCache` class that precomputes wormPath values (cache per fish index + screen width)
  - Cache points every 10-20px along the path
  - Use interpolation between cached points for smooth curves
- **Step 2**: Optimize hit-testing
  - Reduce hit-test frequency from every frame to every 2-3 frames or only when the mouse moves
  - Use bounding box pre-check before ellipse calculation
  - Consider spatial partitioning for multiple fish
- **Step 3**: Profile and benchmark
  - Add lightweight performance logging in DEBUG mode (e.g. frame budget warnings)
  - Test with 20+ fish on target hardware
  - Target <16ms per frame consistently

**Expected Outcome**: Smooth 30fps animation even with 10+ fish, improved battery life on laptops.

### 2. State Management Consistency
**Current Issue**: @State variables scattered across views with potential for inconsistent updates.

**Improvement Steps**:
- **Step 1**: Create `FishState` ObservableObject
  ```swift
  class FishState: ObservableObject {
      @Published var position: CGFloat
      @Published var speedMultiplier: Double
      @Published var baseSpeedMultiplier: Double
      @Published var isMouseOver: Bool
      @Published var accelerationWindow: Date?
  }
  ```
- **Step 2**: Refactor TaskSnakeView to use FishState
  - Replace @State with @ObservedObject
  - Move state mutations into dedicated update functions on FishState
- **Step 3**: Add state validation
  - Ensure position stays within bounds
  - Prevent negative speeds or multipliers

**Expected Outcome**: More predictable behavior, fewer view re-render issues.

### 3. Foreground-Independent Mouse Tracking
**Current Issue**: When BrainFish is not the key app, global mouse coordinates become unreliable, so fish fail to react.

**Improvement Steps**:
- **Step 1**: Replace the current hover-based tracking with a CGEvent tap or `CGDisplayStream` callback that delivers cursor updates regardless of app focus.
- **Step 2**: Confirm the app holds the required Accessibility permission and surface a warning in Settings when permission is missing.
- **Step 3**: Throttle the event stream to match the animation cadence and reconcile coordinates through the shared conversion utilities.

**Expected Outcome**: Fish respond to the cursor even when BrainFish runs in the background or on another Space.

## Medium Priority Issues & Fixes

### 3. Coordinate System Standardization
**Current Issue**: Mixing screen and view coordinates causes mouse detection errors.

**Improvement Steps**:
- **Step 1**: Create coordinate conversion utilities
  ```swift
  extension CGPoint {
      func toViewSpace(from screen: NSScreen) -> CGPoint { ... }
      func toScreenSpace(from viewSize: CGSize) -> CGPoint { ... }
  }
  ```
- **Step 2**: Update mouse tracking
  - Always convert to consistent coordinate space before hit-testing
  - Remove manual Y-flipping assumptions
- **Step 3**: Add multi-monitor support
  - Handle different screen configurations and NSScreen origins
  - Test on dual-monitor setups

**Expected Outcome**: Accurate mouse detection across all screen configurations.

### 4. Code Duplication Elimination
**Current Issue**: wormPath logic and supporting helpers are duplicated between `TaskSnakeView`, `fishBodyView`, and the temporary `BrainFishAppResolutionChangesFix.swift` file.

**Improvement Steps**:
- **Step 1**: Extract shared utilities
  - Create `FishAnimationUtils.swift` with shared functions (wormPath, tangentAngle, lerp, letterScale)
  - Migrate resolution-handling improvements into the main target and delete the legacy fix file once merged
- **Step 2**: Update imports and references
  - Remove duplicate implementations
  - Use single source of truth
- **Step 3**: Optional targeted tests
  - When practical, add small validation functions or debug assertions for path calculations

**Expected Outcome**: Easier maintenance, consistent behavior across views.

## Low Priority Issues & Fixes

### 5. Game Mechanics Balance Tuning
**Current Issue**: Hardcoded values make tuning difficult.

**Improvement Steps**:
- **Step 1**: Move constants to configuration
  ```swift
  struct FishAnimationConfig {
      static let baseSpeed: CGFloat = 50.0
      static let speedMultiplierNearMouse: Double = 2.5
      static let avoidanceRadiusMultiplier: CGFloat = 1.5
      // ... more
  }
  ```
- **Step 2**: Add runtime tuning options
  - Extend AppSettings with animation parameters
  - Add sliders in SettingsView for speed and avoidance sensitivity (guard behind an "Advanced" toggle)
- **Step 3**: User testing and iteration
  - Gather feedback on engagement vs. distraction balance
  - Try different speed ranges in short playtesting sessions

**Expected Outcome**: More accessible tuning, better user experience customization.

### 6. Enhanced Visual Feedback
**Current Issue**: Basic avoidance, could be more engaging.

**Improvement Steps**:
- **Step 1**: Add visual avoidance cues
  - Slight color tint or bloom when avoiding mouse
  - Optional debug overlay to visualize detection ellipses
- **Step 2**: Improve sleeping transition
  - Add fade in/out animations instead of instant hide/show
- **Step 3**: Sound effects (optional)
  - Subtle water sounds when fish move or avoid

**Expected Outcome**: More immersive and polished experience.

## Implementation Timeline

### Phase 1: Critical Performance (Week 1-2)
- Implement path caching
- Optimize hit-testing
- Basic profiling

### Phase 2: State Management (Week 3)
- Create FishState class
- Refactor TaskSnakeView
- Add state validation

### Phase 3: Code Quality (Week 4)
- Eliminate duplication
- Standardize coordinates
- Merge resolution fix file

### Phase 4: Polish & Balance (Week 5-6)
- Add tuning options
- Enhanced visuals
- Informal user testing

## Testing and Validation

### Performance Testing
- Frame rate monitoring with Instruments or simple average frame time logs
- Memory usage tracking on DEBUG builds
- Battery impact measurement (manual observation acceptable for hobby work)

### Functional Testing
- Mouse avoidance accuracy across screen positions
- Multi-fish synchronization
- Pomodoro mode integration
- Sleep cycle transitions

### User Experience Testing
- Engagement vs. distraction balance via personal usage sessions
- Accessibility with different font sizes and color selections
- Performance on various Mac configurations (personal devices, friends’ Macs)

### Edge Cases
- Screen resolution changes
- Multiple displays (especially different scaling factors)
- System sleep/wake
- App backgrounding

> Note: Formal XCTest coverage is optional; lean on manual smoke tests and debug assertions that double as documentation for expected behavior.

## Success Metrics
- Maintain 30fps with 10+ fish
- Zero crashes during normal usage
- Accurate mouse detection in all tested scenarios
- Positive user feedback on engagement level

## Risk Mitigation
- **Feature Flagging**: Gate experimental behavior (new hit-testing cadence, animation configs) behind `AppSettings` toggles or `#if DEBUG` checks so regressions can be bypassed quickly.
- **Incremental Rollout**: Land improvements in small commits, verifying performance in-between to isolate regressions.
- **Fallback Paths**: Keep the current animation logic available until the cached path pipeline is proven; guard with a debug switch to revert instantly.
- **Performance Baselines**: Capture baseline frame time logs before major refactors and compare after each change to detect slowdowns early.
- **Diagnostics Hygiene**: Once profiling is complete, disable verbose `print` statements to prevent log spam from hiding genuine issues.
- **Backup Artifacts**: Preserve existing asset and entitlement configurations prior to tweaks so UI polish or sandbox adjustments can be reverted without surprises.
