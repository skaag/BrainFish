# BrainFish Application Specification

## Overview
BrainFish is a macOS application that displays animated fish representing tasks. The fish swim across the screen, with their appearance and behavior determined by task properties.

## Fish Animation and Behavior

### Fish Movement
- Fish swim from right to left across the screen
- Each fish follows a sinusoidal path (worm-like movement)
- Fish speed is variable and can be affected by external factors like mouse proximity
- Fish position is automatically adjusted when screen parameters change

### Fish Appearance
- Each fish consists of multiple components: head, pectoral fins, ventral fins, tail, and text body
- The fish body is composed of text characters representing the task name
- Components are properly sized relative to each other and the text
- Fish size scales with the font size setting

### Fish Rotation
- The fish head rotates to match the tangent angle of its path
- The tail rotates to match the tangent angle of its position on the path
- All fish components maintain proper orientation as they follow the sinusoidal path

### Mouse Interaction
- Fish detect mouse proximity using elliptical detection areas
- Two detection zones: inner (red) and outer (blue) ellipses
- When mouse enters detection area, the entire fish accelerates to avoid the cursor
- Detection affects the entire fish as a unit, not individual components
- Fish speed gradually returns to normal when mouse leaves detection area

### Animation Performance
- Fish animate continuously using TimelineView with a minimum interval of 0.016 seconds
- Animation continues regardless of mouse movement
- Smooth transitions between animation states

## Screen Management
- Application properly handles screen resolution changes
- Fish remain visible when switching between displays
- Safe zones (80% of visible screen) keep fish from going off-screen
- Screen change detection using NSApplication.didChangeScreenParametersNotification

## Task Management
- Tasks can be displayed in regular mode or Pomodoro mode
- Each task has properties including name, time, and completion status
- Tasks can be added, edited, and removed

## User Interface
- Clean, minimalist interface
- Debug visualization available for fish avoidance mechanics
- Font size and color can be customized
- Settings are persisted between application launches

## Future Improvements
- Add more fish varieties and animations
- Implement task completion notifications
- Add statistics tracking for completed tasks
- Improve performance for large numbers of tasks
