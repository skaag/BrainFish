# Common Mistakes and Solutions

## Swift and SwiftUI Specific Issues

### 1. Scope Issues with Variables
- **Problem**: Using variables outside their scope, such as the `textWidth` variable in the `adjustedFishPosition` method.
- **Solution**: Pass the variable as a parameter to the method or make it a property of the class/struct.
- **Example**: Changed `adjustedFishPosition(original:)` to `adjustedFishPosition(original:detectionWidth:detectionHeight:)` to pass the required variables.

### 2. Optional Binding Issues
- **Problem**: Using `if let` with non-optional values like `NSEvent.mouseLocation`.
- **Solution**: Either directly use the value if it's non-optional, or handle it properly if it is optional.
- **Example**: Changed `if let mouseLocation = NSEvent.mouseLocation` to directly use `let mouseLocation = NSEvent.mouseLocation`.

### 3. Main Attribute Issues
- **Problem**: Using `@main` attribute in a file with top-level code.
- **Solution**: Create a separate file for the app entry point that only contains the `@main` struct.
- **Example**: Created AppMain.swift with a minimal `@main` struct that initializes the app, and removed the `@main` attribute from the BrainFishApp.swift file.

## Screen Management Issues

### 1. Screen Resolution Changes
- **Problem**: Fish swimming off-screen when switching between monitors.
- **Solution**: Implemented screen change detection using `NSApplication.didChangeScreenParametersNotification` and reset fish positions when screen parameters change.

### 2. Window Management
- **Problem**: Improper window setup causing display issues.
- **Solution**: Properly configured window properties (level, opacity, ignoring mouse events, etc.) in `applicationDidFinishLaunching`.

## Animation and Performance Issues

### 1. Mouse Detection
- **Problem**: Mouse detection affecting individual letters instead of the entire fish.
- **Solution**: Implemented elliptical detection areas for mouse proximity that affect the entire fish.

### 2. Continuous Animation
- **Problem**: Fish not animating without mouse movement.
- **Solution**: Used TimelineView with a minimum interval to ensure continuous animation.
