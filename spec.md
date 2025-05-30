
## Fish Avoidance Behavior

### Debug Mode
- A debug flag `DEBUG_FISH_AVOIDANCE` controls visibility of debug elements
- When enabled, shows:
  - Red ellipse: Base detection area around the fish (2x text width, 4x font height)
  - Blue ellipse: Extended detection area (120px wider/taller than red ellipse)
  - Red dot: Current mouse cursor position
  - Black label: Current velocity in px/s
  - The ellipses use the same coordinates as their respective fish (no separate calculations)

### Mouse Detection & Velocity Control
- Base movement: Fish swim from right to left at -25 px/s
- Each fish has a detection ellipse that follows it:
  - Centered on the fish
  - Width = 200% of text width
  - Height = 400% of font height
  - Extended detection area adds 60px padding in all directions
- When mouse enters extended detection area:
  - Fish rapidly accelerates to -100 px/s (4x speed)
  - Acceleration uses lerp with t=0.4 for quick response
  - Visual feedback shows velocity change in debug mode
- When mouse cursor leaves detection area:
  - Fish gradually decelerates back to -25 px/s
  - Deceleration uses lerp with t=0.05 for smooth return
  - Takes about 3 seconds to fully return to normal speed

### Coordinate Space & Positioning
- All fish positions account for menu bar height
- Fish swim in a wave pattern:
  - Base Y position: 8% from top of screen
  - Wave amplitude: 2.5% of screen height
  - Wave frequency: 3.0
  - The fish swim along the path and do not have their own separate wave function
  - The existing code already implement the correct swimming pattern so don't break that
- Multiple fish are staggered:
  - Initial spacing: 300px between fish
  - When a fish exits left side, it reappears on right maintaining stagger
  - Stagger based on task index preserves readable order

### Implementation Notes
- All coordinates must be in screen space for proper mouse detection
- Menu bar height must be consistently applied
- Debug visualization should accurately reflect detection areas
- Velocity changes should feel smooth but responsive
- Fish spacing should maintain readability of tasks
