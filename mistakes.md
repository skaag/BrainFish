# Common Mistakes and Lessons Learned

## General Guidelines
Remember to removed unused variables, keep the code clean and efficient.
Ensure variables are in the scope when you use them or reference them.

## SwiftUI State Management
1. **Modifying State During View Updates**
   - ❌ Mistake: Modifying @State variables directly in view rendering functions or computed properties
   - ✅ Solution: Use `onChange` modifier or dedicated update functions to handle state changes
   - Example: Moving velocity updates from `adjustedFishPosition` to a separate `updateVelocity` function with `onChange`

2. **Timer Management**
   - ❌ Mistake: Using Timer.publish with manual state updates
   - ✅ Solution: Use SwiftUI's TimelineView for animations and continuous updates
   - Benefits: Better performance, automatic cleanup, and SwiftUI-native approach

3. **Mutable State in Views**
   - ❌ Mistake: Using @State with inferred type for mutable task copy
   - ✅ Solution: Explicitly declare the type when creating mutable state copies
   - Example: `@State private var mutableTask: Task = task` instead of `@State private var mutableTask = task`

4. **Property Initialization**
   - ❌ Mistake: Using instance members in property initializers
   - ✅ Solution: Initialize state in the view's initializer using State(initialValue:)
   - Example: Use `self._mutableTask = State(initialValue: task)` in init instead of direct assignment

## Access Control
1. **Visibility Issues**
   - ❌ Mistake: Not making public types and their members accessible
   - ✅ Solution: When a type is public, make sure to:
     - Mark initializers as public
     - Mark required properties as public
     - Mark protocol conformance requirements (like `body`) as public

2. **Type Dependencies**
   - ❌ Mistake: Making a type public while its dependencies remain internal
   - ✅ Solution: Ensure all types used in public interfaces are also public
   - Example: Making `Task` public when it's used in public `TaskSnakeView`

## Code Organization
1. **Duplicate Declarations**
   - ❌ Mistake: Having multiple files with the same type definitions
   - ✅ Solution: 
     - Keep only one source of truth
     - Use proper version control for experimental changes
     - Don't create duplicate "*Fix.swift" files

2. **Function Placement**
   - ❌ Mistake: Scattered related functions throughout the file
   - ✅ Solution: Group related functionality together:
     - Helper functions near where they're used
     - State management functions together
     - View-related functions near the view declaration

## SwiftUI View Building
1. **Non-View Operations in View Builder**
   - ❌ Mistake: Performing state updates or calculations directly in view builder context
   - ✅ Solution: 
     - Use proper SwiftUI modifiers (onChange, onAppear)
     - Move calculations to computed properties or methods
     - Keep view builder context pure for view construction

2. **Animation Constants**
   - ❌ Mistake: Using incorrect movement constants or directions
   - ✅ Solution:
     - Document the purpose of movement constants
     - Use negative values for right-to-left movement
     - Consider screen boundaries in calculations
     - Test with different screen sizes

## Memory Management
1. **Resource Cleanup**
   - ❌ Mistake: Not properly cleaning up subscriptions and timers
   - ✅ Solution: 
     - Use SwiftUI's lifecycle modifiers (`onAppear`, `onDisappear`)
     - Store cancellables in properties
     - Cancel subscriptions when views disappear

## Screen Management
1. **Screen Bounds Handling**
   - ❌ Mistake: Not accounting for screen resolution changes
   - ✅ Solution:
     - Use NSScreen.main.frame dynamically
     - Implement screen change detection
     - Add boundary detection with safe zones
     - Use relative positioning instead of absolute coordinates

## Project Organization
1. **Documentation**
   - ❌ Mistake: Not updating spec.md with implementation details
   - ✅ Solution:
     - Keep spec.md updated with all changes
     - Document design decisions
     - Include known limitations and workarounds

## Performance
1. **Unnecessary Computations**
   - ❌ Mistake: Recalculating values in every view update
   - ✅ Solution:
     - Use computed properties for static values
     - Cache frequently used calculations
     - Move heavy computations out of the render path

## Best Practices
1. **Code Reuse**
   - ❌ Mistake: Duplicating code for similar functionality
   - ✅ Solution:
     - Extract common functionality into reusable functions
     - Use extensions for shared behavior
     - Create utility functions for repeated calculations

2. **Error Handling**
   - ❌ Mistake: Not properly handling potential errors
   - ✅ Solution:
     - Add proper error handling for file operations
     - Handle optional values safely
     - Provide fallback values for edge cases

## Testing
1. **Debug Support**
   - ❌ Mistake: Not maintaining debug visualization when refactoring
   - ✅ Solution:
     - Keep debug flags functional
     - Update debug visualizations with code changes
     - Ensure debug info remains accurate

## SwiftLint and Code Style
1. **Variable Naming**
   - ❌ Mistake: Using single-letter variable names or inconsistent naming
   - ✅ Solution:
     - Use descriptive names (e.g., `letterIndex` instead of `i`)
     - Follow Swift naming conventions
     - Document the purpose of constants

2. **Code Formatting**
   - ❌ Mistake: Inconsistent formatting and long lines
   - ✅ Solution:
     - Break long lines into multiple lines
     - Use consistent indentation
     - Remove trailing whitespace
     - Group related modifiers together

## API Deprecations
1. **SwiftUI API Changes**
   - ❌ Mistake: Using deprecated SwiftUI APIs
   - ✅ Solution:
     - Update `onChange(of:perform:)` to new syntax in macOS 14.0+:
       ```swift
       // Old (deprecated):
       .onChange(of: someValue) { newValue in }
       
       // New (preferred):
       .onChange(of: someValue) { oldValue, newValue in }
       // or
       .onChange(of: someValue) { }
       ```
     - Regularly check for deprecation warnings
     - Keep up with SwiftUI API evolution
     - Test on latest OS versions

Remember to update this file as new lessons are learned and patterns emerge.
