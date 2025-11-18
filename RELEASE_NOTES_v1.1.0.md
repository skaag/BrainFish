# BrainFish v1.1.0 - ClipDrawer Release

## 🎉 Major New Feature: ClipDrawer

A powerful, macOS-native clip management system that brings quick access to your text snippets and links.

### What is ClipDrawer?

ClipDrawer adds edge-activated drawers to your screen that store and organize text clips and links. Simply move your mouse to the screen edge to reveal your clips, drag content from any application to save it, and access it anytime with a quick mouse movement.

## ✨ Key Features

### 📋 Clip Management
- **Drag & Drop**: Drag text, links, or content from any application directly onto the drawer
- **Smart Organization**: Clips are organized in zones for easy access
- **Persistent Storage**: All clips are saved and persist across app restarts
- **App Icon Integration**: Each clip shows the icon of the source application

### 🎯 Interaction & UX
- **Edge Activation**: Move mouse to left or right screen edge to reveal drawer
- **Proximity Zoom**: Clips grow larger as your mouse approaches (macOS Dock-style)
- **Auto-Hide**: Drawers automatically hide after configurable delay (default 4 seconds)
- **Hover Preview**: Hover over any clip for 3 seconds to see full content in a preview bubble
- **Smooth Animations**: Polished fade-in/fade-out transitions

### 🗑️ Deletion
- **Drag to Delete**: Drag clips to the menu bar area to delete them
- **Visual Feedback**: Red delete zone appears when dragging
- **macOS Poof Sound**: Authentic deletion sound effect
- **Context Menu**: Right-click any clip for quick deletion

### ⚙️ Settings & Customization

#### Standard Settings
- **Left/Right Drawer Toggle**: Enable either or both drawers
- **Auto-hide Delay**: Configure how long before clips fade out (1-10 seconds)
- **Drag Behavior**: Choose delete-on-drag or keep-on-drag (with modifier key to reverse)
- **App Icons**: Toggle app icon display

#### Advanced Settings (Collapsible)
- **Visual Tuning**: Font size, padding, colors, background
- **Proximity Zoom**: Configure radius, power, min/max zoom levels
- **Behavior**: Edge sensitivity, slide distance, peek width
- **Shadows**: Drawer and clip shadow controls with adjustable strength
- **Dimensions**: Clip height, corner radius (hidden/visible states)
- **Icon Positioning**: Top or bottom placement for app icons
- **Debug Mode**: Visualize proximity detection circles

### 🔧 Technical Highlights
- **Radius-Based Proximity**: Drawer visibility controlled by configurable radiuses around clips
- **Dual Radius System**:
  - Visible radius (larger): Defines when clips respond to mouse proximity
  - Hidden radius (smaller): Controls sigmoid curve steepness for smooth zoom
- **Native SwiftUI**: Leverages SwiftUI's animation system for smooth transitions
- **Clean Architecture**: Refactored animation utilities into separate FishAnimationUtils.swift

## 🎨 Default Configuration

- **Left drawer**: Enabled
- **Right drawer**: Disabled
- **Auto-hide delay**: 4.0 seconds
- **Delete behavior**: Delete on drag out (hold Shift/Alt to keep)
- **App icons**: Enabled

## 📝 Changes from Previous Version

### Added
- Complete ClipDrawer system with dual-drawer support
- Drag and drop integration across all macOS applications
- Proximity-based zoom with configurable radiuses
- Auto-hide timer with smooth fade animations
- Hover preview bubble (3-second delay)
- Delete zone with macOS poof sound
- Context menu for clip deletion
- Comprehensive settings panel with collapsible advanced options
- App icon tracking and display
- FishAnimationUtils.swift for cleaner code organization
- CLAUDE.md for AI-assisted development documentation

### Changed
- Refactored fish animation code into separate utility file
- Improved code organization and modularity

### Technical Details
- 2,221 line additions across core files
- New proximity detection algorithms
- Enhanced state management for drawer visibility
- Optimized animation performance

## 🚀 Getting Started

1. **Enable ClipDrawer**: Open Settings → ClipDrawer tab → Enable ClipDrawer
2. **Try It Out**:
   - Move your mouse to the left edge of the screen
   - Drag some text from any app onto the drawer
   - Hover over clips to preview content
   - Drag clips to the menu bar area to delete
3. **Customize**: Explore the Advanced Settings for fine-tuning

## 💡 Tips

- The larger "Radius (Visible)" setting controls when the drawer appears
- The smaller "Radius (Hidden)" setting controls zoom curve smoothness
- Use the Debug Circles toggle to visualize proximity detection zones
- Hold Shift or Alt while dragging to reverse your default drag behavior
- Right-click clips for quick actions

## 🙏 Credits

Developed with assistance from Claude Code (Anthropic)

---

**Full Changelog**: https://github.com/YOUR_USERNAME/BrainFish/compare/v1.0.0...v1.1.0
