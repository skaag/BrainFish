# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
BrainFish is a macOS desktop application designed to help people with ADHD stay focused on their tasks. The app displays tasks as animated fish that swim across the top of the screen, providing gentle visual reminders while avoiding the mouse cursor to minimize distraction.

## Architecture

### Core Components
- **BrainFishApp.swift**: Main application file containing the SwiftUI app structure, task management, UI components, and fish animation logic
- **AppMain.swift**: Entry point defining the @main struct and scene configuration
- **FishAnimationUtils.swift**: Shared animation utilities for fish movement, path calculations, and coordinate transformations
- **GlobalMouseTracker**: System-wide mouse position tracking using Accessibility APIs for fish avoidance behavior

### Key Features Implementation
- **Fish Animation**: Uses TimelineView at 30fps with wave-based swimming patterns and mouse avoidance
- **Task Management**: ObservableObject-based state management with UserDefaults persistence
- **Pomodoro Timer**: Integrated timer system with break periods for focused work sessions
- **Mouse Avoidance**: Elliptical detection zones that trigger speed changes when cursor approaches

## Development Commands

### Building
```bash
# Open in Xcode
open BrainFish.xcodeproj

# Build from Xcode: ⌘B
# Run from Xcode: ⌘R
```

### Command Line Building
```bash
# Build the project
xcodebuild -project BrainFish.xcodeproj -scheme BrainFish -configuration Debug build

# Build for release
xcodebuild -project BrainFish.xcodeproj -scheme BrainFish -configuration Release build
```

## Important Implementation Details

### Fish Movement System
- Fish swim from right to left at base speed of -25 px/s
- When mouse enters detection area, fish accelerate to -100 px/s
- Detection ellipse: 2x text width, 4x font height
- Extended detection adds 60px padding
- Uses lerp for smooth acceleration/deceleration

### Coordinate System
- All positions account for menu bar height
- Screen coordinates used for mouse detection (Y-axis inverted from NSEvent)
- Wave pattern: 8% from top with 2.5% amplitude

### State Management
- AppData: Core task and timer state
- AppSettings: User preferences and visual settings
- Tasks persist via UserDefaults encoding

### Accessibility Requirements
- App requires Accessibility permission for global mouse tracking
- Permission prompt shown when feature is first accessed
- Fallback to polling if global monitor unavailable

## Active Development Areas

### Current Issues
- Resolution change handling code exists in BrainFishAppResolutionChangesFix.swift (needs integration)
- Performance optimization opportunities in path calculations (see improvement_plan.md)
- Mouse tracking reliability when app is not foreground

### Debug Features
- `DEBUG_FISH_AVOIDANCE` flag shows detection ellipses and velocity info
- Debug visualizations help tune avoidance behavior parameters

## Code Conventions
- SwiftUI views use @StateObject for ownership, @EnvironmentObject for shared state
- Animation timing uses TimelineView.periodic for consistent frame rates
- Color values stored as hex strings in UserDefaults
- UUID used as Task identifier with Transferable conformance for drag/drop